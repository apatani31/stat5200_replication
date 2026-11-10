# run_all.R
# Reproduces every derived dataset, table and figure from the raw IMF file.
# Usage from the repo root:  Rscript run_all.R
# Optional: Rscript run_all.R --pdf   also compiles summary/replication_summary.tex
# (needs a LaTeX install with pdflatex; skipped with a message otherwise).

if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org")
renv::restore(prompt = FALSE)

scripts <- c("01_clean.R", "02_validate.R", "03_figures.R", "04_tables.R", "05_events.R")
for (s in scripts) {
  message("==== ", s, " ====")
  # Each script runs in a fresh environment so none silently depends on
  # objects left behind by an earlier one.
  sys.source(here::here("code", s), envir = new.env(parent = globalenv()))
}

if ("--pdf" %in% commandArgs(trailingOnly = TRUE)) {
  # Plain pdflatex rather than latexmk: MiKTeX's latexmk needs a separate
  # Perl install on Windows. Two passes resolve references; no bibliography.
  if (nzchar(Sys.which("pdflatex"))) {
    old <- setwd(here::here("summary"))
    on.exit(setwd(old), add = TRUE)
    for (pass in 1:2) {
      status <- system2("pdflatex", c("-interaction=nonstopmode", "-halt-on-error", "replication_summary.tex"),
                        stdout = FALSE)
      if (status != 0) stop("pdflatex failed; see summary/replication_summary.log")
    }
    unlink(c("replication_summary.aux", "replication_summary.log", "replication_summary.out"))
  } else {
    message("pdflatex not found; skipping PDF build.")
  }
}
message("Done. Outputs in output/figures and output/tables.")
