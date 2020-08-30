clear all

cd "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv"
// Importing data 
import delimited "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv\psam_h33.csv", clear 
duplicates report serialno

preserve
import delimited "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv\psam_p33.csv", clear 
tempfile precord
save "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv\precord.dta" , replace 

import excel "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\data_task_SIEPRpredoc_polyakova_2019\slsp_premiums_2017.xls", sheet("Sheet1") firstrow clear
tempfile age_bm
save "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv\age_bm.dta" , replace  
restore 

merge 1:m serialno using "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv\precord.dta"
sum np if _merge==1

// so we can drop the values for which np == 0

drop if np == 0 & _merge==1 

order serialno np sporder
sort serialno np sporder

// work with rac1p and sex  and keep agep

gen race = (rac1p == 1)
gen gender = (sex == 2)
rename agep age 

// measure income relative poverty line "POVPIP" and "hicov"
rename 	povpip ifpl  
gen histat = (hicov == 1)


order serialno np sporder histat ifpl race gender age

/// STEP 2
br if  age <19

gen potaca = 1
replace potaca = 0 if age < 19 & ifpl<318 
replace potaca = 0 if hins1 == 1 
replace potaca = 0 if hins3 == 1 
replace potaca = 0 if hins4 == 1 
replace potaca = 0 if hins5 == 1 
replace potaca = 0 if hins6 == 1 






//hins1 hins2 hins3 hins4 hins5 hins6 hins7
order serialno np sporder histat ifpl race gender age potaca  
quietly bysort serialno ifpl :  gen dup = cond(_N==1,0,_n)
replace dup = 1 if  dup == 0 
bysort serialno ifpl : egen num_fam = max(dup)
order serialno np sporder histat ifpl race gender age num_fam

// number members who need coverage 
bysort serialno ifpl : egen num_fam_c = sum(potaca)
order serialno np sporder histat ifpl race gender age num_fam potaca num_fam_c

// drop where the tax family size is greater than 6 
drop if num_fam >6
keep if potaca == 1

// STEP 3

order serialno np sporder histat ifpl race gender age num_fam potaca num_fam_c fincp 

// Expected Premium Contribution (coverage year 2019)
// http://www.healthreformbeyondthebasics.org/wp-content/uploads/2017/11/REFERENCEGUIDE_Yearly-Guidelines-and-Thresholds_2019.pdf
// http://www.healthreformbeyondthebasics.org/wp-content/uploads/2017/11/REFERENCEGUIDE_Yearly-Guidelines-and-Thresholds_2018.pdf

generate prem_perc = .
replace prem_perc = 0.0201 if (ifpl <133)
replace prem_perc = 0.0302 if (ifpl >=133) & (ifpl <138)
replace prem_perc = 0.0332 if (ifpl >=138) & (ifpl <150)
replace prem_perc = 0.0403 if (ifpl >=150) & (ifpl <200)
replace prem_perc = 0.0634 if (ifpl >=200) & (ifpl <250)
replace prem_perc = 0.0810 if (ifpl >=250) & (ifpl <300)
replace prem_perc = 0.0956 if (ifpl >=300) & (ifpl <=400)


egen premgroup=cut(ifpl), at(0,133, 138, 150, 200, 250,300,401)
drop if ifpl > 400


// choosing directly the subsides 

generate prem_month = .
replace prem_month = 58 if (ifpl <133) & (num_fam > 1)
replace prem_month = 99 if (ifpl >=133) & (ifpl <138) & (num_fam > 1)
replace prem_month = 130 if (ifpl >=138) & (ifpl <150) & (num_fam > 1)
replace prem_month = 274 if (ifpl >=150) & (ifpl <200) & (num_fam > 1)
replace prem_month = 437 if (ifpl >=200) & (ifpl <250) & (num_fam > 1)
replace prem_month = 619 if (ifpl >=250) & (ifpl <300) & (num_fam > 1)
replace prem_month = 825 if (ifpl >=300) & (ifpl <=400) & (num_fam > 1)



// more cleanning
// those who doesn´t have any ifpl or income
order serialno np sporder histat ifpl race gender age num_fam potaca num_fam_c fincp wagp pincp

// we need to correct the income values for just one potential aca 
//  because we check that those individuals from the same family has de same personal income (2-6)
gen fam_inc = fincp 
replace fam_inc = pincp if num_fam == 1 & fincp == .
replace fam_inc = pincp if num_fam > 1 & fincp == .


// If we have no more information 
drop if ifpl== . & fam_inc== .
drop if ifpl== 0 & fam_inc == 0

// 
gen epc = prem_perc * fincp

order serialno np sporder histat ifpl race gender age num_fam potaca num_fam_c fincp wagp epc prem_perc
sort serialno ifpl

drop _merge

merge m:1 age using "G:\My Drive\RA_APP\data_task_SIEPRpredoc_polyakova_2019\csv\age_bm.dta"

// we have to forget about the ones older than 65 
keep if _merge == 3

// STEP 4

bysort serialno ifpl : gen person_id = _n

egen newid = group(serialno ifpl)

order serialno  np newid person_id  sporder histat ifpl race gender age num_fam potaca num_fam_c fincp wagp epc prem_perc
sort newid person_id

bysort newid : egen fam_2sls = sum(annual_2sls_premium)
gen ptc = fam_2sls - epc
order serialno np newid person_id sporder ifpl race gender age num_fam potaca num_fam_c fincp fam_inc epc prem_perc annual_2sls_premium ptc fam_2sls pincp st puma ptc

keep serialno np newid person_id sporder ifpl race gender age num_fam potaca num_fam_c fincp fam_inc epc prem_perc annual_2sls_premium ptc fam_2sls pincp st puma ptc


//   ANALISIS

tabstat ifpl race gender age num_fam ptc, s(mean median sd range min max p10 p90)

// binned scatterplot
ssc install binscatter

binscatter ptc age
reg ptc age

// 

binscatter ptc ifpl
reg ptc ifpl

binscatter  fincp age

// 
histogram ptc, normal by(gender)

twoway histogram ptc,normal by(gender)
