cap cls
clear all
set more off

* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"
*adopath + "$data/sa_census/x13as"

* ---------------------------------------------------------------------------
* Upload
* ---------------------------------------------------------------------------
use "$data/clean/cps_mincer_wage.dta", clear

* ---------------------------------------------------------------------------
* Average wage for all workers (quarterly average)
* ---------------------------------------------------------------------------
preserve 
	collapse (mean) e_wage_all_p [aw=earnwt], by(yq)
	tempfile wage_all_p
	save `wage_all_p', replace
restore

* ---------------------------------------------------------------------------
* Average wage for new hires from unemployment (quarterly average)
* ---------------------------------------------------------------------------
preserve 
	collapse (mean) e_wage_nhu_p [aw=earnwt], by(yq)
	tempfile wage_nhu_p
	save `wage_nhu_p', replace
restore
 
* ---------------------------------------------------------------------------
* Average wage for new hires from other jobs (quarterly average)
* ---------------------------------------------------------------------------
preserve 
	collapse (mean) e_wage_nhc_p [aw=earnwt], by(yq)
	tempfile wage_nhc_p
	save `wage_nhc_p', replace
restore


* ---------------------------------------------------------------------------
* Upload
* ---------------------------------------------------------------------------
use "$data/clean/cps_clean.dta", clear

preserve
	* ---------------------------------------------------------------------------
	* Total number of hires from unemployment
	* ---------------------------------------------------------------------------
	sort cpsidp ym

	*Generate lagged variables for employment status and weight
	gen emp_last_month = L1.l_status
	gen wt_last_month = L1.wtfinl

	*Calculate average weight over two months
	gen avg_weight = (wtfinl + wt_last_month) / 2 if emp_last_month != .

	*unemployed in t-1 and employed in t 
	gen unemp_to_emp = .
	replace unemp_to_emp = 1 if emp_last_month == 2 & l_status == 1
	replace unemp_to_emp = 0 if emp_last_month == 2 & l_status == 2
	label variable unemp_to_emp "unemployed in t-1 and employed in t"

	* ---------------------------------------------------------------------------
	* Total number of hires from non-employment
	* ---------------------------------------------------------------------------
	* Identify newly employed workers: not employed in t-1 and employed in t
	gen newly_employed = (l_status == 1 & emp_last_month != 1 & emp_last_month != .)
	label variable newly_employed "not employed in t-1 and employed in t"
		
	* ---------------------------------------------------------------------------
	* Calculate total number of hires from non-employment and from unemployment
	* ---------------------------------------------------------------------------	
	collapse (sum) newly_employed unemp_to_emp [pw=avg_weight], by(yq)
	tempfile total_flows
	save `total_flows', replace
restore

* ---------------------------------------------------------------------------
* Fraction of unemployed workers in t-1 that are employed in t:
* ---------------------------------------------------------------------------
*Sort data by cpsidp and time
sort cpsidp ym

*Generate lagged variables for employment status and weight
gen emp_last_month = L1.l_status
gen wt_last_month = L1.wtfinl

*Calculate average weight over two months
gen avg_weight = (wtfinl + wt_last_month) / 2 if emp_last_month != .

*unemployed in t-1 and employed in t 
gen unemp_to_emp = .
replace unemp_to_emp = 1 if emp_last_month == 2 & l_status == 1
replace unemp_to_emp = 0 if emp_last_month == 2 & l_status == 2
label variable unemp_to_emp "unemployed in t-1 and employed in t"

collapse (mean) unemp_to_emp [aw=avg_weight], by(yq)

* ---------------------------------------------------------------------------
* Merge in average wages and total number of hires:
* ---------------------------------------------------------------------------
merge 1:1 yq using `wage_all_p', keep(3) nogen
merge 1:1 yq using `wage_nhu_p', keep(3) nogen
merge 1:1 yq using `wage_nhc_p', keep(3) nogen
merge 1:1 yq using `total_flows', keep(3) nogen

* ---------------------------------------------------------------------------------------------------
* Merge in total number of unemployed workers and LF Flows from FRED, Real nonfarm GDP, Help Wanted Index
* ---------------------------------------------------------------------------------------------------
merge 1:1 yq using "$data/clean/total_unemployed_FRED.dta", keep(3) nogen
merge 1:1 yq using "$data/clean/rgdp_FRED.dta", keep(3) nogen
merge 1:1 yq using "$data/clean/composite_hwi.dta", keep(3) nogen
merge 1:1 yq using "$data/clean/nlf_to_emp_FRED.dta", keep(3) nogen
merge 1:1 yq using "$data/clean/unemp_to_emp_FRED.dta", keep(3) nogen

* ---------------------------------------------------------------------------------------------------
* Save
* ---------------------------------------------------------------------------------------------------
save "$data/clean/series1.dta", replace

* ---------------------------------------------------------------------------------------------------
* Merge in seasonally adjusted data. Run s3_export_series1.DO, this will save series1 in the 
* FAME program folder. After you SA make sure to convert the xls to stata dta 
* and save it as: "$data/clean/fame_series1_sa.dta".
* ---------------------------------------------------------------------------------------------------
use "$data/clean/series1.dta", clear

merge 1:1 yq using "$data/clean/fame_series1_sa.dta", nogen

save "$data/clean/series1_sa.dta", replace
