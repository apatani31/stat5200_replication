# Reusable functions for the crypto premium pipeline.
#
# Design note for the stablecoin project: the premium logic only needs a
# local-currency price of some dollar-linked asset and its USD price. For BTC
# that is BTC_LCU / BTC_USD; for USDT it is USDT_LCU / USDT_USD (or USDT_LCU
# alone if USDT is taken as 1 USD). Everything downstream of `build_panel()`
# works on the generic columns `shadow` and `official`, so swapping the leg
# means supplying a different `shadow` column and nothing else.

# ---- Core definitions ------------------------------------------------------

#' Implied LCU per USD from one asset quoted in two currencies.
#' price_usd defaults to 1 so a stablecoin quote can be passed directly.
shadow_rate <- function(price_lcu, price_usd = 1) {
  price_lcu / price_usd
}

#' Premium of the shadow rate over the official rate, as a fraction.
premium <- function(shadow, official) {
  shadow / official - 1
}

# ---- Reading and reshaping the IMF file ------------------------------------

# Series codes look like "ARS.ARG.BIT_SHD_RT.M": currency.country.indicator.freq.
# These are the indicator codes we use and the column names we give them.
INDICATOR_MAP <- c(
  BIT_SHD_RT = "shadow",            # Crypto-based parallel exchange rate, LCU per USD
  XDC_USD_RT = "official",          # Official FX rate, LCU per USD
  BIT_SHD_PT = "premium_pct_file",  # Premium as published by the IMF, in percent
  TVBIT_USD  = "volume_usd",        # BTC trade volume in local market, in USD
  TVBIT      = "volume_btc"         # BTC trade volume, number of coins (one empty series)
)

#' Read the WP-CPER wide CSV (one series per row, one column per month) and
#' return a long table with one row per series and month.
read_wpcper_long <- function(path) {
  raw <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                         show_col_types = FALSE, progress = FALSE)
  time_cols <- grep("^[0-9]{4}-M[0-9]{2}$", names(raw), value = TRUE)
  if (length(time_cols) == 0) stop("No YYYY-Mmm columns found; is this the monthly export?")

  parts <- strsplit(raw$SERIES_CODE, ".", fixed = TRUE)
  raw$iso3      <- vapply(parts, `[`, "", 2)
  raw$ind_code  <- vapply(parts, `[`, "", 3)
  raw$freq_code <- vapply(parts, `[`, "", 4)

  raw |>
    dplyr::select(iso3, country = COUNTRY, currency = CURRENCY, ind_code, freq_code,
                  indicator_label = INDICATOR, dplyr::all_of(time_cols)) |>
    tidyr::pivot_longer(dplyr::all_of(time_cols), names_to = "period", values_to = "value") |>
    dplyr::mutate(
      date  = as.Date(paste0(substr(period, 1, 4), "-", substr(period, 7, 8), "-01")),
      value = suppressWarnings(as.numeric(value))
    ) |>
    dplyr::filter(!is.na(value))
}

#' Country-by-month panel with one column per indicator, plus our own premium.
build_panel <- function(long) {
  unknown <- setdiff(unique(long$ind_code), names(INDICATOR_MAP))
  if (length(unknown) > 0) stop("Unmapped indicator codes: ", paste(unknown, collapse = ", "))

  long |>
    dplyr::mutate(var = unname(INDICATOR_MAP[ind_code])) |>
    dplyr::select(iso3, country, currency, date, var, value) |>
    tidyr::pivot_wider(names_from = var, values_from = value) |>
    dplyr::mutate(premium = premium(shadow, official)) |>
    dplyr::arrange(iso3, date)
}

# ---- Statistics ------------------------------------------------------------

#' Newey-West lag from the usual rule of thumb floor(4 (T/100)^(2/9)).
nw_lag <- function(n) floor(4 * (n / 100)^(2 / 9))

#' Mean of a series with a HAC (Newey-West) standard error.
#' Premia are highly persistent, so iid standard errors would overstate
#' precision; the HAC SE is what makes "mean premium differs from zero" a fair test.
nw_mean <- function(x, lag = NULL) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n < 3) return(c(mean = NA_real_, se = NA_real_, t = NA_real_, lag = NA_real_))
  L <- if (is.null(lag)) nw_lag(n) else lag
  fit <- stats::lm(x ~ 1)
  V <- sandwich::NeweyWest(fit, lag = L, prewhite = FALSE, adjust = TRUE)
  se <- sqrt(V[1, 1])
  c(mean = mean(x), se = se, t = mean(x) / se, lag = L)
}

#' Per-country summary of the premium (in percent) used for H1 and H2.
summarise_premium <- function(panel, threshold = 0.05) {
  panel |>
    dplyr::filter(!is.na(premium)) |>
    dplyr::group_by(iso3, country) |>
    dplyr::summarise(
      first    = min(date),
      last     = max(date),
      n_months = dplyr::n(),
      # Gaps matter for the HAC SE because it treats rows as consecutive.
      gaps     = as.integer(n_months != length(seq(first, last, by = "month"))),
      nw       = list(nw_mean(premium)),
      median_pct = 100 * stats::median(premium),
      sd_pct   = 100 * stats::sd(premium),
      share_abs_gt = mean(abs(premium) > threshold),
      max_pct  = 100 * max(premium),
      min_pct  = 100 * min(premium),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      mean_pct  = 100 * vapply(nw, `[[`, 0, "mean"),
      nw_se_pct = 100 * vapply(nw, `[[`, 0, "se"),
      nw_t      = vapply(nw, `[[`, 0, "t"),
      nw_lag    = vapply(nw, `[[`, 0, "lag"),
      .after = gaps
    ) |>
    dplyr::select(-nw)
}

#' Event-time slice of one country's premium around an event month.
#' The event month is t = 0; it is excluded from the pre/post means because
#' at monthly frequency it mixes pre- and post-event days.
event_window <- function(panel, iso, event_date, k) {
  ev_month <- as.Date(format(event_date, "%Y-%m-01"))
  panel |>
    dplyr::filter(iso3 == iso) |>
    dplyr::mutate(t = (as.integer(format(date, "%Y")) - as.integer(format(ev_month, "%Y"))) * 12 +
                    (as.integer(format(date, "%m")) - as.integer(format(ev_month, "%m")))) |>
    dplyr::filter(abs(t) <= k)
}

event_summary <- function(win) {
  pre  <- win$premium[win$t < 0]
  post <- win$premium[win$t > 0]
  tibble::tibble(
    n_pre = length(pre), n_post = length(post),
    pre_mean_pct  = 100 * mean(pre),
    post_mean_pct = 100 * mean(post),
    diff_pp       = 100 * (mean(post) - mean(pre)),
    month0_pct    = 100 * win$premium[win$t == 0]
  )
}

# ---- Output helpers --------------------------------------------------------

#' Minimal LaTeX tabular writer so the summary document can \input{} tables
#' straight from the pipeline (no copy-pasting numbers).
write_tex_table <- function(df, path, align = NULL, digits = 2) {
  fmt <- function(v) {
    if (is.numeric(v)) formatC(v, format = "f", digits = digits, big.mark = ",") else as.character(v)
  }
  # ">" must go to math mode: in the default OT1 font encoding it prints as an
  # inverted question mark.
  esc <- function(s) gsub(">", "$>$", gsub("([%&_#$])", "\\\\\\1", s), fixed = TRUE)
  cols <- lapply(df, fmt)
  if (is.null(align)) align <- paste0("l", strrep("r", ncol(df) - 1))
  body <- do.call(paste, c(lapply(cols, esc), sep = " & "))
  lines <- c(
    paste0("\\begin{tabular}{", align, "}"),
    "\\hline",
    paste0(paste(esc(names(df)), collapse = " & "), " \\\\"),
    "\\hline",
    paste0(body, " \\\\"),
    "\\hline",
    "\\end{tabular}"
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

theme_rep <- function() {
  ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "grey90", linewidth = 0.3),
      legend.position  = "top",
      strip.text       = ggplot2::element_text(face = "bold", hjust = 0),
      plot.title.position = "plot"
    )
}

#' Shadow vs official rate, one facet per country, common LCU/USD axis
#' within each facet (free scales across countries since units differ).
plot_shadow_official <- function(panel, labels, title, subtitle = NULL,
                                 col_official = "#2a78d6", col_shadow = "#eb6834") {
  d <- panel |>
    dplyr::filter(iso3 %in% names(labels)) |>
    dplyr::mutate(label = factor(labels[iso3], levels = labels)) |>
    dplyr::select(label, date, official, shadow) |>
    tidyr::pivot_longer(c(official, shadow), names_to = "series", values_to = "lcu_per_usd") |>
    dplyr::mutate(series = factor(series, levels = c("official", "shadow"),
                                  labels = c("Official rate", "Crypto shadow rate")))
  ggplot2::ggplot(d, ggplot2::aes(date, lcu_per_usd, colour = series, linetype = series)) +
    ggplot2::geom_line(linewidth = 0.6, na.rm = TRUE) +
    ggplot2::facet_wrap(~label, scales = "free_y") +
    ggplot2::scale_colour_manual(values = c(col_official, col_shadow), name = NULL) +
    ggplot2::scale_linetype_manual(values = c("solid", "22"), name = NULL) +
    ggplot2::labs(x = NULL, y = "Local currency per USD", title = title, subtitle = subtitle) +
    theme_rep()
}
