# Shared setup sourced by every numbered script.
# Kept in one place so that country sets, event dates and the sample window
# are defined once and cannot drift between scripts.

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
  library(sandwich)
})

set.seed(5200)  # nothing is random today; fixed so any future bootstrap is reproducible

source(here::here("code", "functions.R"))

# ---- Paths -----------------------------------------------------------------
# The raw file is located by pattern so a re-download with a new timestamp in
# its name still works, but we insist on exactly one match to avoid silently
# mixing vintages.
raw_files <- Sys.glob(here::here("data", "raw", "dataset_*IMF.STA_WPCPER*.csv"))
if (length(raw_files) != 1) {
  stop("Expected exactly one WPCPER CSV in data/raw/, found ", length(raw_files))
}
RAW_FILE     <- raw_files
DERIVED_DIR  <- here::here("data", "derived")
FIG_DIR      <- here::here("output", "figures")
TAB_DIR      <- here::here("output", "tables")
for (d in c(DERIVED_DIR, FIG_DIR, TAB_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- Sample windows --------------------------------------------------------
# The paper uses 2019-01-01 to 2023-07-13. With monthly data the closest match
# is 2019-01 to 2023-07 (July 2023 is a partial month in the paper).
PAPER_START <- as.Date("2019-01-01")
PAPER_END   <- as.Date("2023-07-01")

# ---- Country sets ----------------------------------------------------------
# Paper Figure 6 (open accounts): euro area, Turkiye, Brazil, Mexico.
# Paper Figures 7-8 (binding controls): Argentina, Ukraine, Egypt, Nigeria.
# The IMF WP-CPER file has no euro area, Turkiye or Egypt series, so we keep
# the paper countries that exist and add two advanced economies with fully
# open accounts (United Kingdom, Japan) as clearly labelled stand-ins for the
# euro area. There is no stand-in for Turkiye or Egypt.
OPEN_SET <- c(BRA = "Brazil", MEX = "Mexico",
              GBR = "United Kingdom (stand-in)", JPN = "Japan (stand-in)")
CONTROLS_SET <- c(ARG = "Argentina", UKR = "Ukraine", NGA = "Nigeria")
PAPER_MISSING <- c("Euro area", "Turkiye", "Egypt")

# ---- Event dates (my reading of the paper, see README) ---------------------
# The paper says Argentina reintroduced restrictions in the 2019 election year
# with the premium rising from late 2019; it does not give a day. We use
# Decree 609/2019 (1 Sept 2019) as the control date. For Ukraine the paper
# refers to the Russian invasion (24 Feb 2022) and to the later NBU
# devaluation (21 July 2022), shown as a secondary marker.
EVENTS <- tibble::tribble(
  ~iso3, ~event,                          ~event_date,
  "ARG", "Capital controls (Decree 609/2019)", as.Date("2019-09-01"),
  "UKR", "Russian invasion",               as.Date("2022-02-24")
)
UKR_DEVALUATION <- as.Date("2022-07-21")

# Event window half-length. Daily data would allow +/- 60 days; at monthly
# frequency that collapses to 2 points, so we use +/- 6 months instead.
EVENT_K <- 6

# Threshold the assignment uses for a "large" premium.
PREMIUM_THRESHOLD <- 0.05

# Plot colours: categorical slots 1 and 2 of a validated palette. Official
# and shadow lines also differ by linetype so colour is never the only cue.
COL_OFFICIAL <- "#2a78d6"
COL_SHADOW   <- "#eb6834"
