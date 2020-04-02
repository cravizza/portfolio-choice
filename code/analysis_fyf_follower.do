*** Portfolio Choice
*** ANALYSIS - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	*qui do "$general/code/clean_fyf.do"
	
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "$general/log/analysis_fyf_follower`date'.log", replace
	* Identifying followers 
	scalar_follower_share
	* Switches in FyF direction
	graph_fyf_freq, file(_all) from(1) to(5) over_acc(1) ///
						dates(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08)
	graph_fyf_freq, file(_all) from(5) to(1) over_acc(1) ///
						dates(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09)
	graph_fyf_freq, file(_all) from(1) to(5) over_acc(0) ///
						dates(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08)
	graph_fyf_freq, file(_all) from(5) to(1) over_acc(0) ///
						dates(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09)		
	* By gender (not needed?) & number switches
	graph_fyf_freq_gender
	graph_follower_N_sw
	log close
end

capture program drop scalar_follower_share
program              scalar_follower_share
	use "$general/output/derived_hpa.dta", clear
	preserve
		* Find number of distinct switchers
		gen 	rec_month = (!mi(rec))        if              date>=ym(2011,8)
		egen 	tag_IDrec = tag(ID rec_month) if sw_fund==1 & date>=ym(2011,8)
		assert 	tag_IDrec==0 if sw_fund==0 | rec_month==. 
		egen 	tag_ID	  = tag(ID)           if sw_fund==1 & date>=ym(2011,8)
		bys ID: egen sw_rec_n = sum(tag_IDrec)  //if date>=ym(2011,8)
		sum ID if sw_fund==1 & tag_ID==1 & date>=ym(2011,8)
		local switchers=r(N)
		di `switchers'
		qui sum sw_rec_n if tag_ID==1 & rec_month==1
			scalar_txt, number(r(N)/`switchers'*100) filename(switcher_fyf_rec_sh) decimal(1) //local sw_fyf_rec=r(N)
		qui sum sw_rec_n if tag_ID==1 & rec_month==0 &  sw_rec_n==1
			scalar_txt, number(r(N)/`switchers'*100) filename(switcher_fyf_norec_sh) decimal(1) //local sw_fyf_norec=r(N)
		qui sum sw_rec_n if tag_ID==1 &                 sw_rec_n==2
			scalar_txt, number(r(N)/`switchers'*100) filename(switcher_fyf_both_sh) decimal(1) //local sw_fyf_both=r(N)
		* Swiyches in FyF direction
		gen sw_fund_freq_sh = (sw_f15_freq+ sw_f51_freq)/sw_fund_freq
		* Use ID==1 since freq var are aggregate and it includes the full time period
		qui sum date if ID==1
		assert r(min)==ym(2007,1) & r(max)==ym(2013,12)
		keep if ID==1
		* Share of fund switches in FyF direction with respect to all accounts
		qui sum sw_fund_freq_sh if rec==1
			scalar_txt, number(r(mean)*100) filename(sw_fund_freq_sh_rec) decimal(1)
		qui sum sw_fund_freq_sh if mi(rec)
			scalar_txt, number(r(mean)*100) filename(sw_fund_freq_sh_NOrec) decimal(1)
		qui sum sw_fund_freq_sh if mi(rec) & (inrange(date,ym(2007,1),ym(2007,12))|inrange(date,ym(2009,6),ym(2013,12)))
			scalar_txt, number(r(mean)*100) filename(sw_fund_freq_sh_NOrecNOfc) decimal(1)
		qui sum sw_fund_freq_sh if mi(rec) & date>=ym(2011,6)
			scalar_txt, number(r(mean)*100) filename(sw_fund_freq_sh_NOrecFyF) decimal(1)
		qui sum sw_fund_freq_sh if mi(rec) & date<ym(2011,6)
			di r(mean)*100
			scalar_txt, number(r(mean)*100) filename(sw_fund_freq_sh_NOrecNOFyF) decimal(1)
	restore
end

capture program drop graph_fyf_freq
program              graph_fyf_freq
	syntax, dates(string) [from(string) to(string) file(string) over_acc(string) if_opt(string)]
	preserve
	use "$general/output/derived_hpa.dta", clear
	capture {
		confirm number `over_acc'
		}
		if !_rc {
				if `over_acc'==1 {
					local  denominator "accounts"
					local den acc
					}
				else {
					local denominator "switchers"
					local den swr
					}
				}		
	rename sw_fund_freq sw_fund_acc_freq
	label var sw_fund_`den'_freq "All switches"
	label var sw_f15_`den'_freq "From A to E"
	label var sw_f51_`den'_freq "From E to A"
	duplicates drop date  sw_f`from'`to'_`den'_freq, force
	replace sw_fund_`den'_freq = . if date==ym(2007,1)
	replace sw_f15_`den'_freq = . if date==ym(2007,1)
	replace sw_f51_`den'_freq = . if date==ym(2007,1)
	sort date 
	tw line sw_f`from'`to'_`den'_freq sw_fund_`den'_freq date `if_opt',  ///
		ylabel(#4, labs(small)) ytitle("Number of switches over total `denominator'")  ///
		tlabel(#8, labs(small)) ttitle("Month") /// *ymtick(0(0.005)0.015)
		tline(`dates') 
	graph export "$general\output\fyf_rec`from'`to'_`den'`file'.png", replace
	restore
end

capture program drop graph_fyf_freq_gender
program              graph_fyf_freq_gender
	preserve
	use "$general/output/derived_hpa.dta", clear
	gen _sw_g0 = 1 if gender==0
	gen _sw_g1 = 1 if gender==1
	forvalues i=0/1 {
		gen _sw_f15_`i' = (sw_fund==1 & sw_f_1from1==1 & sw_f_1to5==1 & gender==`i')
		gen _sw_f51_`i' = (sw_fund==1 & sw_f_1from5==1 & sw_f_1to1==1 & gender==`i')
		bys date: egen _sw_15_`i' = sum(_sw_f15_`i')
		bys date: egen _sw_51_`i' = sum(_sw_f51_`i')
		bys date: egen _sw_`i'    = sum(_sw_g`i')
		gen sw_f15_`i'_freq = _sw_15_`i'/_sw_`i'
		gen sw_f51_`i'_freq = _sw_51_`i'/_sw_`i'
	replace sw_f15_`i'_freq = . if date==ym(2007,1)
	replace sw_f51_`i'_freq = . if date==ym(2007,1)
	}
	bys date: gen  _sw_temp_N = _N
	assert _sw_temp_N==_sw_1+_sw_0
	drop _sw*
	label var sw_f15_0_freq "Female"
	label var sw_f51_0_freq "Female"
	label var sw_f15_1_freq "Male"
	label var sw_f51_1_freq "Male"
	duplicates drop date sw_f15_0_freq sw_f15_1_freq sw_f51_0_freq sw_f51_1_freq, force
	sort date //local from=substr("`frequency_var'",1,1)*local to  =substr("`frequency_var'",-1,1)
	tw line  sw_f51_1_freq sw_f51_0_freq date `if_opt',  ///
		ylabel(#4, labs(small)) ytitle("Number of switches over total accounts")  ///
		tlabel(#8, labs(small)) ttitle("Month") /// 
		tline(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09) 
	graph export "$general\output\fyf_rec51_acc_gender.png", replace
		tw line  sw_f15_1_freq sw_f15_0_freq date `if_opt',  ///
		ylabel(#4, labs(small)) ytitle("Number of switches over total accounts")  ///
		tlabel(#8, labs(small)) ttitle("Month") /// 
		tline(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08) 
	graph export "$general\output\fyf_rec15_acc_gender.png", replace
	restore
end

capture program drop graph_follower_N_sw
program              graph_follower_N_sw
	preserve
		use "$general/output/derived_hpa.dta", clear
		* Find number of distinct switchers
		egen 	tag_IDrec = tag(ID n_sw_fyf) 
		assert 	tag_IDrec==0 if sw_fyf==0 | n_sw_fyf==. 
		bys n_sw_fyf: egen foll_n = sum(tag_IDrec)
		* Assert
		egen 	tag_ID	  = tag(ID)  if sw_fyf==1 & date>=ym(2011,8)
		qui sum ID if tag_ID==1
		local followers=r(N)
		qui sum foll_n if n_sw_fyf ==1 & tag_ID==1
		assert r(N)==`followers'
		gen foll_by_n = foll_n/`followers'
		* Gender
		foreach var of varlist gender age_def TI_a50 {
			qui levelsof `var', local(levels)   //di `levels'
			local words: word count `levels' //di `words'
			forvalues w = 1/`words' {
				local j: word `w' of `levels'
				egen 	tag_`var'`j' = tag(ID n_sw_fyf)  if `var'==`j' & date>=ym(2011,8)
				bys n_sw_fyf: egen foll_`var'`j' = sum(tag_`var'`j')
				gen foll_by_`var'`j' = foll_`var'`j'/`followers'
			}
		}
		//assert foll_by_n==foll_gender0+foll_gender1
		* Collapse
		collapse (mean) foll_by_*, by(n_sw_fyf)
		sort n_sw_fyf
		la var foll_by_n        "All"       
		la var foll_by_gender0  "Female"
		la var foll_by_gender1	"Male"
		la var foll_by_age_def2 "Young" 
		la var foll_by_age_def3 "Middle age" 
		la var foll_by_age_def4 "Old"
		la var foll_by_TI_a500  "Below 50th" 
		la var foll_by_TI_a501  "Above 50th"
		foreach var in gender age_def TI_a50 {
			tw line foll_by_`var'* foll_by_n n_sw_fyf , legend(row(1) symx(7)) lp( "-#.." shortdash solid) ///
			 ytitle("Share of followers") xlabel(1(1)8) xtitle("Switches following FyF advice")  ///
			 ysize(4) xsize(4)
			graph export "$general\output\foll_sw_n_`var'.png", replace
		}		
	restore
end

main
