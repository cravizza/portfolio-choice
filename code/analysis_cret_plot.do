clear all
global data "../../../Data/SP"
global general "../"
global wb = "graphregion(color(white)) bgcolor(white)"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "$general/log/analysis_cret_plot`date'.log", replace
	graph_follower_cret
	
	log close
end
	
capture program drop graph_follower_cret
program              graph_follower_cret
	preserve
	use "$general/output/derived_hpa.dta", clear
		keep if date>=ym(2011,06)
		assert N_sw_fund!=.
		* Create groups of followers/non-followers/non_switchers
		bys ID: gen fyf_non_follower = (N_sw_fund>0 & fyf_follower==0)
		bys ID: gen fyf_non_switcher = (N_sw_fund==0)
		assert fyf_follower==0     if fyf_non_follower==1|fyf_non_switcher==1
		assert fyf_non_follower==0 if fyf_follower==1    |fyf_non_switcher==1
		assert fyf_non_switcher==0 if fyf_follower==1    |fyf_non_follower==1
		table fyf_non_follower fyf_follower fyf_non_switcher

		* Create groups of followers by income
		bys ID: egen fyf_TIy_a50 = max(TIy_a50)          if fyf_follower==1
		bys ID: gen fyf_follower_rich = (fyf_TIy_a50==1) if fyf_follower==1
		bys ID: gen fyf_follower_not  = (fyf_TIy_a50==0) if fyf_follower==1
		table fyf_follower_rich fyf_follower_not

		bys ID: egen mindate = min(date)
		gen mindatedummy = (mindate==ym(2011,6))
		tab mindatedummy
		drop if mindatedummy==0
		di "-- Cumulative return monthly, after the first recommendation"
		foreach group in follower non_follower non_switcher follower_rich follower_not {
			foreach sw_t in f l {
				bys ID (date): gen crp_`group'_`sw_t'=(1+rp_`sw_t') if date==ym(2011,06) & fyf_`group'==1
				replace crp_`group'_`sw_t'=(1+rp_`sw_t')*l.crp_`group'_`sw_t' ///
					if mi(crp_`group'_`sw_t') & fyf_`group'==1
				replace crp_`group'_`sw_t'=crp_`group'_`sw_t'-1 if fyf_`group'==1
			}
		}
		
		bys ID (date): gen crp_def=(1+rpdef) if date==ym(2011,06) & fyf_follower==1
		replace crp_def=(1+rpdef)*l.crp_def  if mi(crp_def) & fyf_follower==1
		replace crp_def = crp_def-1          if fyf_follower==1
		
		collapse (mean) crp_*  (count) ID, by(date)
		keep if ID>=1000
		insobs 1
		replace date = ym(2011,5) if date==.
		foreach var of varlist _all {
			replace   `var' = 0 if `var'==.
		}
		sort date
		* Graphs of cret
		tw line crp_follower_l crp_non_follower_l crp_non_switcher_l date, ${wb} ///
			ylabel(#5, labs(small)) ytitle("Cumulative return")  lp(shortdash "-#.." solid) ///
			tlabel(#6, labs(small)) ttitle("Months") /// //title("Cumulative return after first recommendation") ///
			legend(label(1 "Followers") label(2 "Non-followers") label(3 "Non-switchers") row(1))
		graph export "$general\output\cret_advice.png", replace
		
		tw line crp_follower_f crp_follower_l crp_def  date, ${wb} ///
			ylabel(#5, labs(small)) ytitle("Cumulative return")  lp(shortdash "-#.." solid) ///
			tlabel(#6, labs(small)) ttitle("Months") /// //title("Cumulative return after first recommendation") ///
			legend(label(1 "First day") label(2 "Last day") label(3 "Default") row(1))
		graph export "$general\output\cret_advice_rob.png", replace
		
		tw line crp_follower_rich_l crp_follower_not_l crp_def date, ${wb} ///
			ylabel(#5, labs(small)) ytitle("Cumulative return")  lp(shortdash "-#.." solid) ///
			tlabel(#6, labs(small)) ttitle("Months") /// //title("Cumulative return after first recommendation") ///
			legend(label(1 "High income") label(2 "Low income") label(3 "Default") row(1))
		graph export "$general\output\cret_advice_TI.png", replace
		* t-test
		ttest cret_avg_follower==cret_avgl_follower, unp
		scalar_txt, number(r(p))  filename(pv2s_foll_rob) decimal(2)
		
		ttest cret_avg_non_follower==cret_avgl_non_follower, unp
		ttest cret_avg_follower==cret_avg_non_follower, unp
		ttest cret_avg_follower==cret_avg_non_switcher, unp
		ttest cret_avg_non_follower==cret_avg_non_switcher, unp
		ttest cret_avg_follower_rich==cret_avg_follower_not	, unp
		scalar_txt, number(r(p))  filename(pv2s_foll_ti) decimal(2)

	restore
end
