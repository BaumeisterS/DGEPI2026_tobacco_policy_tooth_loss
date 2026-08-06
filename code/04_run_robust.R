# Driver: prepare the collapsed panel, run the 16 treatment x outcome cells in
# separate R processes (so an estimator failure in one cell cannot abort the rest),
# then build the event-study figures. Run with this folder as the working directory.
rscript <- file.path(R.home("bin"), if (.Platform$OS.type=="windows") "Rscript.exe" else "Rscript")
system2(rscript, c("--vanilla","code/04a_robust_prep.R"))
for (t in c("hightax","highprice","rest","mall"))
  for (o in c("current_smoker","quitting","all_removed","t6_removed"))
    system2(rscript, c("--vanilla","code/04b_robust_cell.R", t, o))
system2(rscript, c("--vanilla","code/04c_event_study_figures.R"))
cat("robust estimators and event-study figures complete\n")
