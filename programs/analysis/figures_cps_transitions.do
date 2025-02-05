cap cls
clear all
set more off

* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

* ---------------------------------------------------------------------------
* Upload 1994-2024 CPS data
* ---------------------------------------------------------------------------
use "$data/cps_1994_2024.dta", clear

* ---------------------------------------------------------------------------
* General Cleaning and Variable Construction
* ---------------------------------------------------------------------------
*generate year-month variable
gen ym = ym(year,month)
format ym %tm

*set as a panel
xtset cpsidp ym

/*cleaning */
keep if age >= 16 & age <= 64

*drop individuals in armed forces:
drop if empstat == 1

*recode empstat to be employed, unemployed, and NILF:
gen employment_status = . 
replace employment_status = 1 if inlist(empstat,10,12)
replace employment_status = 2 if inlist(empstat,21,22)
replace employment_status = 3 if inlist(empstat,32,34,36)

label define employment_status 1 "employed"
label define employment_status 2 "unemployed", add
label define employment_status 3 "nilf", add
label values employment_status employment_status

*generate different job indicator
gen different_job = empsame == 1
label variable different_job "has a different job"

* ------------------------------------------------------------------------------------------------------
* Calculate the following:
* 1.) Total number of workers that are employed this month but were not employed last month;
* 2.) Total number of workers that were unemployed in the previous month and are employed this month;
* 3.) Total number of workers that were employed in the previous month, are employed this month, 
* but have a different job
* ------------------------------------------------------------------------------------------------------
preserve
	keep year month ym cpsidp wtfinl employment_status different_job

	* Sort the data to align individuals by cpsidp and time
	sort cpsidp ym

	* Generate a lagged variable for employment status and weight
	gen emp_last_month = L1.employment_status
	gen wt_last_month = L1.wtfinl

	* Calculate the average weight over the two months
	gen avg_weight = (wtfinl + wt_last_month) / 2 if emp_last_month != .
	replace avg_weight = round(avg_weight)

	* Identify newly employed workers
	gen newly_employed = (employment_status == 1 & emp_last_month != 1 & emp_last_month != .)
	label variable newly_employed "employed in t that were not employed in t-1"
	
	*Identify transitions from unemployment to employment
	gen unemp_to_emp = (emp_last_month == 2 & employment_status == 1)
	label variable unemp_to_emp "unemployed in t-1 and employed in t"
	
	* Identify workers employed in both months with a different job
	gen emp_diff_job = (emp_last_month == 1 & employment_status == 1 & different_job == 1)
	label variable emp_diff_job "employed in t-1, are employed in t, but different job"
	
	* Compute the weighted total of newly employed workers
	collapse (sum) newly_employed unemp_to_emp emp_diff_job [fw=avg_weight], by(ym)
	
	*figure out the spikes in 1995--why is this? 
	*this is data issues for 1995m7-m8 in the CPS. 
	foreach x in newly_employed unemp_to_emp emp_diff_job {
		replace `x' = . if ym == ym(1995,7) | ym == ym(1995,8)
	}
	
	twoway ///
	(line newly_employed ym, lcolor(blue) lwidth(medium)) ///
	(line unemp_to_emp ym, lcolor(red) lwidth(medium)) ///
	(line emp_diff_job ym, lcolor(green) lwidth(medium)), ///
	ytitle("Number of Individuals") ///
	xtitle("Year-Month") ///
	legend(order(1 "Newly Employed" 2 "Unemployed to Employed" 3 "Employed in Different Job") ///
		position(6)) ///
	title("Labor Market Flows")
restore

* ----------------------------------------------------------------------------------------------------------
* Calculate the following:
* 4.) Fraction of unemployed workers in the previous month that are employed this month; 
* 5.) Fraction of workers that were employed in the previous month but report that they have a different job;
* 6.) Fraction of employed workers in the previous month that are employed this month
* ----------------------------------------------------------------------------------------------------------
preserve
	*year month cpsidp wtfinl (final weight); employment_status (1=emp, 2=unemp, 3=NILF); different_job (=1 if yes); 
	keep year month ym cpsidp wtfinl employment_status different_job

	*Sort data by cpsidp and time
	sort cpsidp ym

	*Generate lagged variables for employment status and weight
	gen emp_last_month = L1.employment_status
	gen wt_last_month = L1.wtfinl

	*Calculate average weight over two months
	gen avg_weight = (wtfinl + wt_last_month) / 2 if emp_last_month != .

	*unemployed in t-1 and employed in t 
	gen unemp_to_emp = .
	replace unemp_to_emp = 1 if emp_last_month == 2 & employment_status == 1
	replace unemp_to_emp = 0 if emp_last_month == 2 & employment_status == 2
	label variable unemp_to_emp "unemployed in t-1 and employed in t"
	
	*employed in t-1 and employed in t but different job.
	gen emp_diff_job = .
	replace emp_diff_job = 1 if (employment_status == 1 & emp_last_month == 1 & different_job == 1)
	replace emp_diff_job = 0 if (employment_status == 1 & emp_last_month == 1 & different_job == 0)
	label variable emp_diff_job "employed in t-1 and t but different job"
	
	*employed in t-1 and unemployed in t
	gen emp_to_unemp = .
	replace emp_to_unemp = 1 if (emp_last_month == 1 & employment_status == 2)
	replace emp_to_unemp = 0 if (emp_last_month == 1 & employment_status == 1)
	label variable emp_to_unemp "employed in t-1 and unemployed in t"
	
	*employed in t-1 and not employed in t
	gen emp_not_emp = .
	replace emp_not_emp = 1 if (emp_last_month == 1 & employment_status != 1)
	replace emp_not_emp = 0 if (emp_last_month == 1 & employment_status == 1)
	label variable emp_not_emp "employed in t-1 and unemployed in t"
	
	*Compute the fraction directly using mean with frequency weights
	collapse (mean) unemp_to_emp emp_diff_job emp_to_unemp emp_not_emp [aw=avg_weight], by(ym)

	*figure out the spikes in 1995--why is this? 
	*this is data issues for 1995m7-m8 in the CPS. 
	foreach x in unemp_to_emp emp_diff_job emp_to_unemp emp_not_emp {
		replace `x' = . if ym == ym(1995,7) | ym == ym(1995,8)
	}
	
	twoway ///
	(line emp_diff_job ym, lcolor(red) lwidth(medium)) ///
	(line emp_to_unemp ym, lcolor(black) lwidth(medium)), ///
	ytitle("Fraction of Individuals") ///
	ylabel(, format(%9.2f)) ///
	xtitle("Year-Month") ///
	legend(order(1 "Employed but Different Job" 2 "Employed to Unemployed" ) ///
		position(6)) ///
	title("Labor Market Flows")

	*unemployed to employed: 
	twoway ///
	(line unemp_to_emp ym, lcolor(green) lwidth(medium)), ///
	ytitle("Fraction of Individuals") ///
	ylabel(, format(%9.2f)) ///
	xtitle("Year-Month") ///
	title("Unemployed to Employed")

	*employed to not employed: 
	twoway ///
	(line emp_not_emp ym, lcolor(green) lwidth(medium)), ///
	ytitle("Fraction of Individuals") ///
	ylabel(, format(%9.2f)) ///
	xtitle("Year-Month") ///
	title("Employed to Not Employed")
	
restore
	
