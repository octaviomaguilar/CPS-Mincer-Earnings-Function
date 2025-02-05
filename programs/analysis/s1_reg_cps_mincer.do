* ---------------------------------------------------------------------------
* reg_msample_morg
* ---------------------------------------------------------------------------
*
* Compute wages by pooling. THIS USES MORG WAGES INSTEAD OF IPUMS
*		- running one regression for complete sample (1979-2015)
*		- Males & Females, and Males only
*		- ENE and Changers after 1994
*		- Weighting by hours
*		- 20-60, 25-60, 30-45
*		- 1 and 3 months definition
*
* ---------------------------------------------------------------------------
* The Cyclical Behavior of Unemployment and Wages under Information Frictions
* Camilo Morales-Jimenez
* Spring 2020
* ---------------------------------------------------------------------------
*
* Notes:1) Using this definitions for transitions (in which I am controling 
*		for not changing a job), it doesn't make sence to start before 1994
*
*		2) I decided not to run the same regression changing the wage definition
*		they are very correlated and there is not a big difference.
*
*		3) Keep in mind that I am running first differece for FE, variance is NOT!!!!!!!!!!!!!
*		the same.
*
*		4) All regressions for private wage, non-aggricultural, and people between 20 and 60
* ---------------------------------------------------------------------------
clear all
set more off
set mem 600m
set maxvar 32000
set matsize 11000
capture log close

* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

* ---------------------------------------------------------------------------
* Parameters
* ---------------------------------------------------------------------------
local iyear = 1994
local lyear = 2019

* ---------------------------------------------------------------------------
* Upload
* ---------------------------------------------------------------------------
use "$data/clean/cps_clean.dta", clear

* ---------------------------------------------------------------------------
* Generate variables
* ---------------------------------------------------------------------------
gen group_nhu  = ENE_alt
gen group_nhc  = EE

* Generate variables
xtset, clear
tsset cpsidp ym

tab marst, gen(marital)
tab occ, gen(occupation)
tab ind, gen(industry)
tab statefip, gen(state)
tab ym, gen(DT_)

local nmonth = (`lyear' +1 -`iyear')*12
foreach i of numlist 1/`nmonth' {
	gen DTnhu_`i'=DT_`i'*group_nhu
	gen DTnhc_`i'=DT_`i'*group_nhc
}

* Drop dummies that are not used at all
drop statefip industry1 DT_1

* Keep only observations that are used
keep if class_worker == 1 & ind > 1 & age>=20 & age<=60 & ind*age!=.

* Redefine panel so I can run FE regressions
*gen tint = mish/4
*tsset cpsidp tint
tsset cpsidp ym

* ---------------------------------------------------------------------------
* Run regressions
* ---------------------------------------------------------------------------

*********************
* All
*********************
reg lnwage_cps gradeate exp* Female nWhite hispan marital* occupation* industry* state* DT_* DTnhu_* DTnhc_* [aw=earnwt*ahrswork1]
predict ln_wage_cps_resid, residuals

quietly {
gen wage_all_p = .
gen wage_nhu_p = .
gen wage_nhc_p = .

gen wagen_all_p = .
gen wagen_nhu_p = .
gen wagen_nhc_p = .




local nn = 1
foreach yy of numlist `iyear'/`lyear' {
	foreach mm of numlist 1/12 {
	
	if `nn'==1 {
		replace wage_all_p = 0 if year==`yy' & month == `mm'
		replace wage_nhu_p = _b[DTnhu_`nn'] if year==`yy' & month == `mm'  & _b[DTnhu_`nn']!=0
		replace wage_nhc_p = _b[DTnhc_`nn'] if year==`yy' & month == `mm'  & _b[DTnhc_`nn']!=0
	}
	else {
	if _b[DT_`nn']!=0 {
		replace wage_all_p = _b[DT_`nn'] if year==`yy' & month == `mm'
		replace wage_nhu_p = _b[DT_`nn'] +_b[DTnhu_`nn'] if year==`yy' & month == `mm'  & _b[DTnhu_`nn']!=0
		replace wage_nhc_p = _b[DT_`nn'] +_b[DTnhc_`nn'] if year==`yy' & month == `mm'  & _b[DTnhc_`nn']!=0
	}
	}
		local nn = `nn'+1
	}
}
}	

	* No controling
	reg lnwage_cps DT_* DTnhu_* DTnhc_* [aw=earnwt*ahrswork1] if e(sample)==1 
quietly {
	local nn = 1
	foreach yy of numlist `iyear'/`lyear' {
		foreach mm of numlist 1/12 {
	
		if `nn'==1 {
			replace wagen_all_p = 0 if year==`yy' & month == `mm'
			replace wagen_nhu_p = _b[DTnhu_`nn'] if year==`yy' & month == `mm'  & _b[DTnhu_`nn']!=0
			replace wagen_nhc_p = _b[DTnhc_`nn'] if year==`yy' & month == `mm'  & _b[DTnhc_`nn']!=0
		}
		else {
		if _b[DT_`nn']!=0 {
			replace wagen_all_p = _b[DT_`nn'] if year==`yy' & month == `mm'
			replace wagen_nhu_p = _b[DT_`nn'] +_b[DTnhu_`nn'] if year==`yy' & month == `mm' & _b[DTnhu_`nn']!=0
			replace wagen_nhc_p = _b[DT_`nn'] +_b[DTnhc_`nn'] if year==`yy' & month == `mm' & _b[DTnhc_`nn']!=0 
		}
		}
			local nn = `nn'+1
		}
	}

}

foreach x in wage_all_p wage_nhu_p wage_nhc_p wagen_all_p wagen_nhu_p wagen_nhc_p {
	gen e_`x' = exp(`x')
}

keep wage_all_p wage_nhu_p wage_nhc_p wagen_all_p wagen_nhu_p wagen_nhc_p year month cpsidp earnwt ahrswork1 ym yq lnwage_cps wage ln_wage_cps_resid e_wage_all_p e_wage_nhu_p e_wage_nhc_p e_wagen_all_p e_wagen_nhu_p e_wagen_nhc_p


save "$data/clean/cps_mincer_wage.dta", replace
