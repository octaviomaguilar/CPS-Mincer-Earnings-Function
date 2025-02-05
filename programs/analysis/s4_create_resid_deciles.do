* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

* ---------------------------------------------------------------------------
* Upload
* ---------------------------------------------------------------------------
use "$data/clean/cps_mincer_wage.dta", clear

* ---------------------------------------------------------------------------
* Generate deciles for the mincer regression residuals
* ---------------------------------------------------------------------------
pctile resid_decile=ln_wage_cps_resid, nq(10)

_pctile ln_wage_cps_resid, nq(10)

*Last row is populated as missing, we can drop this.
keep resid_decile
drop if resid_decile == .
list 

export excel using "$data/clean/mincer_residuals_by_decile.xlsx", replace firstrow(variables)
