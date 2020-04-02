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
	log using "$general/log/analysis_fyf_advisor`date'.log", replace
	
	graph_fyf_freq_sw, if_opt(if date>=ym(2011,06)) from(1) to(5) ///
						dates(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08)
	graph_fyf_freq_sw, if_opt(if date>=ym(2011,06)) from(5) to(1) ///
						dates(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09)
	graph_fyf_freq_sw, if_opt(if date>=ym(2011,06)) ///
						dates(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08 ///
							  2011m10 2012m01 2012m06 2013m01 2013m07 2013m09)
	graph_fyf_freq_sw, file(_all) from(1) to(5) ///
						dates(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08)
	graph_fyf_freq_sw, file(_all) from(5) to(1) ///
						dates(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09)
	graph_fyf_freq_sw, file(_all) ///
						dates(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08 ///
						2011m10 2012m01 2012m06 2013m01 2013m07 2013m09)
	graph_fyf_ret_AE
	graph_fyf_cret_daily, cutoff(2011,06) delay_days(2)
	graph_fyf_cret_daily, cutoff(2012,04) delay_days(2)
	graph_fyf_cret_daily, cutoff(2015,01) delay_days(2)
	
	graph_fyf_dailyES
	graph_fyf_ret_delay							   

	log close
end
		
				
capture program drop graph_fyf_freq_sw
program              graph_fyf_freq_sw
	syntax, dates(string) [from(string) to(string) file(string) if_opt(string)]
	preserve
	use "$general/output/derived_hpa.dta", clear
	capture {
		confirm number `to'
		confirm number `from'
		}
		if !_rc {
				local subsample sw_fund==1 & sw_fund==1 & sw_f_fr==`from' & sw_f_to==`to'
				if `from'==1 {
					local fromL A
					}
				else local fromL E
				if `to'==1 {
					local toL A
					}
				else local toL E
				local fromto `fromL'`toL'
				local description from `fromL' to `toL'
                }
		else {
				local subsample sw_fund==1 & sw_fund==1
				local fromto all
				rename sw_fund_freq sw_f_freq
				local description all
				}
	sum id if (`subsample')
	local obs `r(N)'
	duplicates drop date  sw_f`from'`to'_freq, force
	sort date //local from=substr("`frequency_var'",1,1)*local to  =substr("`frequency_var'",-1,1)
	tw line sw_f`from'`to'_freq date `if_opt',  ///
		ylabel(#4, labs(small)) ytitle("Number of switches over total accounts")  ///
		tlabel(#8, labs(small)) ttitle("Month") /// *ymtick(0(0.005)0.015)
		tline(`dates') ///
		title("Fund switches and FyF recommendations") ///
		note("Note: Vertical solid lines indicate FyF recommendations: `description' (obs=`obs').")
	graph export "$general\output\fyf_rec`fromto'`file'.png", replace
	restore
end
	
capture program drop graph_fyf_ret_AE
program              graph_fyf_ret_AE
preserve
	use "$general/output/graph_fyf_AE.dta",  clear	
	* 201108 is r5 -> color RED
	tw line r1 r5 date if date>ym(2011,6) & date<=ym(2013,12), yline(0, lc(gray))  ///
		lp(solid dash) lc(blue cranberry) ///
		ylabel(#6, labs(small)) ytitle("Monthly return") ///
		tlabel(2011m6(6)2013m12, labs(small)) ttitle("Month") ///
		tline(2011m08 2011m11 2012m04 2012m07 2012m09 2013m04 2013m08, lp("-####-####")) ///
		note("Note: Vertical dashed lines indicate FyF recommendations from fund A to E.") 
	graph export "$general\output\fyf_retAE.png", replace
	
	tw line r1 r5 date if date>ym(2011,6) & date<=ym(2013,12), yline(0, lc(gray))  ///
		lp(solid longdash) lc(blue cranberry) ///
		ylabel(#6, labs(small)) ytitle("Monthly return") ///
		tlabel(2011m6(6)2013m12, labs(small)) ttitle("Month") ///
		tline(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09, lp(solid) lc(blue)) ///
		note("Note: Vertical solid lines indicate FyF recommendations from fund E to A.") 
	graph export "$general\output\fyf_retEA.png", replace
		
	tw line diff date if date>ym(2011,6) & date<=ym(2013,12),  lc(blue)  yline(0, lc(gray)) ///
		ylabel(#6, labs(small)) ytitle("Return difference (A-E)")  ///
		tlabel(2011m6(6)2013m12, labs(small)) ttitle("Month") ///
		tline(2011m08 2011m12 2012m04 2012m07 2012m09 2013m04 2013m08, lp("-####-####")) ///
		tline(2011m10 2012m01 2012m06 2012m07 2013m01 2013m07 2013m09, lp(dot) lc(blue)) ///
		title("Returns and FyF recommendations") ///
		note("Note: Vertical dashed lines indicate FyF recommendations from fund A to E." ///
			 "Vertical dashed lines indicate FyF recommendations from fund E to A")
	graph export "$general\output\fyf_retAE_diff.png", replace
restore
end	

capture program drop graph_fyf_cret_daily
program              graph_fyf_cret_daily
	syntax, cutoff(string) delay_days(integer)
	preserve
	qui fyf_rec, delay(`delay_days')
	use "$general/raw/clean_sharevalue.dta", clear
	merge 1:1 date afp_all using "$general/raw/clean_fyf_rec_delay`delay_days'.dta", nogen assert(3)
	collapse (mean) r1 r5 ret_fyf, by(date)
	keep if date>=ym(2011,06)
	keep if date>=ym(`cutoff')
	cum_ret, varlist(ret_fyf r1 r5) datevar(date)
		la var cret_m_r1 "Fund A"
		la var cret_m_r5 "Fund E"
		la var cret_m_ret_fyf "FyF portfolio"
	* Create useful vars
		qui sum cret_ps_r1
		local crA : disp round(float(`r(max)'),0.001)*100
		qui sum cret_ps_r5
		local crE : disp round(float(`r(max)'),0.001)*100
		qui sum cret_ps_ret_fyf
		local crfyf : disp round(float(`r(max)'),0.001)*100
		qui sum cret_m_r1
		local minret `r(min)'
		qui sum date
		local mindate: disp %tm r(min)
		local mindate = trim("`mindate'")
		local maxdate: disp %tm r(max)
	tw line cret_m_r1 cret_m_r5  cret_m_ret_fyf date, lp(shortdash "-#.." solid) ///
			ylabel(-.1(.1).5, labs(small)) ytitle("Cumulative return")  ///
			tlabel(`mindate'(6)`maxdate', labs(small)) ttitle("Month")  ///
			legend(row(1)) ///
			note("Note: cumulative return for different portofolios, beginning to follow advice on `mindate'," ///
			     " and considering a delay of `delay_days' days to implement the switch.") ///
			ttext(`minret' `maxdate' ///
				"Cumulative returns""over the entire period" "Fund A: `crA'%"  ///
				"Fund E: `crE'%"  "FyF : `crfyf'%" ///
				, place(nw) box just(right) margin(l+1 t+1 b+1 r+2) width(33) )
	graph export "$general\output\fyf_cret_`mindate'_`delay_days'.png", replace
restore
end		

capture program drop graph_fyf_dailyES
program              graph_fyf_dailyES
preserve
	use "$general/output/fyf_eventstudy.dta", clear 
	gen rdiffyf = rfyf -(.5*rA + .5*rE)
	
	binscatter rdiffyf dif if event_window==1, ///
		line(connect) xlab(#15) discrete rd(-0.5)  /// 
		xtitle(Business days relative to recommendation)  ///
		ytitle("Advisor's portfolio return with respect to 0.5A+0.5E") ylab(#5) yscale(r(-.002 .002)) ///
		savegraph("$general/output/event_day_fyfdif.png") replace 
	binscatter rdiffyf dif if placebo==1, ///
		line(connect) xlab(#15) discrete rd(-0.5) /// 
		xtitle(Business days relative to placebo dates) ///
		ytitle("Advisor's portfolio return with respect to 0.5A+0.5E (Placebo)") ylab(#8) yscale(r(-.0015 .0015)) ///
		savegraph("$general/output/event_day_placebo.png") replace   
	binscatter rdiffyf dif if event_windowA==1 & n_rec<=5, ///
		line(connect) xlab(#15) discrete rd(-0.5)  /// 
		xtitle(Business days relative to recommendation) ///
		ytitle("Advisor's portfolio return with respect to 0.5A+0.5E") ylab(#5) yscale(r(-.004 .004)) ///
		savegraph("$general/output/event_day_15.png") replace  	
	binscatter rdiffyf dif if event_windowE==1 & n_rec>5, ///
		line(connect) xlab(#15) discrete rd(-0.5)  /// 
		xtitle(Business days relative to recommendation)  ///
		ytitle("Advisor's portfolio return with respect to 0.5A+0.5E") ylab(#5) yscale(r(-.004 .004)) ///
		savegraph("$general/output/event_day_628.png") replace  
end

capture program drop graph_fyf_ret_delay
program              graph_fyf_ret_delay
preserve
qui fyf_delays
use "$general/raw/clean_fyf_rec_delays.dta", clear
	collapse (mean) rA=r1 rE=r5 rfyf_0 rfyf_1 rfyf_2, by(date)
	keep if date>=ym(2011,06)
	cum_ret, varlist(rfyf_0 rfyf_1 rfyf_2 rA rE) datevar(date)
	gen cretAE =.5*cret_m_rA + .5*cret_m_rE
	* Create useful vars
		qui sum cret_ps_rfyf_0
		local cr0 : disp round(float(`r(max)'),0.001)*100
		qui sum cret_ps_rfyf_1
		local cr1 : disp round(float(`r(max)'),0.001)*100
		qui sum cret_ps_rfyf_2
		local cr2 : disp round(float(`r(max)'),0.001)*100
		qui sum cret_m_rfyf_2
		local minret `r(min)'
		qui sum cret_m_rA
		local minret2 `r(min)'
		qui sum date
		local mindate: disp %tm r(min)
		local mindate = trim("`mindate'")
		local maxdate: disp %tm r(max)
		la var cret_m_rfyf_0 "0 days of delay"
		la var cret_m_rfyf_1 "1 day of delay"
		la var cret_m_rfyf_2 "2 days of delay"
		la var cret_m_rA "Fund A"
		la var cret_m_rE "Fund E"
		la var cretAE "50% A + 50% E"
	tw line cret_m_rfyf_0 cret_m_rfyf_2 cretAE date, ///
		lc(green green green) lp(shortdash "-#.." solid)  ///
		ylabel(#6, labs(small)) ytitle("Cumulative return of FyF strategy")  ///
		tlabel(`mindate'(6)`maxdate', labs(small)) ttitle("Month") legend(row(1) symx(10)) ///
		note("Note: cumulative return for different number of delay days to implement the switch.") ///
		ttext(`minret' `maxdate' ///
			"Cumulative returns""over the entire period" "Delay 0 : `cr0'%"  ///
		    "Delay 2 : `cr2'%" ///
			, place(nw) box just(right) margin(l+1 t+1 b+1 r+2) width(33) )
	graph export "$general\output\fyf_cret_all_delay_days.png", replace
	tw line cret_m_rfyf_0 cret_m_rfyf_1 cret_m_rfyf_2 cret_m_rA cret_m_rE date, ////
		lc(green green green blue red) ///
		lp(shortdash "-#.." solid longdash longdash) ///
		ylabel(#6, labs(small)) ytitle("Cumulative return of FyF strategy")  ///
		tlabel(`mindate'(6)`maxdate', labs(small)) ttitle("Month") legend(row(2) col(3)) ///
		note("Note: cumulative return for different number of delay days to implement the switch.") ///
		ttext(`minret2' `maxdate' ///
			"Cumulative returns""over the entire period" "Delay 0 : `cr0'%"  ///
			"Delay 1 : `cr1'%"  "Delay 2 : `cr2'%" ///
			, place(nw) box just(right) margin(l+1 t+1 b+1 r+2) width(33) )
	graph export "$general\output\fyf_cret_all_delay_days_AE.png", replace
restore
end
	
main
