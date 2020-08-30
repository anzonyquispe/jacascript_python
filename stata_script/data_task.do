*--------------------------------------------------
* Data Task
* data_task.do
* 14/02/2019, version 1
* Alexander Quispe, University of Munich
*--------------------------------------------------
asdasdasd
*--------------------------------------------------
* Program Setup
*--------------------------------------------------
version 15              // Set Version number for backward compatibility
set more off            // Disable partitioned output
clear all               // Start with a clean slate
set linesize 80         // Line size limit to make output more readable
macro drop _all         // clear all macros
* --------------------------------------------------




*--------------------------------------------------
* Macros 
*--------------------------------------------------
clear all 
global main "G:\My Drive\SSGAC\data\Genoecon_Data_Task"			// Change this to the file which contain the data 
global data	"$main\data"
// global graphics	"$main\graphics"
// global tables "$main\tables"

global mainname "APPLICATION" 
global mainext "ALEXANDER"
global dofilename "${mainname}_${mainext}"
* --------------------------------------------------

*--------------------------------------------------
* Strucuture of te log file  
*--------------------------------------------------
cap log close
cd "$main"
local td: di %td_CY-N-D  date("$S_DATE", "DMY") 
local td = trim("`td'")
local td = subinstr("`td'"," ","_",.)
local td = subinstr("`td'",":","",.)
log using "$dofilename-`td'_1", text replace 
local today "`c(current_time)'"
local curdir "`c(pwd)'"
local newn = c(N) + 1
* --------------------------------------------------

*--------------------------------------------------
* 1. FIRST QUESTION - CLEANING DATA 
*--------------------------------------------------
	** 1.1. CLEANING DATA TRAIT-A  
		*** 1. Creation of labels 
			cd "$main"
			import delimited "$data\sumstats_trait_A.txt" , clear
			compress

			label variable snp "rsid number"
			label variable chr "Chromosome number"
			label variable bpos "Base pair position"
			label variable a1 "Allele 1-major allele"
			label variable a2 "Allele 2-minir allele"
			label variable maf "minor allele frequency"
			label variable n "Sample size used to estimate the effect size"
			label variable beta_hat "GWAS effect size estimate"
			label variable z "Z-score from the hypothesis test"
			label variable nchrobs "Number of allelic observation for the SNP"
			label variable info "INFO score for the SNP [0,1]"
		*** 2. Missing values of the maing variables 
			ssc install mdesc 
			mdesc snp chr bpos 			// we can verify that bpos has 701 missing values 
		*** 3. Let´s check if there are duplicates 

			/* First lets look for the duplicates
				it is suggeted that SNP should be unique identifier , 
			 	so lets take a look of duplicates in this variable*/

			* Because snp is a string variable we need to take away blanks spaces 
			replace snp = trim( itrim( snp ) )
			duplicates report snp 		// we observe that there is 194 observations with duplicates

			/*
			--------------------------------------
			   copies | observations       surplus
			----------+---------------------------
			        1 |         9806             0
			        2 |          194            97
			--------------------------------------
			*/

			* And if we want to know exactly which are the duplicate ones
			duplicates list snp

			/*we can not eliminate the duplicates of the variable snp 
			First,it should be better to make a cleanning over other variables in order
			to find some difference and drop the ones which are not congruent with the 
			explanation in the instructions file. 
			*/


			* Le´ts take a look over duplicates in the variables chr bpos
			* Because we know that they just identified one snp
			duplicates report chr bpos

			/*

			--------------------------------------
			   copies | observations       surplus
			----------+---------------------------
			        1 |         9297             0
			        2 |            2             1
			      701 |          701           700
			--------------------------------------
			*/

			* Now we create a variable to identifeid duplicates 

			duplicates tag chr bpos,gen(dup2)     // we just found 701 missing values duplicates 

			* So if we don´t know the bpos we can not identified the snp, then we should eliminate this observations
			drop if bpos == .

			* But still we have two obervations which are practical identical 
			list snp chr bpos info if  dup2>0

			/*
			+---------------------------------------+
			|        snp   chr       bpos      info |
			|---------------------------------------|
			| rs77578988    22   39587976   .991961 |
			| rs77578988    22   39587976   .348205 |
			+---------------------------------------+

			*/

			* we will assume that the observation with higher value for var  "info" will be kept 
			drop if snp == "rs77578988" & n == 79474
		*** 4. Identify a1 and a2

			* We want to see if all observations in a1 and a2 are correct

			tabulate a1 			// all is correct
			tabulate a2 			// we can see some repeated values

			* Let´s assume that there was an error typing and
			* when we observe "AA" there should have appeared "A", the same for the other cases  

			replace a2 = "A" if a2 == "AA" 
			replace a2 = "T" if a2 == "TT"  
			replace a2 = "C" if a2 == "CC"  
			replace a2 = "G" if a2 == "GG"  

			* But still there are some incorrect values in a2 
			list if length( a2 )>1

			* Because we can not  identify them we drop them 
			drop if length( a2 )>1

			* Besides we know that a1 should be different to a2
			count if a1 == a2 			// but we have 207 cases where that is not true

			* now because I can not  make any further assumpiton I will drop those "fake combinations (A,A)"
			drop if a1 == a2
		*** 5. Identify values out of the range in variable maf

			* Let´s take a look over maf  

			summarize maf 

			/*
			    Variable |        Obs        Mean    Std. Dev.       Min        Max
			-------------+---------------------------------------------------------
			         maf |      9,298    .2482799    .3337525   -.997525   1.998888

			*/

			* so we can see that there are values larger than 1 and lower than 0
			* Let´s count how many cases we have 

			count if maf>1 | maf<0			// so we have 299 cases where this happens

			* To adjust some values: in cases where -1<maf <0  we may change the sign
			replace maf  = abs(maf) if maf <0  

			* But we still have cases where the value is larger than one and it's better to drop them
			drop if maf >1

			/* we still have duplicates in the snp,but we can not just eliminate the duplicates
			 because we could identify them with the next data set-Trait B */
			duplicates report snp
		*** 6. Preparing for merging 
			* Let´s rename variables before merging 
			local vars1 "maf n beta_hat z nchrobs info"
			local n: word count `vars1'
			forvalues i = 1/`n' {
			local v1 : word `i' of `vars1'
			rename `v1' `v1'_A 
			}

			* Let´s create a temfile 
			tempfile sumstats_trait_A
			save `sumstats_trait_A'

			/* The cleanning data proces of Trait-b
				takes exactly the same process as the first one. 
			*/
	** 1.2. CLEANING DATA TRAIT-B

		*** 1. Creation of labels
			import delimited "$data\sumstats_trait_B.txt" , clear 

			compress


			label variable snp "rsid number"
			label variable chr "Chromosome number"
			label variable bpos "Base pair position"
			label variable a1 "Allele 1-major allele"
			label variable a2 "Allele 2-minir allele"
			label variable maf "minor allele frequency"
			label variable n "Sample size used to estimate the effect size"
			label variable beta_hat "GWAS effect size estimate"
			label variable z "Z-score from the hypothesis test"
			label variable nchrobs "Number of allelic observation for the SNP"
			label variable info "INFO score for the SNP [0,1]"
		*** 2. Missing values of the main variables
			ssc install mdesc 
			mdesc snp chr bpos 			// we can verify that bpos has 701 missing values 
		*** 3. Let´s check if there are duplicates 
			replace snp = trim( itrim( snp ) )
			sort snp
			duplicates report snp      // 202 	
			duplicates report chr bpos    

			duplicates tag chr bpos,gen(dup2) 

			list snp chr bpos info if  dup2>0 & bpos != .

			/*
			       +---------------------------------------+
			       |        snp   chr       bpos      info |
			       |---------------------------------------|
				   | rs77578988    22   39587976   .991961 |
				   | rs77578988    22   39587976   .348205 |
			       +---------------------------------------+
			*/

			* to look no missings - again I use the argument of the hogher value 
			list if  dup2>0 & bpos != .

			drop if snp == "rs77578988" & n == 78072
		*** 4. Identify a1 and a2

			* We want to see if all observations in a1 and a2 are correct

			tabulate a1 			// all is correct
			tabulate a2 			// we can see some repeated values

			* Let´s assume that there was a error typing and
			* when we observe "AA" there should have appeared "A", the same for the other cases  

			replace a2 = "A" if a2 == "AA" 
			replace a2 = "T" if a2 == "TT"  
			replace a2 = "C" if a2 == "CC"  
			replace a2 = "G" if a2 == "GG"  

			* But still there are some incorrect values in a2 
			list if length( a2 )>1

			* Because we can not  identify them we drop them 
			drop if length( a2 )>1

			* Besides we know that a1 should be different to a2
			count if a1 == a2 			// but we have 207 cases where that is not true

			* now because I can not  make any other assumpiton I will drop those "fake combinations (A,A)"
			drop if a1 == a2
		*** 5. Identify values out of the range in variable maf

			sum maf 
			* so we can see that there are values larger than 1 and lower than 0
			* Let´s count how many cases we have 

			count if maf>1 | maf<0			// so we have 299 cases where this happens

			* To adjust some values: in cases where -1<maf <0  we can change the sign
			replace maf  = abs(maf) if maf <0  

			* But we still have cases where the value is larger than one and it's better to drop them
			drop if maf >1

			/* we still have duplicates in the snp,but we can not just eliminate the duplicates
			 because we could identify them with the next data set */
			duplicates report snp
		*** 6. Preparing for merging
			* Let´s rename variables before merging 

			local vars1 "maf n beta_hat z nchrobs info"
			local n: word count `vars1'
			forvalues i = 1/`n' {
			local v1 : word `i' of `vars1'
			rename `v1' `v1'_B 
			}
	** 1.3. MERGING DATASETS 
		merge 1:1 snp chr bpos a1 a2 using `sumstats_trait_A' 
		keep if _merge == 3
		drop dup*

		/* Finally we just have 5885 observations 
		without repeated values in the variable snp*/
		 duplicates report snp

		save "$main\data_clean.dta" , replace 

*--------------------------------------------------
*2. SECOND QUESTION - Q-Q PLOT ANALYSIS  
*--------------------------------------------------
	** 2.1. PRODUCE A QUANTILE-QUANTILE PLOT
		clear all
		use "$main\data_clean.dta" , clear  


		/* 	First we need to get the p values from both traits, since
			we assume that the Z scores come from standard normal distribution 
			and if the H_0 were true for all SNP , we could expect that p-values will distribute uniformly .
			Besides , we need to create a uniform distribution to make the comparison */

		* First , wee need to verify our normality assumption with some histograms 
			histogram z_A, normal legend(on)
			graph save h_A , replace

			histogram z_B, normal legend(on)
			graph save h_B , replace

		* Now we combine both graphics 
			graph combine h_A.gph h_B.gph , col(2)

			graph export "$main\h_A_B.png" , replace


		* Now we can create the functionts 
			gen uniform = runiform(0,1)

			gen pv_A_n = normal(z_A)
			gen pv_B_n = normal(z_B)

		* Graph pv_A_n and uniform distribution
			#delimit ;

			qqplot pv_A_n uniform, recast(line) rlopts(lcolor(green)) 
			ytitle(Sample Quantiles of p-values)
			xtitle(Theoretical Quantiles Uniform Distribution) 
			title(Q-Q plot of the p-values (Trait-A)) 
			legend(on order(1 "p-value"2 "45° line" ) cols(2)) clegend(on) plegend(on) ;
			
			#delimit cr
			graph save qq_plot_A , replace			
			graph export "$main\qq_plot_A.png" , replace

		* Graph pv_B_n and uniform distribution
			#delimit ;

			qqplot pv_B_n uniform, recast(line) rlopts(lcolor(green)) 
			ytitle(Sample Quantiles of p-values)
			xtitle(Theoretical Quantiles Uniform Distribution) 
			title(Q-Q plot of the p-values (Trait-B)) 
			legend(on order(1 "p-value"2 "45° line" ) cols(2)) clegend(on) plegend(on)  ;

			#delimit cr
			graph save qq_plot_B , replace			
			graph export "$main\qq_plot_B.png" , replace

		* Let´s combine both graphics
			graph combine qq_plot_A.gph qq_plot_B.gph , col(2)
			graph export "$main\qq_plot_both.png" , replace
	** 2.2. ANSWER IN PDF
	** 2.3. ANSWER IN PDF
	** 2.4. ANSWER IN PDF


