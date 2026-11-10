# 03_figures.R
# Paper Figures 6-8 analogues: shadow vs official rates for the open set and
# the controls set, plus a premium panel. Plotted over the full file sample
# with the paper's sample end marked, so readers can see both what the paper
# saw and what happened afterwards.

source(here::here("code", "00_setup.R"))
panel <- readr::read_csv(file.path(DERIVED_DIR, "panel_country_month.csv"), show_col_types = FALSE)

paper_end_line <- ggplot2::geom_vline(xintercept = as.Date("2023-07-13"),
                                      colour = "grey55", linewidth = 0.3, linetype = "dotted")
note <- "Monthly IMF WP-CPER data. Dotted line: end of paper sample (13 Jul 2023)."

p1 <- plot_shadow_official(
  panel, OPEN_SET,
  title = "Open financial accounts: crypto shadow rate tracks the official rate",
  subtitle = paste0("Paper's euro area and Turkiye panels are not in the IMF file; UK and Japan shown instead.\n", note),
  col_official = COL_OFFICIAL, col_shadow = COL_SHADOW) + paper_end_line
ggsave(file.path(FIG_DIR, "fig1_open_shadow_vs_official.png"), p1, width = 8, height = 5.5, dpi = 200, bg = "white")

p2 <- plot_shadow_official(
  panel, CONTROLS_SET,
  title = "Binding capital controls: crypto shadow rate opens a gap",
  subtitle = paste0("Paper's Egypt panel (Binance P2P) is not in the IMF file.\n", note),
  col_official = COL_OFFICIAL, col_shadow = COL_SHADOW) + paper_end_line +
  ggplot2::facet_wrap(~label, scales = "free_y", ncol = 3)
ggsave(file.path(FIG_DIR, "fig2_controls_shadow_vs_official.png"), p2, width = 9, height = 3.8, dpi = 200, bg = "white")

# Premium panel: one small multiple per country rather than one crowded
# chart, because premia differ by two orders of magnitude across groups.
all_sets <- c(OPEN_SET, CONTROLS_SET)
grp <- c(rep("Open", length(OPEN_SET)), rep("Controls", length(CONTROLS_SET)))
names(grp) <- names(all_sets)
d3 <- panel |>
  dplyr::filter(iso3 %in% names(all_sets), !is.na(premium)) |>
  dplyr::mutate(label = factor(all_sets[iso3], levels = all_sets),
                group = factor(grp[iso3], levels = c("Open", "Controls")))
p3 <- ggplot2::ggplot(d3, ggplot2::aes(date, 100 * premium)) +
  ggplot2::annotate("rect", xmin = as.Date(-Inf), xmax = as.Date(Inf),
                    ymin = -100 * PREMIUM_THRESHOLD, ymax = 100 * PREMIUM_THRESHOLD,
                    fill = "grey92") +
  ggplot2::geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  ggplot2::geom_line(ggplot2::aes(colour = group), linewidth = 0.6) +
  paper_end_line +
  ggplot2::facet_wrap(~label, scales = "free_y", ncol = 4) +
  ggplot2::scale_colour_manual(values = c(Open = COL_OFFICIAL, Controls = COL_SHADOW), name = NULL) +
  ggplot2::labs(x = NULL, y = "Premium, % (shadow / official - 1)",
                title = "Crypto shadow premium by country",
                subtitle = paste("Grey band: |premium| <= 5%. Y axes differ by panel.", note)) +
  theme_rep()
ggsave(file.path(FIG_DIR, "fig3_premium_panel.png"), p3, width = 10, height = 5, dpi = 200, bg = "white")

message("03_figures: wrote fig1-fig3 to output/figures")
