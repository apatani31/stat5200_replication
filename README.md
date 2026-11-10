# Replication: "Crypto as a Marketplace for Capital Flight"

STAT 5200 (Applied Econometrics I, Wharton) replication assignment.

**Paper:** Graf von Luckner, C., Koepke, R. and Sgherri, S. (2024), "Crypto as a Marketplace for Capital Flight", IMF Working Paper 24/133. [IMF page](https://www.imf.org/en/publications/wp/issues/2024/06/28/crypto-as-a-marketplace-for-capital-flight-550966)

## Purpose

The paper argues that crypto exchanges let people who cannot buy foreign currency at the official rate buy it from people who can. The price of bitcoin in local currency divided by its US dollar price gives an implied "shadow" exchange rate. The premium of that rate over the official rate should be near zero with open financial accounts (H1), and large and persistent under binding capital controls (H2). The paper also argues that crypto bans cluster in countries with closed financial accounts (H3).

This repo reproduces the paper's evidence for H1 and H2 from the IMF's public companion dataset, adds summary statistics with Newey-West standard errors and event windows, and documents where and why the results differ. It also serves as the base for my final project on the stablecoin (USDT) dollar premium: the BTC leg is isolated in `shadow_rate()` in `code/functions.R`, so the same pipeline can run on USDT quotes.

The full write-up is [`summary/replication_summary.pdf`](summary/replication_summary.pdf).

## Repo layout

```
run_all.R                  single entry point: restores packages, runs code/01..05, optional PDF
renv.lock, renv/, .Rprofile  pinned R package versions (renv)
code/
  00_setup.R               packages, paths, seed, country sets, event dates (sourced by every script)
  functions.R              reusable logic: shadow_rate(), premium(), reshaping, Newey-West, plots, LaTeX tables
  01_clean.R               raw wide CSV -> tidy country-by-month panel (data/derived/)
  02_validate.R            premium formula vs IMF series, US benchmark, monthly averaging test
  03_figures.R             fig1-fig3: shadow vs official (open, controls), premium panel
  04_tables.R              table1 (paper window and full sample), table A1 (all countries)
  05_events.R              table2 and fig4: event windows (Argentina 2019, Ukraine 2022)
data/
  README.md                source, download date, structure, frequency check, caveats
  raw/                     IMF WP-CPER CSV exactly as downloaded (never modified)
  derived/                 rebuilt by 01_clean.R (git-ignored)
output/
  figures/                 fig1-fig4 (PNG)
  tables/                  CSV and LaTeX tables, validation checks, series inventory
summary/
  replication_summary.tex  short write-up; \input's tables from output/tables
  replication_summary.pdf  compiled version
```

## Software

- R 4.5.2 (2025-10-31), Windows 11. Package versions are pinned in `renv.lock`; the direct dependencies are:

  | Package | Version |
  |---|---|
  | renv | 1.3.1 |
  | here | 1.0.2 |
  | dplyr | 1.2.1 |
  | tidyr | 1.3.2 |
  | readr | 2.2.0 |
  | ggplot2 | 4.0.3 |
  | scales | 1.4.0 |
  | sandwich | 3.1-3 |

- Optional, for the PDF: a LaTeX distribution with `pdflatex` (built with MiKTeX 26.5, pdfTeX 4.27). Required LaTeX packages: geometry, graphicx, booktabs, float, amsmath, hyperref.

## Reproduce from a clean clone

1. Clone the repo and enter it:

   ```bash
   git clone https://github.com/apatani31/stat5200_replication.git
   ```

   ```bash
   cd stat5200_replication
   ```

2. Run the whole pipeline. On first run `renv` bootstraps itself and installs the pinned packages into a project library (needs internet once):

   ```bash
   Rscript run_all.R
   ```

3. Optionally rebuild the PDF summary as well:

   ```bash
   Rscript run_all.R --pdf
   ```

No manual steps are needed. All paths are relative (`here::here()`), and the raw data file is committed (410 KB), so nothing has to be downloaded apart from R packages. A full run takes well under a minute after packages are installed.

## Expected outputs

| File | Content |
|---|---|
| `data/derived/panel_country_month.csv` | Tidy panel: `iso3, country, currency, date, shadow, official, premium_pct_file, volume_usd, volume_btc, premium` |
| `data/derived/wpcper_long.csv` | One row per series and month |
| `output/tables/validation_checks.csv` | Premium formula check (max gap 4.9e-6 pp over 2,095 obs), US benchmark, monthly averaging test |
| `output/tables/series_inventory.csv` | Every series with first and last month and number of observations |
| `output/tables/table1_premium_summary.csv`, `table1_*.tex` | Per country: N, mean with Newey-West SE and t, median, SD, share of months with abs(premium) > 5%, max, min, correlation with US premium |
| `output/tables/table_a1_all_countries*` | Same statistics for all 33 economies with crypto data |
| `output/tables/table2_event_windows.*` | Pre, month 0 and post means around the two events |
| `output/figures/fig1_open_shadow_vs_official.png` | Brazil, Mexico, UK, Japan |
| `output/figures/fig2_controls_shadow_vs_official.png` | Argentina, Ukraine, Nigeria |
| `output/figures/fig3_premium_panel.png` | Premium for all seven countries with the 5% band |
| `output/figures/fig4_event_windows.png` | Event windows of plus or minus 6 months |

Headline numbers (paper window, 2019-01 to 2023-07, monthly):

| Country | Median premium | Share of months above 5% | NW t-stat of mean |
|---|---|---|---|
| Brazil | 0.74% | 0.05 | 2.12 |
| Mexico | -0.05% | 0.02 | -0.43 |
| Argentina | 78.1% | 0.93 | 7.78 |
| Nigeria | 27.3% | 1.00 | 6.11 |
| Ukraine | 0.45% (pre-invasion 1.5%, post 13.0%) | 0.25 | 1.82 |

## Data at a glance

See [`data/README.md`](data/README.md) for full details. The main points:

- **Monthly only.** The IMF Data Explorer and SDMX API offer only monthly frequency for WP-CPER (checked 2026-11-10). The paper used daily data. The monthly values are period averages.
- **Coverage.** 33 economies have crypto rates, January 2019 to October 2025. There are **no euro area, Turkiye or Egypt series**, so three of the paper's eight case-study panels cannot be reproduced. The UK and Japan are shown as labelled stand-ins for the euro area.
- **The shadow rate is taken from the file, not recomputed.** The file does not include the underlying BTC prices. Our premium matches the IMF's published premium exactly.

## What was reproduced and what was not

- **Reproduced:** H1 (open-account premia near zero), H2 (large, persistent premia in Argentina and Nigeria; Ukraine's jump after the invasion), and the observation that Ukraine's July 2022 devaluation moved the official rate to roughly the shadow rate.
- **Not reproduced:** the euro area, Turkiye and Egypt panels (not in the data); daily dynamics (monthly data only); H3 (see below).
- **Differs:** Argentina's premium already reached 12 to 18% in early 2019, before the September 2019 controls. Open-economy deviations correlate 0.6 to 0.8 with the US premium, so they are mostly benchmark noise.

## Judgement calls to be aware of

- **Event dates are my reading of the paper**, not dates the paper states. The paper says Argentina reintroduced restrictions "in the 2019 election year" with the premium rising from "late 2019". I use Decree 609/2019 (1 Sept 2019). For Ukraine it refers to "the Russian invasion"; I use 24 Feb 2022, and mark the NBU devaluation of 21 Jul 2022 as a secondary event. Both are set in `code/00_setup.R`.
- **Event windows** are plus or minus 6 months because the data are monthly (a daily study would use something like plus or minus 60 days). The event month is excluded from pre and post means because it averages days on both sides of the event.
- **Newey-West lag** is `floor(4 (T/100)^(2/9))`, which equals 3 for both T = 55 and T = 82.
- **H3 is skipped.** The paper's ban list is Library of Congress (2021) data "updated by the authors" and is not published. I could not get the paper's vintage of the Baba et al. financial openness index (threshold 0.5, paper footnote 10) from a reliable source. Building either one by hand would be guesswork.
