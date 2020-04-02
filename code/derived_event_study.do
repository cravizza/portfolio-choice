*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/derived_event_study`date'.log", replace
	dataset_IDevent_pairs
	ES_setup, id_var(ID_sw) time_var(date) event_var(sw_event) months_event(12) months_estim(12)
	return_by_direction
	ev_and_dif_time_switch	
	cumulative_return
	statistic_return, past_months(3)
	demo_event_window 
	labeling
	sum sw_ev_l sw_ev_f rp* cr* stat_* 
	order ID-r5 rp_* dif* event_*  *_ev_* cr_* crdef* stat_* age_* TI* sw_* sh_* def* n_* ///
	       blnc *_pred *_adj *_ret *_dif  nm* cav*
	save "../output/derived_ES.dta", replace
	log close
end

capture program drop dataset_IDevent_pairs
program              dataset_IDevent_pairs	
	di "-- Setup database to include multiple events by ID (joinby)"
	use "../output/derived_hpa.dta", clear
	di "-- Exclude switches that occur closer than 6 months"
	tsset ID date
	tsspell , cond(sw_fund==0) spell(_sp_nosw)
	egen length = max(_seq), by(id _sp_nosw)
	gen sw_fund_ES=1 if sw_fund==1 & N_sw_fund==1 |(sw_fund==1 & N_sw_fund>1 ///
	                     & length[_n-1]>=2 & length[_n+1]>=2 & ID==ID[_n+1] & ID==ID[_n-1])
	replace sw_fund_ES=0 if sw_fund_ES==.
	
	di "-- Define event dates and new identifier that associates ID with each switch" 
	keep ID date N_sw_fund sw_fund_ES sw_f_*fr* sw_f_*to*
	by ID: gen sw_num = 0 if N_sw_fund==0 & _n==1
	keep if (sw_fund_ES==1 & N_sw_fund>0) | (sw_num==0)
	by ID: replace sw_num = _n if N_sw_fund>0
	egen ID_sw = group(ID sw_num)
	isid ID_sw
	
	gen sw_event   = sw_fund_ES if sw_fund_ES==1
	gen sw_ev_from = sw_f_from  if sw_event==1
	gen sw_ev_to   = sw_f_to    if sw_event==1
	forvalues f=1/5 {
		gen sw_ev_from`f' = sw_f_1from`f'  if sw_event==1
		gen sw_ev_to`f'   = sw_f_1to`f'    if sw_event==1
	}
	tempfile event_dates
	save `event_dates', replace
	
	di "-- Create new dataset that includes observations for each ID_sw"
	keep ID_sw ID
	joinby  ID using "../output/derived_hpa.dta"
	sort ID (ID_sw) date
	
	di "-- Add the switch direction variables for these ID's"
	merge  1:1 ID ID_sw date using `event_dates', keepusing(sw_event sw_ev_*) assert(1 3) nogen
	replace sw_event=0 if sw_event==.
	bys ID_sw (sw_ev_from): replace sw_ev_from = sw_ev_from[1]
	bys ID_sw (sw_ev_to):   replace sw_ev_to   = sw_ev_to[1]
	forvalues f=1/5 {
		bys ID_sw (sw_ev_from`f'): replace sw_ev_from`f' = sw_ev_from`f'[1]
		bys ID_sw (sw_ev_to`f'):   replace sw_ev_to`f' =   sw_ev_to`f'[1]
	}
end
	
capture program drop ES_setup
program              ES_setup
	di "-- Setup event study time variables"
	*event_var is a variable that takes value 1 in the obs (id/month) when the event occurs (time 0)
syntax, id_var(varlist) time_var(varlist) event_var(varlist) months_event(real) months_estim(real)
	bys `id_var' (`time_var'): gen  temp_datenum = _n
	bys `id_var' (`time_var'): gen  temp_target  = temp_datenum if `event_var'==1
	bys `id_var'		 	 : egen temp_td      = min(temp_target)
	gen dif = temp_datenum - temp_td
	
	bys `id_var': gen       event_window = 1 if dif>=-`months_event' & dif<=`months_event'
	bys `id_var': egen temp_count_ev_obs = count(event_window)
	replace event_window = 0 if event_window==.
	
	bys `id_var': gen estimation_window = 1 if dif<-`months_estim' & dif>=-2*`months_estim'
	bys `id_var': egen temp_count_es_obs = count(estimation_window)
	replace estimation_window=0 if estimation_window==.
	*table temp_count* , c(count `id_var')
	drop temp_*
end	
	
capture program drop return_by_direction	
program              return_by_direction
	di "-- Average return with fund shares fixed to before/after switching funds"
	forvalues f=1/5 {
		tempvar sh_`f'fr
		by ID_sw (date): egen sh_`f'fr = max(sh_f`f'[_n-1]*sw_event) if event_window==1 
		by ID_sw (date): egen sh_`f'to = max(sh_f`f'*sw_event)       if event_window==1 
		assert sh_`f'fr == sh_f`f'[_n-1] if sw_event==1 
		assert sh_`f'to == sh_f`f'       if sw_event==1
		replace sh_`f'fr = sh_`f'fr[_n-1] if dif==13
		replace sh_`f'to = sh_`f'to[_n-1] if dif==13
	}
	gen       rp_fr  = rp_f                                              if event_window==1 & dif<0
	replace   rp_fr  = sh_1fr*r1+sh_2fr*r2+sh_3fr*r3+sh_4fr*r4+sh_5fr*r5 if (event_window==1 & dif>=0) | dif==13
	gen       rp_to  = rp_f                                              if (event_window==1 & dif>=0) | dif==13
	replace   rp_to  = sh_1to*r1+sh_2to*r2+sh_3to*r3+sh_4to*r4+sh_5to*r5 if event_window==1 & dif<0
	gen       rp_dif = rp_to-rp_fr                                       if (event_window==1) | dif==13
	
	label var rp_dif "Average return difference destination/origin portfolio"
	label var rp_fr  "Average return of origin portfolio"
	label var rp_to  "Average return of destination portfolio"
end	

capture program drop ev_and_dif_time_switch	
program              ev_and_dif_time_switch	
	sort ID_sw date
	rename	dif     dif_f 
	gen 	dif_l = dif_f - 1 if dif_f>=-11 & dif_f<=13
	rename 	event_window event_f
	gen 	event_l = (!mi(dif_l))
	rename 	sw_event  sw_ev_f
	gen 	sw_ev_l = sw_ev_f[_n-1] if ID_sw==ID_sw[_n-1]
	replace sw_ev_l = 0 if sw_ev_l==.
	replace dif_f = . if dif_f>12 | dif_f<-12
end

capture program drop cumulative_return
program              cumulative_return
	di "-- Cum.ret. for different switching timing: first and last of the month"
	foreach sw_t in _f _l {
		qui gen temp_lnrp`sw_t' = ln(1+rp`sw_t') if event`sw_t'==1 & dif`sw_t'>0
		foreach month of numlist 2 12 {
			local postev event`sw_t'==1 & dif`sw_t'>0 & dif`sw_t'<=`month'
			qui	bys ID_sw (date): egen temp_slrp`sw_t'`month' = sum(temp_lnrp`sw_t')        if `postev' 
			qui bys ID_sw (date): gen cr`sw_t'_`month'm     = exp(temp_slrp`sw_t'`month')-1 if `postev' & sw_ev`sw_t'[_n-1]==1 
			replace cr`sw_t'_`month'm = cr`sw_t'_`month'm[_n+1] if dif`sw_t'==0 
			replace cr`sw_t'_`month'm = . if dif`sw_t'==1
		}
		drop temp_*
	}
	foreach name in _dif def  _to _fr {
		foreach sw_t in _f _l {
			qui gen temp_lnrp`name'`sw_t' = ln(1+rp`name') if event`sw_t'==1 & dif`sw_t'>0
			foreach month of numlist 2 12 {
				local postev event`sw_t'==1 & dif`sw_t'>0 & dif`sw_t'<=`month'
				qui	bys ID_sw (date): egen temp_slrp`name'`month'`sw_t' = sum(temp_lnrp`name'`sw_t')      if `postev' 
				qui bys ID_sw (date): gen cr`name'`sw_t'_`month'm    = exp(temp_slrp`name'`month'`sw_t')-1 if `postev' & sw_ev`sw_t'[_n-1]==1 
				replace cr`name'`sw_t'_`month'm = cr`name'`sw_t'_`month'm[_n+1] if dif`sw_t'==0 
				replace cr`name'`sw_t'_`month'm = . if dif`sw_t'==1
			}
		}
		drop temp_*
	}
	/*foreach name in avg avg_to avg_dif avg_from avg_l def {
		qui gen temp_lnr`name' = ln(1+ret_`name') if event_window==1 & dif>=0
		
		foreach month of numlist 2 6 12 {
			local postev event_window==1 & dif>=0 & dif<=`month'
		
		qui	bys ID_sw (date): egen temp_slr`name'`month' = sum(temp_lnr`name')          if `postev' 
			bys ID_sw (date): gen cret_`name'`month'm    = exp(temp_slr`name'`month')-1 if `postev' & sw_event==1 
		}
		drop temp_*
	}*/
end
	
capture program drop statistic_return	
program              statistic_return
	syntax, past_months(integer)
	local p=`past_months' //avg return of past 3 months wrt past trend
	foreach direc in dif {
		foreach sw_t in _f _l {
			bys ID_sw (date): egen rp_T`direc'`sw_t' =  mean(rp_`direc') 	                     if                   dif`sw_t'<-`p' & event`sw_t'==1
			bys ID_sw (date): egen rp_t`direc'`sw_t' =  mean(rp_`direc') 	                     if dif`sw_t'>=-`p' & dif`sw_t'<0    & event`sw_t'==1
			gen stat_`direc'`sw_t' = (rp_t`direc'`sw_t'[_n-1]-rp_T`direc'`sw_t'[_n-`p'-1])       if sw_ev`sw_t'==1                   & event`sw_t'==1
			sum stat_`direc'`sw_t'
			gen stat_`direc'`sw_t'_se = `r(sd)'/sqrt(`r(N)')					                 if sw_ev`sw_t'==1 & stat_`direc'`sw_t'!=. & event`sw_t'==1
		}
	}
	drop rp_tdif* rp_Tdif*
end

/*capture program drop statistic_loss	
program              statistic_loss
	gen stat_loss = (ret_avg[_n-1]<0) if sw_event==1 & event_window==1
	sum stat_loss
		gen stat_loss_se = `r(sd)'/sqrt(`r(N)') ///
					if stat_loss!=. & event_window==1 & sw_event==1
end*/

capture program drop demo_event_window 
program              demo_event_window 
	local ev_w (event_l==1 | event_f==1)
	local sw_ev (sw_ev_f==1|sw_ev_l==1)
	di "-- Include mean TI"
	foreach var in TI TI0 {
		bys ID_sw: egen `var'_event = mean(`var') if `ev_w'
		qui sum `var'_event if `sw_ev', det
		gen        `var'_ev_quart = 4 if `r(p75)'<=`var'_event                        & `sw_ev' & `var'_event!=.
		replace    `var'_ev_quart = 3 if `r(p50)'<=`var'_event & `var'_event<`r(p75)' & `sw_ev' & `var'_event!=.
		replace    `var'_ev_quart = 2 if `r(p25)'<=`var'_event & `var'_event<`r(p50)' & `sw_ev' & `var'_event!=.
		replace    `var'_ev_quart = 1 if `r(p25)'>=`var'_event                        & `sw_ev' & `var'_event!=.
		bys ID_sw (`var'_ev_quart): replace `var'_ev_quart = `var'_ev_quart[1]
		
		gen        `var'_ev_50    = 1 if `r(p50)'<=`var'_event & `sw_ev'
		replace    `var'_ev_50    = 0 if `r(p50)'> `var'_event & `sw_ev'
		bys ID_sw (`var'_ev_50)   : replace `var'_ev_50    = `var'_ev_50[1]
	}	
	di "-- Include age default at event"
	gen         age_ev_def = age_def if `sw_ev'
	bys ID_sw (age_ev_def) : replace age_ev_def  = age_ev_def[1]
end

capture program drop labeling
program              labeling
	di "-- Labeling"
	bys ID_sw: egen temp_max_f = max(dif_f) if event_f==1
	bys ID_sw: egen temp_max_l = max(dif_l) if event_l==1
	gen temp_max = min(temp_max_f,temp_max_l)
	bys ID_sw: egen dif_max = min(temp_max) 
	bys ID_sw: egen temp_min_f = min(dif_f) if event_f==1
	bys ID_sw: egen temp_min_l = min(dif_l) if event_l==1
	gen temp_min = max(temp_min_f,temp_min_l)
	bys ID_sw: egen dif_min = max(temp_min)
	drop temp_*
	/*local ev_w (event_l==1 | event_f==1)
	bys ID_sw: egen dif_max = max(dif_f|dif_l) if `ev_w' //event_window==1
	bys ID_sw: egen dif_min = min(dif_f) if `ev_w' //event_window==1

	local sw_ev (sw_ev_f==1|sw_ev_l==1) // sw_event==1
	foreach direc in to from {
		gen s_`direc'_risky = (sw_ev_`direc'1|sw_ev_`direc'2) ///
			if `sw_ev' & sw_ev_`direc'1!=.|sw_ev_`direc'2!=.
		gen s_`direc'_conse = (sw_ev_`direc'4|sw_ev_`direc'5) ///
			if `sw_ev' & sw_ev_`direc'4!=.|sw_ev_`direc'5!=.
	}
	gen     s_to   = 1 if `sw_ev' & s_to_risky==1   & s_to_conse!=1
	replace s_to   = 0 if `sw_ev' & s_to_risky!=1   & s_to_conse==1
	gen     s_from = 1 if `sw_ev' & s_from_risky==1 & s_from_conse!=1
	replace s_from = 0 if `sw_ev' & s_from_risky!=1 & s_from_conse==1
	gen     s_dif  = 1 if `sw_ev' & stat_dif!=.*/
	
	la var age_ev_def  "Age group"
	la def age_ev_def  2 "Young" 3 "Middle age" 4 "Old"
	la val age_ev_def age_ev_def
	
	foreach var in TI TI0 {
		la var `var'_ev_quart "Income quartile"
		la def `var'_ev_quart 1 "1st" 2 "2nd" 3 "3rd" 4 "4th"
		la val `var'_ev_quart `var'_ev_quart
		
		la var `var'_ev_50    "Income percentile"
		la def `var'_ev_50    0 "Below 50th" 1 "Above 50th"
		la val `var'_ev_50 `var'_ev_50
		}
	
	/*la var s_to        "Destination fund"
	la def s_to        0 "Conservative" 1 "Agressive"
	la val s_to s_to
	
	la var s_from      "Origin fund"
	la def s_from      0 "Conservative" 1 "Agressive"
	la val s_from s_from
	
	la var s_dif       "Destination vs Origin"
	la def s_dif       1 "Difference"
	la val s_dif s_dif*/
end

main

