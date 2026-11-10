# Data

## Source

- **Dataset:** IMF, *Crypto-based Parallel Exchange Rates* (WP-CPER), dataflow `IMF.STA:WPCPER`, version 6.0.0.
  Landing page: https://data.imf.org/en/datasets/IMF.STA:WPCPER
- **Companion paper:** Graf von Luckner, C., Koepke, R. and Sgherri, S. (2024), "Crypto as a Marketplace for Capital Flight", IMF Working Paper 24/133.
- **Download:** IMF Data Explorer, "full dataset", CSV, one time series per row with metadata columns.
  The timestamp in the file name gives the export time: **2026-11-10 15:39:14 UTC**.
- **Raw file:** `data/raw/dataset_2026-11-10T15_39_14.935556468Z_DEFAULT_INTEGRATION_IMF.STA_WPCPER_6.0.0.csv`
  (410,470 bytes; SHA-256 `01833217c599a27b663d4fcaa92fffdeb95590418a53ae463e850ea173a6773f`).
  It is kept exactly as downloaded. Nothing in the pipeline writes to `data/raw/`.
- **Licence:** IMF copyright, public (unrestricted) access level as stated in the file's metadata columns.

## Structure

164 rows (one per series) by 117 columns: 35 metadata columns (`DATASET`, `SERIES_CODE`, `CURRENCY`, `COUNTRY`, `INDICATOR`, `FREQUENCY`, `SCALE`, `FULL_DESCRIPTION`, ...) followed by 82 monthly columns `2019-M01` to `2025-M10`.

`SERIES_CODE` has the form `CUR.ISO.INDICATOR.FREQ`, for example `ARS.ARG.BIT_SHD_RT.M`.

| Indicator code | Label in file | Unit | Series |
|---|---|---|---|
| `BIT_SHD_RT` | Crypto-based Parallel Exchange Rate (LCU/USD) | local currency per USD | 33 |
| `XDC_USD_RT` | Official FX Rate, LCU/USD | local currency per USD | 64 |
| `BIT_SHD_PT` | Crypto-based Parallel Exchange Rate Premium (in %) | percent | 33 |
| `TVBIT_USD` | Bitcoin trade volume in local market (in USD) | see caveat 5 | 33 |
| `TVBIT` | Trade volume in local market (number of bitcoin traded) | coins | 1 (Brazil, empty) |

So the file is **not** three series per country. 33 economies have the full crypto set (shadow rate, premium, volume, official rate). Another 29 countries and 2 currency unions (CFA franc BEAC and BCEAO) have only the official rate. `output/tables/series_inventory.csv` (written by `code/01_clean.R`) lists every series with its first and last month and number of observations.

**Economies with crypto data (33):** Argentina, Australia, Brazil, Canada, Chile, Colombia, Czech Republic, Georgia, India, Indonesia, Israel, Japan, Kenya, Kyrgyz Republic, Malaysia, Mexico, New Zealand, Nigeria, Peru, Philippines, Romania, Singapore, South Africa, Switzerland, Taiwan Province of China, Thailand, Uganda, Ukraine, United Arab Emirates, United Kingdom, United States, Vietnam, Zambia.

Coverage within these varies a lot: 19 have all 82 months, while Georgia (11 months), Kenya (11), Kyrgyz Republic (10), Romania (7), Vietnam (16), Zambia (21) and Uganda (26) are short.

## Frequency

**The data are monthly only.** Every row has `FREQUENCY = Monthly`. Before accepting this I queried the IMF SDMX API (`api.imf.org/external/sdmx/2.1`) on 2026-11-10:

- a request for the daily key `ARS.ARG.BIT_SHD_RT.D` returned no observations;
- the full dataflow (`.../data/IMF.STA,WPCPER/all`) returned 10,135 observations, all with `FREQUENCY = M`;
- the availability constraint for the `FREQUENCY` dimension lists only `M`.

The paper used daily closes (1 Jan 2019 to 13 Jul 2023). The daily series are not published through the IMF portal.

**Monthly values are period averages, not end of month.** The file does not say, so `code/02_validate.R` tests it with Ukraine, whose official rate was fixed at 29.2549 from 24 Feb 2022 and moved to 36.5686 on 21 Jul 2022. The file has 28.41 for Feb 2022 (below the peg), exactly 29.2549 for Mar to Jun 2022, 31.85 for Jul 2022 (between the two pegs) and 36.5686 from Aug 2022. That pattern only fits monthly averages. One consequence is that a month containing an event mixes days from before and after it.

## Definitions and checks

The file's own description field gives `CryptoShadowRate LC/USD = BTC_LCU / BTC_USD`, where BTC_USD is the international bitcoin price and BTC_LCU the local-market price. That is the paper's definition (Section 4, equation for the crypto shadow rate). The file contains the shadow rate itself but not the two BTC prices, so the ratio cannot be recomputed from prices. The pipeline uses the file's shadow and official rates and computes

    premium = shadow / official - 1

Checks run by `code/02_validate.R` (output in `output/tables/validation_checks.csv`):

- Our premium matches the IMF's published `BIT_SHD_PT` series in all 2,095 country-months, with a maximum absolute difference of 0.000005 percentage points (rounding).
- The US official rate is exactly 1, as it should be.
- The US shadow rate is **not** exactly 1. It deviates by more than 1% in 38 of 82 months and by up to 8.1%. So the "local US market" price and the "international" BTC/USD price come from different exchange sets. We treat the US premium as a measure of cross-exchange noise that has nothing to do with capital controls.

## Caveats

1. **Countries missing relative to the paper.** The file has no euro area, Turkiye or Egypt series, so three of the paper's eight case-study panels cannot be reproduced. The Egypt series in the paper used Binance P2P offers, and P2P data are not in this dataset.
2. **Monthly averaging** smooths spikes. Daily maxima in the paper will be higher than the monthly maxima here.
3. **Sample window.** The file runs to Oct 2025, 27 months beyond the paper. Results are reported for 2019-01 to 2023-07 (the paper window) and for the full sample.
4. **Possible revisions.** This is version 6.0.0 of a dataset that the IMF says it updates periodically. Exchange coverage and weights may differ from the paper vintage.
5. **Volume units.** `TVBIT_USD` is labelled "in USD" but `SCALE` is blank, and several values are implausibly small for monthly USD turnover (for example 14 for the US in Nov 2020, 26 to 28 for Nigeria in mid-2024). The volume series are not used in any result here.
6. **Thin markets.** Short or patchy series (see list above) and large single-month swings (for example Philippines -91%, Malaysia -78%, South Africa -53% minimum premia in the paper window) are more likely to be liquidity artefacts than capital-control signals, as the paper itself warns in its footnote 13.

## Derived data

Written by `code/01_clean.R` to `data/derived/` (regenerated on every run, so safe to delete):

- `wpcper_long.csv`: one row per series and month (`iso3, country, currency, ind_code, freq_code, indicator_label, period, value, date`).
- `panel_country_month.csv`: one row per country and month with columns `shadow, official, premium_pct_file, volume_usd, volume_btc, premium`, where `premium` is our own `shadow / official - 1` as a fraction.
