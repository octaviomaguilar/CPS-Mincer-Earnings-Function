cap cls
clear all
set more off

* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

*-----------------------------------------------------------------------
* Import CPS unemployment (in thousands), retreived from FRED.
*----------------------------------------------------------------------- 
import excel "$data/raw/FRED_unemp.xlsx", sheet("Quarterly") firstrow clear

*adjust the date to be in year-quarter format:
gen yq = yq(year(observation_date), quarter(observation_date))
format yq %tq

*rename series:
rename UNEMPLOY total_unemployed
label variable total_unemployed "Total number of unemployed workers (qrtly-avg)"
keep total_unemployed yq

*save the data:
save "$data/clean/total_unemployed_FRED.dta", replace

*-----------------------------------------------------------------------
* Import BEA reported real GDP, retreived from FRED. 
*----------------------------------------------------------------------- 
import excel "$data/raw/FRED_rgdp.xlsx", sheet("Quarterly") firstrow clear

*adjust the date to be in year-quarter format:
gen yq = yq(year(observation_date), quarter(observation_date))
format yq %tq

*rename series:
rename A358RX1Q020SBEA rgdp
label variable rgdp "Real GDP excluding farming"
keep rgdp yq

*save the data:
save "$data/clean/rgdp_FRED.dta", replace

*-----------------------------------------------------------------------
* Import help-wanted index from Barnichon (2010). The series is complete  
* to 2025 by using JOLTS and labor force data from FRED. See README
* for additional information on the construction. 
*----------------------------------------------------------------------- 
import excel "$data/raw/CompositeHWI.xlsx", sheet("data") firstrow clear

*generate year-month variable
rename year date
gen year = substr(date,1,4)
gen month = substr(date,6,6)

foreach x in year month {
	destring `x', replace
}

*generate a year-month indicator:
gen ym = ym(year,month) 
format ym %tm

*generate a year-qtr indicator: 
gen yq = yq(year(dofm(ym)), quarter(dofm(ym)))
format yq %tq

*collapse the data to take the quarterly average: 
collapse (mean) V_hwi V_LF, by(yq)

label variable V_hwi "HWI quarterly average"
label variable V_LF "V/size of the LF"

drop if yq == .
*save the data:
save "$data/clean/composite_hwi.dta", replace

*-----------------------------------------------------------------------
* Import unemployed to employed flows, retreived from FRED. 
*----------------------------------------------------------------------- 
import excel "$data/raw/FRED_unemp_emp.xlsx", sheet("Quarterly") firstrow clear

*adjust the date to be in year-quarter format:
gen yq = yq(year(observation_date), quarter(observation_date))
format yq %tq

*rename series:
rename LNS17100000 fred_unemp_to_emp
label variable fred_unemp_to_emp "unemployed to employed from FRED"
keep fred_unemp_to_emp yq

*save the data:
save "$data/clean/unemp_to_emp_FRED.dta", replace

*-----------------------------------------------------------------------
* Import nlf to employed flows, retreived from FRED. 
*----------------------------------------------------------------------- 
import excel "$data/raw/FRED_nlf_emp.xlsx", sheet("Quarterly") firstrow clear

*adjust the date to be in year-quarter format:
gen yq = yq(year(observation_date), quarter(observation_date))
format yq %tq

*rename series:
rename LNS17200000 fred_nlf_to_emp
label variable fred_nlf_to_emp "NLF to employed from FRED"
keep fred_nlf_to_emp yq

*save the data:
save "$data/clean/nlf_to_emp_FRED.dta", replace
