cap cls
clear all
set more off

* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

* ---------------------------------------------------------------------------
* Upload
* ---------------------------------------------------------------------------
use "$data/clean/series1.dta", clear

* ---------------------------------------------------------------------------
* Keep only the variables that need to be seasonally adjusted 
* ---------------------------------------------------------------------------
keep yq unemp_to_emp e_wage_all_p e_wage_nhu_p e_wage_nhc_p newly_employed

* ---------------------------------------------------------------------------
* Export to excel: this will live in the FAME program folder.
* ---------------------------------------------------------------------------
export excel using "$home/programs/fame/series1.xls", firstrow(variables) replace
