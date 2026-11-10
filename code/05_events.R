# 05_events.R
# Event windows around Argentina's Sept 2019 controls and Ukraine's Feb 2022
# invasion. With monthly data the window is +/- EVENT_K months and the event
# month itself (t = 0) is shown but excluded from pre/post means, because it
# averages days on both sides of the event.

source(here::here("code", "00_setup.R"))
panel <- readr::read_csv(file.path(DERIVED_DIR, "panel_country_month.csv"), show_col_types = FALSE)

wins <- lapply(seq_len(nrow(EVENTS)), function(i) {
  e <- EVENTS[i, ]
  w <- event_window(panel, e$iso3, e$event_date, EVENT_K)
  w$event <- paste0(CONTROLS_SET[[e$iso3]], ": ", e$event, " (", format(e$event_date, "%d %b %Y"), ")")
  w
})
win_df <- dplyr::bind_rows(wins)

ev_tab <- dplyr::bind_rows(lapply(seq_len(nrow(EVENTS)), function(i) {
  dplyr::bind_cols(EVENTS[i, ], event_summary(wins[[i]]))
}))
readr::write_csv(ev_tab, file.path(TAB_DIR, "table2_event_windows.csv"))
write_tex_table(
  ev_tab |> dplyr::transmute(Country = CONTROLS_SET[iso3], Event = event,
                             `Pre mean %` = pre_mean_pct, `Month 0 %` = month0_pct,
                             `Post mean %` = post_mean_pct, `Change pp` = diff_pp),
  file.path(TAB_DIR, "table2_event_windows.tex"), align = "llrrrr")
print(ev_tab, width = 160)

# Ukraine devaluation marker, in event time relative to the invasion month.
ukr_deval_t <- (as.integer(format(UKR_DEVALUATION, "%Y")) - 2022) * 12 + as.integer(format(UKR_DEVALUATION, "%m")) - 2
deval_df <- tibble::tibble(event = unique(win_df$event[win_df$iso3 == "UKR"]), t = ukr_deval_t,
                           lab = "NBU devaluation\n21 Jul 2022")

p4 <- ggplot2::ggplot(win_df, ggplot2::aes(t, 100 * premium)) +
  ggplot2::annotate("rect", xmin = -Inf, xmax = Inf, ymin = -100 * PREMIUM_THRESHOLD,
                    ymax = 100 * PREMIUM_THRESHOLD, fill = "grey92") +
  ggplot2::geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.4) +
  ggplot2::geom_vline(data = deval_df, ggplot2::aes(xintercept = t), colour = "grey40",
                      linewidth = 0.3, linetype = "22") +
  ggplot2::geom_text(data = deval_df, ggplot2::aes(x = t, y = -Inf, label = lab),
                     vjust = -0.4, hjust = 1.05, size = 2.8, colour = "grey30") +
  ggplot2::geom_line(colour = COL_SHADOW, linewidth = 0.6) +
  ggplot2::geom_point(colour = COL_SHADOW, size = 1.6) +
  ggplot2::facet_wrap(~event, scales = "free_y") +
  ggplot2::scale_x_continuous(breaks = seq(-EVENT_K, EVENT_K, 2)) +
  ggplot2::labs(x = "Months relative to event month (t = 0)", y = "Premium, %",
                title = "Crypto shadow premium around capital-flow shocks",
                subtitle = "Monthly data, +/- 6 months. Grey band: |premium| <= 5%. Event dates are my reading of the paper.") +
  theme_rep()
ggsave(file.path(FIG_DIR, "fig4_event_windows.png"), p4, width = 9, height = 4, dpi = 200, bg = "white")
message("05_events: wrote table2 and fig4")
