DATA
====

The analysis data set and the raw source files are not distributed here because
of their size; all are publicly available (see links below). Place the files as
follows before running the full pipeline (Path A in ../README.md).

Expected layout
---------------
data/
  final_smoking_analysis_dataset.dta   <- output of code/01_build_analysis_dataset.do
  raw/
    brfss/   BRFSS<year>.dta            (annual BRFSS files, 1995-2012)
    tax/     The_Tax_Burden_on_Tobacco__1970-2019_*.csv
    bans/    Table_9078.xls  (restaurant smoking restrictions)
             Table_3207.xls  (mall/grocery smoking restrictions)

The scripts in ../code/ write all estimates (.csv) and figures (.png) to
../output/ at run time; no results or data are stored in this repository.

Sources
-------
- BRFSS (1995-2012), Centers for Disease Control and Prevention:
  https://www.cdc.gov/brfss/
- The Tax Burden on Tobacco (cigarette excise taxes and retail prices):
  https://chronicdata.cdc.gov/Policy/The-Tax-Burden-on-Tobacco-Glossary-and-Methodology/fip8-rcng/about_data
- CDC STATE System (clean indoor-air laws):
  https://www.cdc.gov/statesystem/

All monetary values are inflation-adjusted to constant 2012 US dollars
(CPI-U), as described in code/01_build_analysis_dataset.do.
