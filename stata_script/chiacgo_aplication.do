*--------------------------------------------------
* Data Task Chicago
* data_task.do
* 22/04/2020
* Anzony Quispe, UNALM
*--------------------------------------------------
*--------------------------------------------------
* Program Setup
*--------------------------------------------------
	version 14              // Set Version number for backward compatibility
	set more off            // Disable partitioned output
	clear all               // Start with a clean slate
	set linesize 80         // Line size limit to make output more readable
	macro drop _all         // clear all macros
*--------------------------------------------------
* Macros 
*--------------------------------------------------
	clear all 
	global main "G:\Mi unidad\RA_APP\Chicago" // Change this to the file which contains the data 
	global mainname "ENDES_DATA" 
	global mainext "ANZONY"
	global dofilename "${mainname}_${mainext}"

	cd "${main}"
	import excel "${main}\Data for Stata Test_2019.xlsx", sheet("Sheet1") firstrow clear
	//ssc install missings //package needed to clean all missing values observations
	mdesc
	missings dropobs, force //drop all missing values obs
	capture isid town_id 
	display _rc
	if _rc == 459 {
		display "It is not unique"
	}
	tempfile observations
	save `observations'

	import excel "${main}\Town Names for Stata Test_2019.xlsx", sheet("Sheet1") firstrow clear
	mdesc
	rename (TownID TownName) (town_id town_name)
	merge 1:m town_id using `observations'
	drop if _merge == 1
	drop _merge
	gen id = string(town_id, "%02.0f") + string(_n, "%02.0f")
	isid id

	encode district, gen(district_id)
	tab district_id
	label values district_id //give a number to each distric name.
	tab district_id
	drop district
	rename district_id district

	foreach var of varlist turnout_total-treatment_phase{
		replace `var' = . if `var' < 0
	}
	//ssc install mdesc
	mdesc
	list id if registered_total == . | registered_male == . | registered_female == . //all the missings belonged to the same observation
	drop if registered_total == .
	

	gen id = _n
		tostring id , replace
		gen id_1 = string(town_id) + id 
		drop id
		rename  id_1 id 


	//labeling variables
	label variable turnout_total "Total number of votes"
	label variable turnout_male "Number of male votes"
	//Because 
	tabstat registered_total registered_male registered_female, by(town_name) stat(mean p50)



	//generating dummies for each town id
	tabulate town_id, generate(dum_town)
	label variable turnout_female "Number of female votes"
	label variable registered_total "Total number of registered voters"
	label variable registered_male "Number of male registered voters"
	label variable registered_female "Number of female registered voters"
	label define treats 0 "Not Treated" 1 "Treated"
	label values treatment treats
	label variable treatment "0 = Not Treated 1 = Treated"
	label variable id "ID variable"
	label variable treatment_phase "1 = Phase one	2 = Phase two"
	label define phase 1 "Phase one" 2 "Phase two"
	label values treatment_phase phase

	levelsof town_name, local (names) //We extract each name for label
	forvalues i = 1/27 {
		local name : word `i' of `names'
		local dum_var "dum_town`i'"
		display "`dum_var'"
		label variable  `dum_var' "`name' town"
	}

	/*
		9.	What is the average total turnout rate? 
		Also note down the highest and lowest turnout rates recorded. 
		How many polling booths recorded the highest turnout rate? 
	*/
	tabstat turnout_total, stat(mi mean ma)
	list id if turnout_total == 1045
	x
	tabulate treatment_phase treatment

	gen turnout_total_rate =turnout_total/registered_total 
	gen turnout_fem_rate =turnout_female/registered_female 
	sum turnout_fem_rate if turnout_fem_rate > = 0.75 , by(district)
	tabulate  district if turnout_fem_rate > = 0.75 , sum(turnout_fem_rate)
	order turnout_female_dis turnout_total_dis turnout_total_dis_5  participation_075 registered_total_dis 
	
	graph bar (mean) turnout_total turnout_female turnout_male, stack over(treatment)

	#delimit ;
	graph bar turnout_total , over( treatment, label(labsize(small)) relabel(`r(relabel)')) 
		bargap(-30)
		legend( label(1 "Not treated" 2 "Treated")) 
		ytitle("Turnout") ;
	#delimit cr

		///
		name(turnout_total, replace) ///
		scheme(sj) ///

	drop town_id
	eststo: reg turnout_total treatment registered_total dum_town*

	*Instrmental Variables
	gen ratio = registered_female / registered_male 
	
	// I use as an instrment the variable ratio of women/male 

	ivregress 2sls turnout_total ( take_up = ratio ) registered_total dum_town*, first

