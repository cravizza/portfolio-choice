*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	*qui do "$general/code/clean_fyf.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "$general/log/derived_fyf`date'.log", replace
	data_ind_level
	data_ind_rec_level
	data_graph_fyf_AE
	data_fyf_dailyES
	log close
end

program data_ind_level
	* Setup sample at the individual level
	use "$general/output/derived_hpa.dta", clear
	keep if date>=ym(2011,6) & rec==1
	rename gender sex
	rename TI_a50 ti
	rename TI_quart tiq
	by ID: egen ad = mean(age_def)
	replace ad = round(ad)
	la var ad  "Age group"
	la def ad  2 "Young" 3 "Middle age" 4 "Old"
	la val ad ad
	duplicates drop ID rec N_sw_fund N_sw_fyf fyf_follower sex ti tiq ad, force
	isid ID
	egen tag = group(ID)
	keep ID rec N_sw_fund N_sw_fyf fyf_follower sex ti tiq ad tag
	save "$general/output/tab_ind_level.dta", replace 
//	save "$general/output/tab_fyf_follower.dta", replace
end

program data_ind_rec_level
	* Setup sample at the recommendation/individual level
	use "$general/output/derived_hpa.dta", clear
	keep if date>=ym(2011,6) & rec==1 & fyf_follower_t==1 & !mi(n_sw_fyf) //gen tag = (rec==1 & fyf_follower_t==1 & !mi(n_sw_fyf))
	assert !mi(n_rec) & !mi(n_sw_fyf) & !mi(N_sw_fyf) & !mi(sw_fyf)
	gen _temp = -n_rec
	bys ID (_temp): gen fyf_rec_left = _n //if tag==1
	gen fyf_sw_left = N_sw_fyf - n_sw_fyf + sw_fyf //if tag==1
	sort ID date
	isid ID fyf_rec_left
	gen fyf_sh_sw_rec = fyf_sw_left/fyf_rec_left
	
	rename gender sex
	rename TI_a50 ti
	rename TI_quart tiq
	by ID: egen ad = mean(age_def)
	replace ad = round(ad)
	la var ad  "Age group"
	la def ad  2 "Young" 3 "Middle age" 4 "Old"
	la val ad ad
	egen tag = group(ID n_rec)
	keep ID rec n_rec *fyf* sex ti tiq ad tag
	save "$general/output/tab_ind_rec_level.dta", replace  
//	save "$general/output/tab_fyf_sh_sw_rec.dta", replace
end
								  
capture program drop data_graph_fyf_AE
program              data_graph_fyf_AE
	use "$general/raw/clean_sharevalue.dta", clear
	merge 1:1 date afp_all using "$general/raw/clean_fyf_rec_delay2.dta", nogen assert(3) keepus(ret_fyf)
	collapse (mean) r1=r1 r5=r5 ret_fyf=ret_fyf, by(date)
	gen diff = r1-r5 
	la var r1 "Return of fund A"
	la var r5 "Return of fund E"
	la var diff "Return difference (A-E)"
	sort date
	save "$general/output/graph_fyf_AE.dta", replace
end

capture program drop data_fyf_dailyES
program              data_fyf_dailyES
	di "- Event study treating rec's indivually, 14 days apart by construction"
	use "$general/raw/clean_fyf_delay0daily.dta", clear
	collapse (mean) rA=r1 rB=r2 rC=r3 rD=r4 rE=r5 rfyf=rfyf rec*, by(date)
	drop if rA==0 & rB==0 & rC==0 & rD==0 & rE==0
	sort date
	gen day =_n
	tempfile returns
	save `returns'
	egen n_rec = group(day rec) if rec==1
	keep if n_rec!=.
	keep day n_rec rec*
	foreach f in A B C D E {
		rename rec`f' event_window`f'
	}
	expand 15
	sort n_rec day
	bys n_rec: gen dif= _n
	replace dif = dif-8
	replace day = day + dif
	gen event_window = 1 if dif!=.
	replace rec=. if dif!=0
	joinby day using `returns',  unmatched(both)
	assert  _merge==2 | _merge==3 if _merge>0
	sort date
	di "- Generate placebo recommendation dates"
	//set seed 1234//generate rannum = uniform() if _merge==2 & event_window[_n-14]==0 & event_window[_n+14]==0 //sort rannum
	gen tag = 1  if day==10  |day==60  |day==111 |day==150 |day==230 |day==470 |day==550 | ///
					day==666 |day==700 |day==890 |day==1000|day==1166|day==1288|day==1333| ///
					day==1444|day==1533|day==1600|day==1666|day==1755|day==1811|day==2000| ///
					day==2266|day==2323|day==2355|day==2444|day==333 |day==410 |day==1930
	gen placebo = .
	local i -7
	while `i'<=7 {
		replace placebo = 1   if placebo==. & tag[_n-`i'-7]==1
		replace dif     = `i' if dif==.     & tag[_n-`i'-7]==1
		local i = `i'+1
	}
	drop _merge day tag 
	save "$general/output/fyf_eventstudy.dta", replace
end

capture program drop followers_eventstudy
program              followers_eventstudy
// PROBABLY NOT USING THIS PROGRAM
	 use "../output/derived_ES.dta", clear
	 sort ID_sw date
	 br ID ID_sw date sw_follower sw_fyf n_rec rec
	 bys ID_sw: egen temp_max_sw_fyf = max(n_sw_fyf)
	 bys ID_sw: egen temp_recs = total(rec)
	 
	 keep if follower==1
	 bys ID_sw: gen sw_follower_again = (temp_max_sw_fyf>1) if sw_follower==1
	 gen sh_advice_followed = (temp_max_sw_fyf)/temp_recs
	 
	 bys ID_sw: gen sw_fyf_first = (n_sw_fyf==1 & dif==0 & sw_event==1) 
end

main
