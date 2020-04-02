*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/clean_newvars`date'.log", replace
	use "../raw/hpa_clean.dta", clear
	egen ID = group(id) //xtset ID date
	vsa_flag_and_drop
	demographics
	funds_number
	funds_share
	return_by_obs
	default_fund
	sum ID date def_f2 def_f3 def_f4 f1-f5
	balance_predicted
	save "../raw/clean_newvars.dta", replace
	log close  //save "..\code\temp_newvars.dta", replace
end

capture program drop vsa_flag_and_drop
program              vsa_flag_and_drop
	di "-- VSA flag and drop"
	bys id date: egen I_cavt = max(type_account)
	replace           I_cavt = I_cavt-1
	bys id:      egen I_cav  = max(I_cavt)
	* Which fund do they have their money on?
	keep if type_account==1
	drop    type_account
	tsset ID date, monthly
end

capture program drop demographics
program              demographics
	di "-- Demographics"
	/*qui sum TI, det
	gen TI_p50below = (TI < r(p50)) if TI!=.
	gen TI_p25below = (TI < r(p25)) if TI!=.
	gen TI_p75above = (TI > r(p75)) if TI!=. */
	gen TI0 = TI
	replace TI0 = 0 if mi(TI)
	foreach var in TI TI0 {
		di "-- Mean potential income for all period"
		bys ID: egen `var'_avg = mean(`var')
		bys ID: gen temp_n = _n
		sum `var'_avg if temp_n==1, det
		bys ID: gen   `var'_a50 = 1 if `r(p50)'<=`var'_avg 
		replace       `var'_a50 = 0 if `r(p50)'> `var'_avg
		bys ID: gen `var'_quart = 4 if `r(p75)'<=`var'_avg                      & `var'_avg!=.
		replace     `var'_quart = 3 if `r(p50)'<=`var'_avg & `var'_avg<`r(p75)' & `var'_avg!=.
		replace     `var'_quart = 2 if `r(p25)'<=`var'_avg & `var'_avg<`r(p50)' & `var'_avg!=.
		replace     `var'_quart = 1 if `r(p25)'>=`var'_avg                      & `var'_avg!=.
		di "-- Mean potential income by year"
		gen temp_date = dofm(date)
		format %td temp_date
		gen temp_year = year(temp_date)
		bys ID temp_year: egen `var'y_avg = mean(`var')
		bys ID temp_year: gen temp_y_n = _n
		gen   `var'y_a50 = .
		gen `var'y_quart = .
		forvalues y = 2007/2013 {
			sum `var'y_avg if temp_year==`y' & temp_y_n==1, det
			local year_nomis temp_year==`y' & `var'y_avg!=.
			replace   `var'y_a50 = 1 if `year_nomis' & `r(p50)'<=`var'y_avg & `var'y_avg!=.
			replace   `var'y_a50 = 0 if `year_nomis' & `r(p50)'> `var'y_avg   
			replace `var'y_quart = 4 if `year_nomis' & `r(p75)'<=`var'y_avg                      
			replace `var'y_quart = 3 if `year_nomis' & `r(p50)'<=`var'y_avg & `var'y_avg<`r(p75)'
			replace `var'y_quart = 2 if `year_nomis' & `r(p25)'<=`var'y_avg & `var'y_avg<`r(p50)'
			replace `var'y_quart = 1 if `year_nomis' & `r(p25)'>=`var'y_avg                      
		}
		drop temp_*
	}
	di "-- Age of default"
	gen age_def = .
	qui replace age_def = 2 if age<=35
	qui replace age_def = 3 if (age>35 & age<=55 & gender==1) | (age>35 & age<=50 & gender==0)
	qui replace age_def = 4 if (age>55 & gender==1) | (age>50 & gender==0)
end

capture program drop funds_number
program              funds_number
	di "-- Funds number"
	egen blnc = rowtotal(f1 f2 f3 f4 f5)
	egen n_f = rownonmiss(f1 f2 f3 f4 f5)
	assert (n_f==1 | n_f==2) & !mi(n_f)
	label var n_f "Number of nonmissing funds"
	bys ID: egen n_f_min = min(n_f)
	bys ID: egen n_f_max = max(n_f)
end

capture program drop funds_share
program              funds_share
	forvalues f=1/5 {
		gen nmf`f' = (!mi(f`f'))
		gen sh_f`f' = f`f'/blnc if              nmf`f'==1 & f`f'!=0
		replace sh_f`f' = 1     if sh_f`f'==. & nmf`f'==1 & n_f==1 & blnc==0
		replace sh_f`f' = 0.5   if sh_f`f'==. & nmf`f'==1 & n_f==2 & blnc==0
		replace sh_f`f' = 0     if sh_f`f'==. & nmf`f'==1 & n_f==2 & blnc!=0 & f`f'==0
		replace sh_f`f' = 0     if sh_f`f'==. & nmf`f'==0
	}
	assert sh_f3<=1 & sh_f3>=0
end

capture program drop return_by_obs
program              return_by_obs
	di "-- Returns by observation"
	di "-- Switch the first day of the month"
	gen ret_avg = sh_f1*r1+sh_f2*r2+sh_f3*r3+sh_f4*r4+sh_f5*r5
end


capture program drop default_fund
program              default_fund
	*Notation fF_n: default fund F when has n funds by default
	bys ID (date): egen age_min = min(age)
	bys ID (date): egen age_max = max(age)
	di "-- Locals for demo groups and identification of nonmis funds"
	forvalues f=2/4 {
		local f`f'_1 n_f==1 & !mi(f`f') //gen def_f`f'_0 = (`f`f'_1') if `demo_f`f''
	}
	local demo_f2    age<=35
	local demo_f3_2 (age>35 & age<=39)
	local demo_f3_1 ((age>39 & age<=55 & gender==1)|(age>39 & age<=50 & gender==0))
	local demo_f4_2 ((age>55 & age<=59 & gender==1)|(age>50 & age<=54 & gender==0))
	local demo_f4_1 ((age>59           & gender==1)|(age>54           & gender==0))
	forvalues f=3/4 {
		local demo_f`f'   (`demo_f`f'_2'|`demo_f`f'_1')
		local j=`f'-1
		local f`f'_2   (n_f==2 & !mi(f`j') & !mi(f`f'))
		gen    rat_f`f' = round(f`f'/(f`j'+f`f'),.01) if `demo_f`f'' & `f`f'_2'
	}
	
	di "-- Ratio's acceptable range - by demo groups"
	qui gen     rat_m = 0.2*(age-35)-.06    if `demo_f3' & `f3_2'
	qui replace rat_m = 0.2*(age-50)-.06    if `demo_f4' & `f4_2' & gender==0
	qui replace rat_m = 0.2*(age-55)-.06    if `demo_f4' & `f4_2' & gender==1
	qui gen     rat_M = 0.2*(age-35)+.06    if `demo_f3' & `f3_2'
	qui replace rat_M = 0.2*(age-50)+.06    if `demo_f4' & `f3_2' & gender==0
	qui replace rat_M = 0.2*(age-55)+.06    if `demo_f4' & `f4_2' & gender==1
	
	di "-- Funds' share in default option"
	gen     sh_2def = 1              if `demo_f2'
	replace sh_2def = 1-0.2*(age-35) if `demo_f3_2'
	gen     sh_3def =   0.2*(age-35) if `demo_f3_2'
	replace sh_3def = 1              if `demo_f3_1'
	replace sh_3def = 1-0.2*(age-50) if `demo_f4_2' & gender==0
	replace sh_3def = 1-0.2*(age-55) if `demo_f4_2' & gender==1
	gen     sh_4def =   0.2*(age-50) if `demo_f4_2' & gender==0
	replace sh_4def =   0.2*(age-55) if `demo_f4_2' & gender==1
	replace sh_4def = 1              if `demo_f4_1'
	assert  sh_4def==1 & sh_4def[_n-1]==float(0.8) if gender==1 & age==60 & age[_n-1]==59
	forvalues f=2/4 {
		replace sh_`f'def=0 if sh_`f'def==. 
	}
	
	di "-- Returns in default option"
	gen rpdef = sh_2def*r2 + sh_3def*r3 + sh_4def*r4
	
	di "-- Generate default dummies and average of defaults - by demo groups"
	gen  def_f2_1 = (`demo_f2'   & `f2_1') if `demo_f2'
	qui bys ID (date): egen a1_f2_1= mean(def_f2_1)
	forvalues f=3/4 {
		local inrange rat_f`f'>=rat_m & rat_f`f'<=rat_M
		gen  def_f`f'_2 = (`demo_f`f'_2'& `f`f'_2' & `inrange') if `demo_f`f'_2'
		gen  def_f`f'_1 = (`demo_f`f'_1'& `f`f'_1')             if `demo_f`f'_1'
	}
	
	di "-- Fix if 1 year delay in default gradual switch - by demo group"
	local 21_3 (n_f==2 & nmf2==1 & nmf3==1)
	local d_3 (age==40 | age==39)
	local 21_4 (n_f==2 & nmf3==1 & nmf4==1)
	local d_4 (((age==60|age==59) & gender==1)|((age==55|age==54) & gender==0))
	forvalues i=1/11 {
	  forvalues f=3/4 {
		replace def_f`f'_2=1 if def_f`f'_1==0 & `21_`f'' & def_f`f'_1[_n+`i']==1 & `d_`f''
		replace def_f`f'_1=. if def_f`f'_1==0 & `21_`f'' & def_f`f'_1[_n+`i']==1 & `d_`f''
	  }
	}
	local 2_23 (n_f==1 & nmf2==1 & age==36)
	local 3_34 (n_f==1 & nmf3==1 & ((age==56 & gender==1)|(age==51 & gender==0)))
	forvalues i=1/11 {
	 replace def_f2_1=1 if def_f3_2==0 & `2_23' & def_f3_2[_n+`i']==1
	 replace def_f3_1=1 if def_f4_2==0 & `3_34' & def_f4_2[_n+`i']==1
	 replace def_f3_2=. if def_f3_2==0 & `2_23' & def_f3_2[_n+`i']==1
	 replace def_f4_2=. if def_f4_2==0 & `3_34' & def_f4_2[_n+`i']==1
	}
	
	di "-- Fix if in default by chance after switch - by demo group"
				forvalues i=1/11 {
					replace def_f3_2=0 if def_f3_2==1 & `f3_2' & nmf2[_n-`i']==0 & nmf3[_n-`i']==0
					replace def_f3_1=0 if def_f3_1==1 & `f3_1' & nmf3[_n-`i']==0
					replace def_f4_2=0 if def_f4_2==1 & `f4_2' & nmf3[_n-`i']==0 & nmf4[_n-`i']==0
					replace def_f4_1=0 if def_f4_1==1 & `f4_1' & nmf4[_n-`i']==0
				}
	
	di "-- Generate average of defaults"
	forvalues f=3/4 {
		qui bys ID (date): egen a1_f`f'_2= mean(def_f`f'_2)
		qui bys ID (date): egen a1_f`f'_1= mean(def_f`f'_1)
	}
	
	/*di "-- Fix if delays in default gradual switch - by demo groups"
	replace def_f2_1=1 if age==36 & `f2_1' & a1_f3_2>0.7 & (a1_f3_1>0.7|a1_f2_1>0.7)
	replace def_f3_2=. if age==36 & `f2_1' & a1_f3_2>0.7 & (a1_f3_1>0.7|a1_f2_1>0.7)
	replace def_f3_2=1 if age==40 & `f3_2' & a1_f3_1>0.7 & (a1_f3_2>0.7|a1_f2_1>0.7)
	replace def_f3_1=. if age==40 & `f3_2' & a1_f3_1>0.7 & (a1_f3_2>0.7|a1_f2_1>0.7)
	
	replace def_f3_1=1 if age==51 & `f3_1' & a1_f3_2>0.7 & (a1_f3_2>0.7|a1_f4_2>0.7) & gender==0
	replace def_f4_2=. if age==51 & `f3_1' & a1_f3_2>0.7 & (a1_f3_2>0.7|a1_f4_2>0.7) & gender==0
	replace def_f4_2=1 if age==55 & `f4_2' & a1_f4_1>0.7 & (a1_f4_2>0.7)             & gender==0
	replace def_f4_1=. if age==55 & `f4_2' & a1_f4_1>0.7 & (a1_f4_2>0.7)             & gender==0
	
	replace def_f3_1=1 if age==56 & `f3_1' & a1_f3_2>0.7 & (a1_f3_2>0.7|a1_f4_2>0.7) & gender==1
	replace def_f4_2=. if age==56 & `f3_1' & a1_f3_2>0.7 & (a1_f3_2>0.7|a1_f4_2>0.7) & gender==1
	replace def_f4_2=1 if age==60 & `f4_2' & a1_f4_1>0.7 & (a1_f4_2>0.7)             & gender==1
	replace def_f4_1=. if age==60 & `f4_2' & a1_f4_1>0.7 & (a1_f4_2>0.7)             & gender==1*/
	
	di "-- Check average default - by demo groups"
	qui bys ID (date): egen a2_f2_1= mean(def_f2_1)
	forvalues f=3/4 {
		qui bys ID (date): egen a2_f`f'_2= mean(def_f`f'_2)
		qui bys ID (date): egen a2_f`f'_1= mean(def_f`f'_1)
	}	
	
	di "-- Fix 101 & for balance<20000 when n_f==2"
	forvalues f=3/4 {
		local j = `f'-1
		local f`f'_2_101  def_f`f'_2[_n-1]==1 & def_f`f'_2[_n+1]==1 & def_f`f'_2==0
		local avg_ok_nonmis ((a2_f`f'_1>0.9|a2_f`f'_1!=.) |(a2_f`j'_1>0.9|a2_f`j'_1!=.))
		local avg_no_nonmis ((a2_f`f'_1<0.4|a2_f`j'_1<0.4)&(a2_f`f'_1!=.| a2_f`f'_1!=.))
		replace def_f`f'_2=1 if `f`f'_2_101'   & `f`f'_2' & a2_f`f'_2>0.5 & `avg_ok_nonmis'
		replace def_f`f'_2=1 if  def_f`f'_2==0 & `f`f'_2' & a2_f`f'_2>0.9 & `avg_ok_nonmis'
		replace def_f`f'_2=1 if  def_f`f'_2==0 & `f`f'_2' & blnc==0       & `avg_ok_nonmis'
		*replace def_f`f'_2=0 if  def_f`f'_2==1 & `f`f'_2' & a2_f`f'_2<0.4 & `avg_no_nonmis'
	}
	
	di "-- Final default variables"	
	gen def_f2  = def_f2_1
	gen def_f3  = max(def_f3_1,def_f3_2)
	gen def_f4  = max(def_f4_1,def_f4_2)
	gen default = max(def_f2,def_f3,def_f4)
	replace default = 1 if default[_n-1]==1 & default[_n+1]==1 & default==0 ///
	                     & ID==ID[_n-1] & ID==ID[_n+1]
	
	bys ID (date): egen av_f2_1= mean(def_f2_1)
	forvalues f=3/4 {
		qui bys ID (date): egen av_f`f'_2= mean(def_f`f'_2)
		qui bys ID (date): egen av_f`f'_1= mean(def_f`f'_1)
	}
	drop a1* a2*
	
	di "-- Check	"
	assert (default==0 | default==1) & default!=. & default<2
	tsreport ID date, panel
	assert `r(N_gaps2)'==0
end	

capture program drop balance_predicted
program              balance_predicted
	di "-- Predicted balance" 
	sort ID date
	gen cont = TI*0.1 
	gen blnc_adj = cond(mi(bhijo),0,bhijo,0)-cond(mi(reld),0,reld,0)-cond(mi(pRP),0,pRP,0) ///
			  -cond(mi(pRT),0,pRT,0) if (!mi(bhijo)|!mi(reld)|!mi(pRP)|!mi(pRT))
	gen blnc_ret = f1[_n-1]*(1+r1)+f2[_n-1]*(1+r2)+f3[_n-1]*(1+r3)+f4[_n-1]*(1+r4)  ///
				  +f5[_n-1]*(1+r5)   if ID==ID[_n-1]
	replace blnc_ret = blnc if blnc_ret==. & ID!=ID[_n-1]
	gen blnc_pred = round(blnc_ret+cond(mi(cont),0,cont,0)+cond(mi(blnc_adj),0,blnc_adj,0),10000) 
	gen blnc_dif = abs(blnc-blnc_pred) 
	
	di "-- Predicted funds"
	forvalues f=1/5 {
		qui gen f`f'_adj  = sh_f`f'*blnc_adj
		qui gen f`f'_ret  = f`f'[_n-1]*(1+r`f')       if ID==ID[_n-1]
		qui gen f`f'_pred = f`f'_ret + cond(mi(f`f'_adj),0,f`f'_adj,0)
		gen f`f'_dif  = abs(f`f'-f`f'_pred)
	}
end
 		
*===================================================================================================
program default_fund_old
	local demo_f2 age<=35
	local demo_f3 (age>35 & age<=55 & gender==1) | (age>35 & age<=50 & gender==0)
	local demo_f4 (age>55           & gender==1) | (age>50           & gender==0)
	local f2_f3   n_f==2 & !mi(f2) & !mi(f3)
	local f3_f4   n_f==2 & !mi(f3) & !mi(f4)
	*Generate defaults if only one nonmissing fund, given demographics
	forvalues f=2/4 {
		local only_f`f' n_f==1 & !mi(f`f')
		gen def_f`f'_0 = (`only_f`f'') if `demo_f`f''
	}
	*FUND B
	gen		def_f2 = only_f2 if age<=35
	*FUND C
	*A1) "in dC amidst" if "dB at 35yo & dC at 40yo" (gradual default switch 20% at 36,...)
	sort 	ID date
	gen def_f3_g = .
	forvalues i = 1/48 {
		replace def_f3_g = 1 if `f2_f3' & age[_n-`i']==35    & def_f2_0[_n-`i']==1 ///
							           & age[_n+50-`i']==40 & def_f3_0[_n+50-`i']==1
		}
	*A2) in default if the ratio is +-.05 from default gradual change (blnc ratio of gradual switch)
	gen ratio3 = round(f3/(f2+f3),.01) if `demo_f3' & `f2_f3' & def_f3_0==0
	gen def_f3_r = .
	forvalues i = 1/4 {
		replace def_f3_r = 1 if (ratio3>=0.2*`i'-.0501) & (ratio3<=0.2*`i'+.0501) & (age==35+`i')
	}
	*A3) in default before if in default at age 40 & split in 2 funds before
	gen def_f3_b = ((def_f3_r==1) | (def_f3_0==1)) if def_f3_0!=.
	forvalues j = 1/4 {
		forvalues i = 1/12 {
		replace def_f3_b = 1 if `f2_f3' & def_f3_0==0 & def_f3_b[_n+`i']==1  ///
		                                & age==40-`j' & age[_n+`i']==41-`j'
		}
	}
	*A4) in default if first gradual adjustment starts up to 6 months after age 36
	forvalues i = 1/6 {
		replace def_f3_b = 1 if `only_f2' & def_f3_0==0 & def_f3_b[_n+`i']==1 ///
									      & age==36 & age[_n+`i']==36 
	}
	*All adjustments
	gen def_f3 = ((def_f3_r==1) | (def_f3_b==1)) if def_f3_0!=.
	*FUND D
	*A1) "in dD amidst" if "dC at 49/54yo & dD at 54/59yo" (gradual default switch 20% at 50F/55M)
	sort 	ID date
	gen def_f4_g = .
	forvalues i = 1/48 {          
		replace def_f4_g = 1 if `f3_f4' & gender==0 & def_f3_0[_n-`i']==1 & def_f4_0[_n+50-`i']==1 ///
		                    & age[_n-`i']==50 & age[_n+50-`i']==55 //age+15 from C
		replace def_f4_g = 1 if `f3_f4' & gender==1 & def_f3_0[_n-`i']==1 & def_f4_0[_n+50-`i']==1 ///
	                        & age[_n-`i']==55 & age[_n+50-`i']==60  
	}
	*A2) in default if the ratio is +-.05 from default gradual change (blnc ratio of gradual switch)
	gen ratio4 = round(f4/(f3+f4),.01) if `demo_f4'	& `f3_f4' & def_f4_0==0
	gen def_f4_r = .
	forvalues i = 1/4 {
		replace def_f4_r = 1 if (ratio4>=0.2*`i'-.0501) & (ratio4<=0.2*`i'+.0501) ///
							  & ((age==55+`i' & gender==1) | (age==50+`i' & gender==0))
	}
	*A3) in default before if in default at age 40 & split in 2 funds before
	gen def_f4_b = ((def_f4_r==1) | (def_f4_0==1)) if def_f4_0!=.
	forvalues j = 1/4 {
		forvalues i = 1/12 {
		replace def_f4_b = 1 if `f3_f4' & gender==0 & def_f4_0==0 & def_f4_b[_n+`i']==1 ///
													& age==55-`j' & age[_n+`i']==56-`j' 									
		replace def_f4_b = 1 if `f3_f4' & gender==1 & def_f4_0==0 & def_f4_b[_n+`i']==1 ///
													& age==60-`j' & age[_n+`i']==61-`j'
		}
	}
	*A4) in default if first gradual adjustment starts up to 6 months after age 56M/51F
	forvalues i = 1/6 {
	replace def_f4_b = 1 if `only_f3' & gender==1 & def_f4_0==0 & def_f4_b[_n+`i']==1 ///
								                  & age==56 & age[_n+`i']==56 
	replace def_f4_b = 1 if `only_f3' & gender==0 & def_f4_0==0 & def_f4_b[_n+`i']==1 ///
								                  & age==51 & age[_n+`i']==51
	}
	* All adjustments
	gen def_f4 = ((def_f4_r==1) | (def_f4_b==1)) if def_f4_0!=.
end
*===================================================================================================

main

/*
program newvar_policy_change //replace bid=2 if date<ym(2010,8) & date>ym(2010,2)
	gen bid  = (date>=ym(2010,8))
	gen bid1 = (date>=ym(2010,8) & date<ym(2012,8)) if date<ym(2012,8)
	gen bid2 = (date>=ym(2012,8))					if date>ym(2010,8)
	gen bid12 = bid1
	replace bid12 = 2 if bid2==1
end
*/
/*
*Checks default fund
*hist av_f3_2, width(0.05) freq saving(f3_2, replace) graph combine f3_2.gph f3_1.gph f4_2.gph 
*br date ID age gender afp f1-f5 n_f def* av_*  if
//def_f3_2==0 & a2_f3_2<0.4 & ((a2_f3_1<0.4)|(a2_f2_1<0.4)) & (n_f==2 & !mi(f2) & !mi(f3))
//ID==897|ID==969|ID==3211|ID==7069|ID==7561|ID==7723|ID==1|ID==9|ID==18|ID==33|ID==58|ID==473
//def_f3_2[_n-1]==1&def_f3_2[_n+1]==1&def_f3_2==0&(n_f==2&!mi(f2)&!mi(f3))&a1_f3_2>0.5&a1_f3_1>0.9
preserve
	collapse gender age_min age_max (count) num=age_min, by(ID)
	table  age_min age_max, c(n  num) by(gender)
restore
*/
/*
*Adjustments to balance             
	gen cont = TI*0.1 if type_account==1
	gen _adj = cond(mi(bhijo),0,bhijo,0)-cond(mi(reld),0,reld,0)-cond(mi(pRP),0,pRP,0) ///
			  -cond(mi(pRT),0,pRT,0) ///
			  if type_account==1 & (!mi(bhijo)|!mi(reld)|!mi(pRP)|!mi(pRT))
	gen _blnc_ret = f1[_n-1]*(1+r1)+f2[_n-1]*(1+r2)+f3[_n-1]*(1+r3)+f4[_n-1]*(1+r4)  ///
				  +f5[_n-1]*(1+r5) if _id==_id[_n-1]
	replace _blnc_ret = _blnc if _blnc_ret==. & _id!=_id[_n-1] & type_account==1
	gen _blnc_pred = round(_blnc_ret+cond(mi(cont),0,cont,0)+cond(mi(_adj),0,_adj,0),10000) ///
			  if type_account==1
	gen _dif = abs(round(_blnc,10000)-_blnc_pred) if type_account==1
	*True zero if explained by changes in contributions/adj
	gen _b0 = (_seq0==1 & _dif<=10000 & ((_adj!=0&!mi(_adj))|(cont!=0&!mi(cont))))  ///
			  if type_account==1
	bys _id (date): egen _b0_max = max(_b0)  if type_account==1
	gen Iblnc0 = (_b0_max==1 & _sp_b0>0)
	*br _id ID date _blnc _dif _blnc_pred _blnc_ret cont _adj _b0* if type_account==1 & _b0_max==1	
	bys _id _sp_b0 (date): egen _dif_tot = total(_dif) if _sp_b0>0 & _seq0!=1
	replace _dif_tot = _dif if  _seq0==1 & _end0==1 & blnc_0==1  & type_account==1
	replace _dif_tot = _dif_tot[_n+1] if  _dif_tot==. & _seq0==1 & type_account==1
	
	egen aa = max(_mi) , by(_id)
	br aa _mi date *id afp_all type f* p* c23 c24 c26 date_* TI reld *bhijo if aa<.
	
	gen tag_f_cf = (_mi<=4 & type_account==1)
	egen total_balance = rowtotal(f1 f2 f3 f4 f5)
	tsspell , cond(total_balance>0) spell(_sp_bp) seq(_seqp) end(_endp)
	sort type_account ID date
	egen _length = max(_seqp), by(_id _sp_bp) //spell length by id-spell
	egen _length_id = max(_seqp), by(_id)  //longest spell by id
	keep if (_length==_length_id & _length>=12 & type_account==1) | type_account==2 //keep longest spell
	tsreport _id date, panel
	assert `r(N_gaps2)'==0
	drop _*
*/
