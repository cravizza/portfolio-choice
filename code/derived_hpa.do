*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/derived_hpa`date'.log", replace
	use "../raw/clean_newvars.dta", clear
	switch_fund
	switch_direction
	switch_frequency
	fix_default
	switch_advice
	return_by_portfolio
	cumulative_return
	labeling
	sum sw_f1-sw_f5 sw_firm sw_fund sw_fundfirm sw_f*freq fyf*
	order  date ID age-r5 ret_* r* sw_* *_sw_fund *_pred nmf* TI-bhijo ch_* I_* cav* date_* tag* v* c2-c35
	drop v* c2-c35 *_b0 def_* rat_* av_* ch_* I_*  date_* tag_* cav_* p* reld bhijo sw_1d
	sort ID date
	save "../output/derived_hpa.dta", replace
	log close 
end

capture program drop switch_fund
program              switch_fund
	di "-- Switch if m/nm, same ID, not default"
	forvalues x=1/5 {
		bys ID (date): gen sw_f`x' = (nmf`x'[_n]!=nmf`x'[_n-1] & ID[_n]==ID[_n-1] /// & default[_n-1]==0
		                           & (default==0 )) //|(default==1&default[_n-1]==0)) )  //  
	}	
	gen sw_fund = max(sw_f1,sw_f2,sw_f3,sw_f4,sw_f5)
	gen sw_fundfirm = (sw_fund==1 & sw_firm==1)
	tab sw_fund
end

capture program drop switch_direction
program              switch_direction
	di "-- Switch direction: one or two digit variable"
	sort ID date
	gen sw_f_to = .
	gen sw_f_from = .
	forvalues f=1/5 {
		local switch_now sw_fund==1 & nmf`f'==1 
		local switch_pre sw_fund==1 & nmf`f'[_n-1]==1
		replace sw_f_to   = `f'           if `switch_now' & n_f==1       & sw_f_to==. 
		replace sw_f_to   = `f'*10        if `switch_now' & n_f==2       & sw_f_to==.
		replace sw_f_to   = sw_f_to+`f'   if `switch_now' & n_f==2       & sw_f_to!=`f'*10
		replace sw_f_from = `f'           if `switch_pre' & n_f[_n-1]==1 & sw_f_from==. 
		replace sw_f_from = `f'*10        if `switch_pre' & n_f[_n-1]==2 & sw_f_from==.
		replace sw_f_from = sw_f_from+`f' if `switch_pre' & n_f[_n-1]==2 & sw_f_from!=`f'*10
	}
	forvalues f=1/4 {
		assert  sw_f_to   == `f'5 if sw_fund==1 & nmf`f'==1       & nmf5==1       & n_f==2
		assert  sw_f_from == `f'5 if sw_fund==1 & nmf`f'[_n-1]==1 & nmf5[_n-1]==1 & n_f[_n-1]==2
	}
	*NOTE: to extract the funds from sw_f_to:
	*====* 2nd term or n_f==1 = sw_f_to - floor(sw_f_to/10)*10
	*====* 1st term w/ n_f==2 = floor(sw_f_to/10) 
	di "-- One variable per fund direction"
	forvalues f=1/5 {
		gen sw_f_1to`f'   = 1 if sw_fund==1 & nmf`f'==1
		gen sw_f_1from`f' = 1 if sw_fund==1 & nmf`f'[_n-1]==1
	}
	table sw_f_from sw_f_to
end

capture program drop switch_frequency
program              switch_frequency
	di "-- Frequency of switches over time with respect to all accounts"
	freq_var , targetvar(sw_firm)     over(date) newvar(sw_firm)
	freq_var , targetvar(sw_fund)     over(date) newvar(sw_fund)
	freq_var , targetvar(sw_fundfirm) over(date) newvar(sw_firmfund)
	*gen _sw_f15 = (sw_fund==1 & sw_f_from==1 & sw_f_to==5)
	*gen _sw_f51 = (sw_fund==1 & sw_f_from==5 & sw_f_to==1)
	gen _sw_f15 = (sw_fund==1 & sw_f_1from1==1 & sw_f_1to5==1)
	gen _sw_f51 = (sw_fund==1 & sw_f_1from5==1 & sw_f_1to1==1)
	freq_var , targetvar(_sw_f15) over(date) newvar(sw_f15_acc)
	freq_var , targetvar(_sw_f51) over(date) newvar(sw_f51_acc)
	di "-- Frequency of switches over time with respect to the switchers"
	bys ID  : egen _swr_all_0 = max(sw_fund)
	bys date: egen _swr_all   = sum(_swr_all_0)
	bys date: egen _swr_15    = sum(_sw_f15)
	bys date: egen _swr_51    = sum(_sw_f51)
	bys date: egen _swr_f     = sum(sw_fund)
	gen sw_f15_swr_freq = _swr_15/_swr_all
	gen sw_f51_swr_freq = _swr_51/_swr_all
	gen sw_fund_swr_freq = _swr_f/_swr_all
		di "--  Number of switches and dummy"
	bys ID sw_fund (date): gen n_sw_fund = _n if sw_fund==1
	bys ID (date): carryforward n_sw_fund, replace
	bys ID: egen N_sw_fund = total(sw_fund) // bys  date: gen  Nid = _N
	drop _sw*
end

capture program drop fix_default
program              fix_default
	di "-- Fix defaults: after switch cannot be in default"
	bys ID (date):     egen sw_1d = min(date) if sw_fund==1
	bys ID (sw_1d): replace sw_1d = sw_1d[1]  if sw_1d==.
	format %tm sw_1d
	sort ID date
	local demo_1   age<=35
	local demo_2 (age>35 & age<=39)
	local demo_3 ((age>39 & age<=55 & gender==1)|(age>39 & age<=50 & gender==0))
	local demo_4 ((age>55 & age<=59 & gender==1)|(age>50 & age<=54 & gender==0))
	local demo_5 ((age>59           & gender==1)|(age>54           & gender==0))
	local alloc1 n_f==1 & nmf2==1
	local alloc2 n_f==2 & nmf2==1 & nmf3==1
	local alloc3 n_f==1 & nmf3==1
	local alloc4 n_f==2 & nmf3==1 & nmf4==1
	local alloc5 n_f==1 & nmf4==1
	gen default_rev = default
	forvalues i=1/5 {
		local j=`i'+1
		replace default_rev = 1 if default==0 & n_sw_f==0 & `demo_`i'' & `alloc`i'' 
		replace default_rev = 1 if default==0 & n_sw_f>0  & `demo_`i'' & `alloc`i'' &  date<sw_1d
		replace default_rev = 0 if default==1 & n_sw_f>0  & `demo_`i'' & `alloc`i'' &  date>=sw_1d
	}
	assert default_rev==0 | default_rev==1
end

capture program drop switch_advice
program              switch_advice
	merge m:1 date afp_all using "$general/raw/clean_fyf_rec_delay5.dta", ///
			nogen assert(3 2) keep(3) keepusing(rec* n_rec)
	merge m:1 date afp_all using "$general/raw/clean_fyf_rec_delay2.dta", ///
			nogen assert(3 2) keep(3) keepusing(rfyf)
	gen temp_dir = (n_f==1 & ((nmf1>0 & recA>0)|(nmf2>0 & recB>0)|(nmf3>0 & recC>0)| ///
							  (nmf4>0 & recD>0)|(nmf5>0 & recE>0)) ) if rec==1
	gen sw_fyf = (rec==1 & sw_fund==1 & temp_dir==1)
	bys ID: egen fyf_follower = max(sw_fyf)	
	label var fyf_follower "Dummy for following advice at least once"
	
	bys ID sw_fyf (date): gen n_sw_fyf = _n if sw_fyf==1
	bys ID (date): carryforward n_sw_fyf, replace
	//replace n_sw_fyf = 0 if n_sw_fyf==. & sw_fund==1
	bys ID: egen N_sw_fyf = max(n_sw_fyf)
	
	gen fyf_follower_t = (n_sw_fyf>0 & n_sw_fyf!=.)
	by ID (date): replace fyf_follower_t=1 if fyf_follower_t[_n-1]==1
	gen fyf_keep_t = (n_sw_fyf < N_sw_fyf)
	label var fyf_follower_t "Becomes a follower after following advice for the 1st time"
		
	gen fyf_port = (recA==sh_f1 & recB==sh_f2 & recC==sh_f3 & recD==sh_f4 & recE==sh_f5) if fyf_follower_t==1

	bys ID (sw_fund date): gen sw_fyf_cons = (n_rec[_n+1]-n_rec==1 & n_sw_fyf[_n+1]-n_sw_fyf==1) if sw_fyf==1
	replace sw_fyf_cons=2 if sw_fyf_cons==0 & ID!=ID[_n+1] ///
							& n_rec-n_rec[_n-1]==1 & n_sw_fyf-n_sw_fyf[_n-1]==1
	sort ID date
end

capture program drop return_by_portfolio
program              return_by_portfolio
	di "-- Switch the 1st, 15th, and last day of the month"
	gen 	rp_f = ret_avg
	gen     rp_m = ret_avg
	replace rp_m = ret_avg*0.5 + ret_avg[_n-1]*0.5 if sw_fund==1 & ID==ID[_n-1]
	gen     rp_l = ret_avg
	replace rp_l = ret_avg[_n-1] if sw_fund==1 & ID==ID[_n-1]
	di "-- Assert"
	foreach var in rp_f rp_m rp_l {
		assert `var'!=.
		assert `var'==r1 if nmf1==1 & n_f==1  & sw_fund!=1
		assert (r1<`var' & `var'<r2)|(r2<`var' & `var'<r1) if nmf1==1 & nmf2==1 & sw_fund!=1
		assert (r2<`var' & `var'<r3)|(r3<`var' & `var'<r2) if nmf2==1 & nmf3==1 & f2!=0 & f3!=0 & sw_fund!=1
	}
	assert (rp_f==rp_m) & (rp_f==rp_l) if sw_fund!=1
	assert (rp_f!=rp_m) & (rp_f!=rp_l) if sw_fund==1
end

capture program drop cumulative_return
program              cumulative_return
	bys ID (date):         gen temp_date = _n
	bys ID (sw_fund date): gen temp_sw = temp_date if sw_fund==1
	bys ID               : egen temp_t = min(temp_sw)
	gen sw_months = temp_date - temp_t
	bys ID (date): gen sw_post = 1 if sw_months>=0 & sw_months!=.
	
	di "-- Cumulative return by the end of the period, after the switch"
	foreach name in p_f p_m p_l pdef {
		qui gen temp_lnr`name' = ln(1+r`name')                      if sw_post==1
		qui	bys ID (date): egen temp_slr`name' = sum(temp_lnr`name')   if sw_post==1
			bys ID (date): gen cr_ps_`name'  = exp(temp_slr`name')-1 if sw_post==1 
	}
	drop temp_*
	di "-- Cumulative return monthly, after the switch"
	foreach name in p_f p_m p_l pdef {
		bys ID (date): gen cr_m_`name'=(1+r`name') if sw_months==0 & sw_post==1
		replace cr_m_`name'=(1+r`name')*l.cr_m_`name' if mi(cr_m_`name') & sw_post==1
		replace cr_m_`name'=cr_m_`name'-1 if sw_post==1
	}
end

capture program drop labeling
program              labeling	
	di "-- Labeling"
	la var rp_f "Portfolio return - 1st day sw"
	la var rp_m "Portfolio return - 15th day sw"
	la var rp_l "Portfolio return - last day sw"
	
	la var cr_m_p_f "Cum.ret. monthly - 1st day sw portfolio"
	la var cr_m_p_m "Cum.ret. monthly - 15th day sw portfolio"
	la var cr_m_p_l "Cum.ret. monthly - last day sw portfolio"
	la var cr_m_pdef "Cum.ret. monthly - default portfolio"
		
	la var cr_ps_p_f "Cum.ret. final - 1st day sw portfolio"
	la var cr_ps_p_m "Cum.ret. final - 15th day sw portfolio"
	la var cr_ps_p_l "Cum.ret. final - last day sw portfolio"
	la var cr_ps_pdef "Cum.ret. final - default portfolio"
	
	la var gender "Gender"
	la def gender 0 "Female" 1 "Male"
	la val gender gender
	
	la var age_def  "Age group"
	la def age_def  2 "Young" 3 "Middle age" 4 "Old"
	//la def age_def  2 "Default fund 2" 3 "Default fund 3" 4 "Default fund 4"
	la val age_def age_def
	
	foreach var in TI TI0 {
		la var `var'_a50    "Income percentile"
		la def `var'_a50    0 "Below 50th" 1 "Above 50th"
		la val `var'_a50 `var'_a50
		
		la var `var'y_a50    "Income percentile"
		la def `var'y_a50    0 "Below 50th" 1 "Above 50th"
		la val `var'y_a50 `var'y_a50
		
		la var `var'_quart  "Income quartile"
		la def `var'_quart  1 "1st" 2 "2nd" 3 "3rd" 4 "4th"
		la val `var'_quart `var'_quart
		
		la var `var'y_quart "Income quartile"
		la def `var'y_quart 1 "1st" 2 "2nd" 3 "3rd" 4 "4th"
		la val `var'y_quart `var'y_quart
	}
	
	la var default_rev "Default option"
	la def default_rev 0 "No" 1 "Yes"
	la val default_rev default_rev

	la var n_f         "Fund allocation"
	la def n_f         1 "One fund" 2 "Two funds"
	la val n_f n_f
	
	la var f1 "Fund A"
	la var f2 "Fund B"
	la var f3 "Fund C"
	la var f4 "Fund D"
	la var f5 "Fund E"
	label var sw_months "Months after first switch"
end

main

/*
	bys id: gen temp_r_target = returns if fund_sw==1
	bys id: egen temp_r_td     = min(temp_r_target)
	gen ret_n = returns - temp_r_td
	*gen date_sw = date if sw_fund==1
	*bys ID (date): replace date_sw = date_sw[_n+1] if date_sw[_n+1]!=. & date_sw[_n-1]==.
*/
