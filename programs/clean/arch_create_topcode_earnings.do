
version 7.0
cap cls
clear all
set more off

global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

*******
**(1)**
*******
*log using "$data/create_topcode_earnings.log", replace

* ---------------------------------------------------------------------------
* Parameters
* ---------------------------------------------------------------------------
local start_year = 1997
local end_year = 1997

* ---------------------------------------------------------------------------
* Loop through each year and month from 1994m1-2024m12
* ---------------------------------------------------------------------------
forval year = `start_year'/`end_year' {
    forval month = 6/6 {

	use if year == `year' & month == `month' using "$data/cps_1994_2024.dta", clear
	
	*-----------------------------------------------------------------------
	* Labor force status (=1 employed, =2 unemployed, =3 NIF, =. other)
	*-----------------------------------------------------------------------
	gen l_status = .
	replace l_status = 1 if empstat == 10 | empstat == 12
	replace l_status = 2 if empstat >= 20 & empstat <= 22 & empstat !=.
	replace l_status = 3 if empstat >= 30 & empstat !=.

	*-----------------------------------------------------------------------
	* earnweek: Earnings per week (includes overtime tips and commissions)
	* topcoded: 9401-9712: 1923
	*			9801-2014: 2884
	*
	* NOTE: Earnwke is corrected by topcoded. Hence this is not equal the
	*       original 
	*-----------------------------------------------------------------------
	replace earnweek = . if earnweek<=0 | earnweek>=9000
		
	replace uhrswork1 = . if uhrswork1 == 999
	replace uhrswork1 = . if uhrswork1 >90

		
	*********************************************************************************
	*********************************************************************************
	* BEGIN *************************************************************************
	*********************************************************************************
	*********************************************************************************

	*********************************************************************************
	* Correct earnings for topcoding (Schmitt):
	*********************************************************************************
	*
	* The following code is copied and modified from:
	* File:	cepr_org_topcode_lognormal.do
	* Date:	Nov 14, 2005, CEPR ORG Version 1.0
	* Desc:	Estimates mean above the top-code for weekly earnings
	*         using the lognormal distribution
	* Copyright 2003 CEPR and John Schmitt
	* Original code and full copyright notice available at www.ceprDATA.net
	* Modified only to reflect different variable naming conventions.
	*
	*********************************************************************************

	* top-code by year
	if 1989<=`year' & `year'<=1997 {
		global topcode=1923 
	}

	if 1998<=`year' {
		global topcode=2884 
	}
	local T=ln($topcode) 

	*********************************************************************************
	* Step 1
	*********************************************************************************
	* a. calculate share of weekly earnings at or above the top-code (PHI)
	*    universe is all those not paid by hour and reporting weekly earnings
	*    not paid by hour is paidhre==2 in NBER data, ==0 in modified data
	rename classwkr class_worker

	gen     tci = 0 if l_status == 1 & class_worker!=0 & paidhour!=2 & earnweek!=. 
	replace tci = 1 if l_status == 1 & class_worker!=0 & paidhour!=2 & earnweek!=. & earnweek>=$topcode

	qui sum tci [aw=earnwt]
	local PHI = 1-r(mean)

	* b. calculate other needed values
	* 	 top-coding implies right-censoring
	*    take natural log of weekly earnings since procedure
	*    assumes weekly earnings are log-normally distributed
	tempvar lnwke
	gen `lnwke' = ln(earnweek) if l_status==1 & class_worker!=0
	sum `lnwke' [aw=earnwt] if tci~=. 

	local X     = r(mean) 
	local SD    = r(sd) 
	local alpha = invnorm(`PHI')
	local lamda = -normden(`alpha')/norm(`alpha')

	* c. calculate estimates of true mean and standard deviation
	local lsigma = (`T'-`X')/(`PHI'*(`alpha'-`lamda'))
	local lmu    = `T' - `alpha'*`lsigma'

	* d. convert from natural logs back to dollars per week
	local mX=exp(`X')
	local mu=exp(`lmu')
	local mT=exp(`T')
	local sigma=exp(`lsigma')

	*********************************************************************************
	* Step 2
	*********************************************************************************

	* a. calculate mean above top-code
	*    calculating mean above top-code implies left-truncation
	local halpha = (`T'-`lmu')/`lsigma'
	local hlamda = normden(`halpha')/(1 - norm(`halpha'))
	local mtc    = `lmu' + `lsigma'*`hlamda'

	* b. convert from natural logs back to dollars per week
	qui replace earnweek = exp(`mtc') if tci==1

	* Drop 0.25th and 0.9975th percentile
	egen low_pw = pctile(earnweek), p(0.25)
	egen high_pw = pctile(earnweek), p(99.75)
	replace earnweek = . if earnweek <= low_pw | earnweek >= high_pw

	*********************************************************************************
	*********************************************************************************
	* END ***************************************************************************
	*********************************************************************************
	*********************************************************************************
		
	*-----------------------------------------------------------------------
	* Education
	* Note: According to ipums documentation educ is never =120 (August 2016),
	*		but even if it was, it is ok to say that it is equal to 17 years of
	*		education because if educ==120, it does not take any other value
	*-----------------------------------------------------------------------
	gen gradeate=0		
	replace gradeate=2.5  if educ>=010 & educ<=14 & educ!=. 
	replace gradeate=5.5  if educ>=020 & educ<=22 & educ!=.  
	replace gradeate=7.5  if educ>=030 & educ<=32 & educ!=. 
	replace gradeate=9    if educ==040
	replace gradeate=10   if educ==050 
	replace gradeate=11   if educ==060
	replace gradeate=12   if educ>=070 & educ<=073 & educ!=.
	replace gradeate=13   if educ==080 | educ==081 
	replace gradeate=14   if educ>=090 & educ<=092 & educ!=.
	replace gradeate=15   if educ==100 
	replace gradeate=16   if educ>=110 & educ<=111 & educ!=.
	replace gradeate=17   if educ>=120 & educ<=122 & educ!=.
	replace gradeate=18   if educ>=123 | educ==124 | educ==125
	replace gradeate=.    if educ==001 | educ>=990

	*-----------------------------------------------------------------------
	* Age: Top codes are 90 before 2001 and 80/85 onwards so I don't consider them
	*-----------------------------------------------------------------------
	replace age = . if age<=0 | age >=80
		
	*-----------------------------------------------------------------------
	* Female = 1 female
	*-----------------------------------------------------------------------
	gen Female = sex-1
	replace Female = . if Female<0 | Female>1

	*-----------------------------------------------------------------------
	* nWhite = 1 if non white
	*-----------------------------------------------------------------------
	gen nWhite = 1 if race <990 & race!=.
	replace nWhite = 0 if race==100


	*-----------------------------------------------------------------------
	* Hispanic = 1 hispan
	*-----------------------------------------------------------------------
	replace hispan = 1 if hispan>0 & hispan <901 & hispan != .
	replace hispan = . if hispan>1	


	*-----------------------------------------------------------------------
	* Marst=1 married, = 2 single, =0 other
	*-----------------------------------------------------------------------
	replace marst = 1 if marst == 1 | marst == 2
	replace marst = 2 if marst == 6
	replace marst = . if marst == 9
	replace marst = 0 if marst != 1 & marst ! = 2 & marst != .


	*-----------------------------------------------------------------------
	* Industry
	*-----------------------------------------------------------------------
	gen ind = .

	* Agriculture, Foresct, and Fishing
	replace ind = 1 if ind1950 >= 105 & ind1950<= 126 & ind1950!=.

	* Mining
	replace ind = 2 if ind1950 >= 206 & ind1950<= 236 & ind1950!=.

	* Construction
	replace ind = 3 if ind1950 == 246 

	* Manufacturing/Durable Goods
	replace ind = 4 if ind1950 >= 306 & ind1950<= 399 & ind1950!=.

	* Manufacturing/Non-Durable Goods
	replace ind = 5 if ind1950 >= 406 & ind1950<= 499 & ind1950!=.
		
	* Transportation
	replace ind = 6 if ind1950 >= 506 & ind1950<= 568 & ind1950!=.

	* Telecommunications
	replace ind = 7 if ind1950 >= 578 & ind1950<= 579 & ind1950!=.

	* Utilities and Sanitary Services
	replace ind = 8 if ind1950 >= 586 & ind1950<= 598 & ind1950!=.

	* Wholesale Trade
	replace ind = 9 if ind1950 >= 606 & ind1950<= 627 & ind1950!=.

	* Retail Trade
	replace ind = 10 if ind1950 >= 636 & ind1950<= 699 & ind1950!=.

	* Finance, Insurance, and Real Estate
	replace ind = 11 if ind1950 >= 716 & ind1950<= 746 & ind1950!=.

	* Business and Repair Services
	replace ind = 12 if ind1950 >= 806 & ind1950<= 817 & ind1950!=.

	* Personal services
	replace ind = 13 if ind1950 >= 826 & ind1950<= 849 & ind1950!=.

	* Entertainment and Recreation Services
	replace ind = 14 if ind1950 >= 856 & ind1950<= 859 & ind1950!=.

	* Professional and Related Services
	replace ind = 15 if ind1950 >= 868 & ind1950<= 899 & ind1950!=.

	* Public Administration
	replace ind = 16 if ind1950 >= 906 & ind1950<= 936 & ind1950!=.


	*-----------------------------------------------------------------------
	* Occupation
	*-----------------------------------------------------------------------
	gen occ = .

	* Professional, Technical
	replace occ = 1 if occ1950>=000 & occ1950<=099 & occ1950!=.

	* Farmers
	replace occ = 2 if occ1950>=100 & occ1950<=123 & occ1950!=.

	* Managers, Officials, and Proprietors
	replace occ = 3 if occ1950>=200 & occ1950<=290 & occ1950!=.

	* Clerical and Kindred
	replace occ = 4 if occ1950>=300 & occ1950<=390 & occ1950!=.

	* Sales workers
	replace occ = 5 if occ1950>=400 & occ1950<=490 & occ1950!=.

	* Craftsmen
	replace occ = 6 if occ1950>=500 & occ1950<=595 & occ1950!=.

	* Operatives
	replace occ = 7 if occ1950>=600 & occ1950<=690 & occ1950!=.

	* Service Workers (private household)
	replace occ = 8 if occ1950>=700 & occ1950<=720 & occ1950!=.

	* Service Workers (not household)
	replace occ = 9 if occ1950>=730 & occ1950<=790 & occ1950!=.

	* Farm Laborers
	replace occ = 10 if occ1950>=810 & occ1950<=840 & occ1950!=.

	* Laborers
	replace occ = 11 if occ1950>=910 & occ1950<=970 & occ1950!=.	


	*-----------------------------------------------------------------------
	* Experience
	*-----------------------------------------------------------------------
	gen exp = age - gradeate - 6
	gen exp2 = exp*exp
	gen exp3 = exp2*exp
	gen exp4 = exp3*exp

	*-----------------------------------------------------------------------
	* Log Nominal Wage
	*-----------------------------------------------------------------------

	gen lnwage_cps = log(earnweek/uhrswork1)
	gen wage = exp(lnwage_cps)
	drop _*
    }
}
/*
*-----------------------------------------------------------------------
* End loop and save data
*-----------------------------------------------------------------------
	if ym == ym(1994,1) {
		save "$data/cps_clean_earnings.dta", replace
	}
	else {
		append using "$data/cps_clean_earnings.dta"
		save "$data/cps_clean_earnings.dta", replace
	}

    }
}

log close

/*
*figure out the spikes in 1995--why is this? 
*this is data issues for 1995m7-m8 in the CPS. 
foreach x in wage lnwage_cps {
	replace `x' = . if ym == ym(1995,7) | ym == ym(1995,8)
}
*/
