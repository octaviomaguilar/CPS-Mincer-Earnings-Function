version 7.0
cap cls
clear all
set more off

* ---------------------------------------------------------------------------
* Folders
* ---------------------------------------------------------------------------
global home = "/mq/scratch/m1oma00/oma_projects/cps"
global data "$home/data"

*-----------------------------------------------------------------------
* Import Raw CPS data
*-----------------------------------------------------------------------
use "$data/raw/cps_1994_2024.dta", clear

*-----------------------------------------------------------------------
* General Cleaning: Set panel and define sample restrictions
*-----------------------------------------------------------------------
*generate a year-month indicator:
gen ym = ym(year,month) 
format ym %tm

*generate a year-qtr indicator: 
gen yq = yq(year(dofm(ym)), quarter(dofm(ym)))
format yq %tq

xtset cpsidp ym

keep if age >= 16 & age <= 64

*drop individuals in armed forces:
drop if empstat == 1

*-----------------------------------------------------------------------
* Labor force status (=1 employed, =2 unemployed, =3 NIF, =. other)
*-----------------------------------------------------------------------
gen l_status = .
replace l_status = 1 if empstat == 10 | empstat == 12
replace l_status = 2 if empstat >= 20 & empstat <= 22 & empstat !=.
replace l_status = 3 if empstat >= 30 & empstat !=.

foreach ll of numlist 1/3 {
    gen l`ll'_status = .
    replace l`ll'_status = 1 if L`ll'.empstat == 10 | L`ll'.empstat == 12
    replace l`ll'_status = 2 if inrange(L`ll'.empstat, 20, 22) & L`ll'.empstat !=.
    replace l`ll'_status = 3 if L`ll'.empstat >= 30 & L`ll'.empstat !=.
}

*changed employed indicator
gen C_employer = empsame == 1
label variable C_employer "changed employer"

*-----------------------------------------------------------------------
* Dummies New Hire, Changers, From unemployment
*-----------------------------------------------------------------------	
* New hire from non employment
gen ENE  = 0 if l_status==1
gen ENE1 = 0 if l_status==1
gen ENE2 = 0 if l_status==1
replace ENE  = 1 if l_status==1 & (l1_status>1 & l1_status!=.)
replace ENE1 = 1 if l_status==1 & l1_status==1 & (l2_status>1 & l2_status!=.) & C_employer == 0 
replace ENE2 = 1 if l_status==1 & l1_status==1 & l2_status==1 & (l3_status>1 & l3_status!=.) & C_employer == 0 & L1.C_employer == 0 
			
* New hire from employment
gen EE  = 0 if l_status==1
gen EE1 = 0 if l_status==1
gen EE2 = 0 if l_status==1
replace EE  = 1 if l_status==1 & l1_status==1 & C_employer == 1
replace EE1 = 1 if l_status==1 & l1_status==1 & l2_status==1 & C_employer == 0 & L1.C_employer == 1
replace EE2 = 1 if l_status==1 & l1_status==1 & l2_status==1 & l3_status==1 & C_employer == 0 & L1.C_employer == 0 & L2.C_employer == 1

* Flag = 1 if we don't have all the information
gen FlagE = 0
replace FlagE = 1 if l_status*l1_status*l2_status*l3_status*C_employer*L1.C_employer*L2.C_employer == . 

* Flag = 1 if we don't have all information
gen FlagE2 = 0
replace FlagE2  = 1 if l_status*l1_status*C_employer == . 

*-----------------------------------------------------------------------
* Dummies New Hire from unemployment for whole sample
*-----------------------------------------------------------------------
gen ENE_alt  = 0 if l_status==1
gen ENE_alt1 = 0 if l_status==1
gen ENE_alt2 = 0 if l_status==1
replace ENE_alt  = 1 if l_status==1 & (l1_status>1 & l1_status!=.)
replace ENE_alt1 = 1 if l_status==1 & l1_status==1 & (l2_status>1 & l2_status!=.) 
replace ENE_alt2 = 1 if l_status==1 & l1_status==1 & l2_status==1 & (l3_status>1 & l3_status!=.) 

* Flag =1 if we don't have all information
gen FlagE_alt = 0
replace FlagE_alt = 1 if l_status*l1_status*l2_status*l3_status == . 

* Flag = 1 if we don't have all information
gen FlagE2_alt = 0	
replace FlagE2_alt = 1 if l_status*l1_status == . 

*-----------------------------------------------------------------------
* Class of worker (=1 wage priv, =2 wage public, =3 self, = . other)
*-----------------------------------------------------------------------
gen class_worker = .
replace class_worker = 1 if classwkr >= 21 & classwkr <= 23 & classwkr != .
replace class_worker = 2 if classwkr >= 24 & classwkr <= 28 & classwkr != .
replace class_worker = 3 if classwkr >= 10 & classwkr <= 14 & classwkr != .

*-----------------------------------------------------------------------
* Cover or member of a union
* Note: Available only for 1984-present in IPUMS. We could have it for 1983
*		from CPS or MORG, but IPUMS argues that this should be used only
*		for 1990-present
*-----------------------------------------------------------------------
gen unionm = 0
gen unionc = 0
replace unionm = 1 if union == 2
replace unionc = 1 if union == 3
	
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
gen exp2 = exp^2
gen exp3 = exp^3
gen exp4 = exp^4

*-----------------------------------------------------------------------
* Log Nominal Wage
*-----------------------------------------------------------------------
gen lnwage_cps = log(earnweek/uhrswork1)
gen wage = exp(lnwage_cps)

*-----------------------------------------------------------------------
* Save as a clean dataset
*-----------------------------------------------------------------------
save "$data/clean/cps_clean.dta", replace
