# 04_tables.R
# Summary statistics of the premium by country (H1 and H2), with Newey-West
# standard errors for the mean. Reported for the paper window and for the
# full file sample, because the file extends 27 months past the paper.

source(here::here("code", "00_setup.R"))
panel <- readr::read_csv(file.path(DERIVED_DIR, "panel_country_month.csv"), show_col_types = FALSE)

sets <- tibble::tibble(iso3 = c(names(OPEN_SET), names(CONTROLS_SET)),
                       label = c(OPEN_SET, CONTROLS_SET),
                       group = c(rep("Open (H1)", length(OPEN_SET)), rep("Controls (H2)", length(CONTROLS_SET))))

# The US "premium" is pure cross-exchange noise (02_validate.R). If open
# economies' premia co-move with it, their small deviations reflect the
# international benchmark price rather than anything local.
corr_with_us <- function(p) {
  us <- p |> dplyr::filter(iso3 == "USA") |> dplyr::select(date, us_premium = premium)
  p |>
    dplyr::filter(!is.na(premium)) |>
    dplyr::inner_join(us, by = "date") |>
    dplyr::group_by(iso3) |>
    dplyr::summarise(corr_us = stats::cor(premium, us_premium, use = "complete.obs"), .groups = "drop")
}

make_table <- function(p, window_name) {
  summarise_premium(p, PREMIUM_THRESHOLD) |>
    dplyr::inner_join(sets, by = "iso3") |>
    dplyr::left_join(corr_with_us(p), by = "iso3") |>
    dplyr::mutate(window = window_name) |>
    dplyr::select(window, group, label, iso3, first, last, n_months, gaps,
                  mean_pct, nw_se_pct, nw_t, nw_lag, median_pct, sd_pct,
                  share_abs_gt, max_pct, min_pct, corr_us) |>
    dplyr::arrange(match(iso3, sets$iso3))
}

paper_win <- panel |> dplyr::filter(date >= PAPER_START, date <= PAPER_END)
tab_paper <- make_table(paper_win, "2019-01 to 2023-07 (paper)")
tab_full  <- make_table(panel, "Full file sample")

# All countries with crypto data, for context beyond the paper's case studies.
tab_all <- summarise_premium(paper_win, PREMIUM_THRESHOLD) |>
  dplyr::arrange(dplyr::desc(abs(median_pct)))

readr::write_csv(dplyr::bind_rows(tab_paper, tab_full), file.path(TAB_DIR, "table1_premium_summary.csv"))
readr::write_csv(tab_all, file.path(TAB_DIR, "table_a1_all_countries_paper_window.csv"))

tex_view <- function(t) {
  t |>
    dplyr::transmute(Country = label, N = as.character(n_months),
                     `Mean %` = mean_pct, `NW SE` = nw_se_pct, `t` = nw_t,
                     `Median %` = median_pct, `SD` = sd_pct,
                     `Share >5%` = share_abs_gt, `Max %` = max_pct,
                     `Corr US` = corr_us)
}
write_tex_table(tex_view(tab_paper), file.path(TAB_DIR, "table1_paper_window.tex"))
write_tex_table(tex_view(tab_full),  file.path(TAB_DIR, "table1_full_sample.tex"))
write_tex_table(
  tab_all |> dplyr::transmute(Country = country, N = as.character(n_months),
                              `Median %` = median_pct, `Share >5%` = share_abs_gt,
                              `Max %` = max_pct),
  file.path(TAB_DIR, "table_a1_all_countries.tex"))

print(tab_paper |> dplyr::select(label, n_months, mean_pct, nw_se_pct, nw_t, median_pct, sd_pct, share_abs_gt, max_pct, corr_us), width = 160)
print(tab_full  |> dplyr::select(label, n_months, mean_pct, nw_se_pct, nw_t, median_pct, sd_pct, share_abs_gt, max_pct, corr_us), width = 160)
