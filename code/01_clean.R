# 01_clean.R
# Reshape the IMF WP-CPER export (one series per row, months as columns) into
# a tidy country-by-month panel. The raw file is only read, never written.

source(here::here("code", "00_setup.R"))

long <- read_wpcper_long(RAW_FILE)

# The export claims a single frequency; fail loudly if a future download
# mixes frequencies, since every later step assumes monthly spacing.
stopifnot(identical(unique(long$freq_code), "M"))

panel <- build_panel(long)

# Inventory of what each country actually has, used in data/README.md and to
# justify the country substitutions in 00_setup.R.
inventory <- long |>
  dplyr::group_by(iso3, country, ind_code, indicator_label) |>
  dplyr::summarise(n_months = dplyr::n(),
                   first = format(min(date), "%Y-%m"),
                   last  = format(max(date), "%Y-%m"), .groups = "drop") |>
  dplyr::arrange(country, ind_code)

readr::write_csv(long,      file.path(DERIVED_DIR, "wpcper_long.csv"))
readr::write_csv(panel,     file.path(DERIVED_DIR, "panel_country_month.csv"))
readr::write_csv(inventory, file.path(TAB_DIR, "series_inventory.csv"))

message(sprintf("01_clean: %d series rows -> panel of %d country-months, %d countries (%d with crypto rates)",
                dplyr::n_distinct(paste(long$iso3, long$ind_code)), nrow(panel),
                dplyr::n_distinct(panel$iso3),
                dplyr::n_distinct(panel$iso3[!is.na(panel$shadow)])))
