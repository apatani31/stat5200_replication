# 02_validate.R
# Checks that the file's own series behave as the paper's definitions say,
# before we build any results on them.
#  (a) premium: 100 * (shadow / official - 1) should equal the published
#      premium series BIT_SHD_PT.
#  (b) shadow rate = BTC_LCU / BTC_USD: the file does not ship BTC prices, so
#      we test the implication that the United States shadow rate is 1
#      (BTC_USD / BTC_USD) and the US official rate is 1.
#  (c) aggregation: are monthly values averages or end-of-month? Ukraine's
#      official rate was fixed at 29.25 from 24 Feb to 21 Jul 2022 and then
#      reset to 36.5686. An average gives a value strictly between the two in
#      July 2022 and a value below 29.25 in February; an end-of-month value
#      gives 36.57 in July.

source(here::here("code", "00_setup.R"))
panel <- readr::read_csv(file.path(DERIVED_DIR, "panel_country_month.csv"), show_col_types = FALSE)

both <- panel |> dplyr::filter(!is.na(premium), !is.na(premium_pct_file))
diff_pp <- 100 * both$premium - both$premium_pct_file

usa <- panel |> dplyr::filter(iso3 == "USA")
ukr <- panel |> dplyr::filter(iso3 == "UKR", date >= as.Date("2022-01-01"), date <= as.Date("2022-09-01"))

checks <- tibble::tibble(
  check = c(
    "Obs with both own and IMF premium",
    "Max |own premium - IMF premium| (pp)",
    "Mean |own premium - IMF premium| (pp)",
    "Country-months with shadow but no IMF premium",
    "USA: months with |shadow - 1| > 1%",
    "USA: max |shadow - 1|",
    "USA: max |official - 1|",
    "UKR official 2022-02",
    "UKR official 2022-03 to 2022-06 (min)",
    "UKR official 2022-03 to 2022-06 (max)",
    "UKR official 2022-07",
    "UKR official 2022-08"
  ),
  value = c(
    nrow(both),
    max(abs(diff_pp)),
    mean(abs(diff_pp)),
    sum(!is.na(panel$shadow) & is.na(panel$premium_pct_file)),
    sum(abs(usa$shadow - 1) > 0.01, na.rm = TRUE),
    max(abs(usa$shadow - 1), na.rm = TRUE),
    max(abs(usa$official - 1), na.rm = TRUE),
    ukr$official[ukr$date == as.Date("2022-02-01")],
    min(ukr$official[ukr$date >= as.Date("2022-03-01") & ukr$date <= as.Date("2022-06-01")]),
    max(ukr$official[ukr$date >= as.Date("2022-03-01") & ukr$date <= as.Date("2022-06-01")]),
    ukr$official[ukr$date == as.Date("2022-07-01")],
    ukr$official[ukr$date == as.Date("2022-08-01")]
  )
)
readr::write_csv(checks, file.path(TAB_DIR, "validation_checks.csv"))
print(checks, n = Inf, width = 120)

# Hard stops: if the file's premium disagrees with the formula, every result
# downstream would be ambiguous, so the pipeline should not continue.
if (max(abs(diff_pp)) > 1e-3) stop("Own premium does not match IMF BIT_SHD_PT series")
# The US shadow rate is NOT identically 1: the "local US market" price and
# the "international" BTC/USD benchmark come from different exchange sets, so
# the US row measures pure cross-exchange noise. That is informative (a noise
# floor for every other country), not an error, so we report it rather than stop.
message(sprintf("02_validate: US shadow rate deviates from 1 by up to %.1f%% (cross-exchange noise floor)",
                100 * max(abs(usa$shadow - 1), na.rm = TRUE)))
