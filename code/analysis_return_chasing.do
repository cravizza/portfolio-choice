** Portfolio Choice
*** RETURN CHASING
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/analysis_return_chasing`date'.log", replace
	use "../output/derived_ES.dta", clear
	tsset ID_sw dif_f
	scalar_return_chasing
	graph_return_chasing,		var(rp_fr)  sw_t(l)
	graph_return_chasing,		var(rp_dif) sw_t(l)
	graph_return_chasing_box,	var(rp_dif) sw_t(l)
	graph_return_chasing_box,	var(rp_dif) sw_t(l) file(_follower) if_opt(& fyf_follower==1)
	by ID_sw: egen _sw_frE = max(sw_f_1from5) if event_l==1
	by ID_sw: egen _sw_toA = max(sw_f_1to1)   if event_l==1
	graph_return_chasing_box,	var(rp_dif) sw_t(l) file(_toA)      if_opt(& (_sw_frE==1 & _sw_toA==1))
	drop _sw_*
	graph_return_chasing_demo,	var(rp_dif)	sw_t(l)
	switch_to_best_option, past_months(3)	sw_t(l)
	table_statistic, depvar(stat_dif_l)
	table_statistic_subs, depvar(stat_dif_l)
	table_statistic_agg
	log close
end

capture program drop scalar_return_chasing
program              scalar_return_chasing
	qui sum rp_dif if dif_l==1
	scalar_txt, number(r(mean)*100) filename(rp_dif_1) decimal(2)
	sum rp_dif if dif_l==4
	scalar_txt, number(r(mean)*100) filename(rp_dif_4) decimal(2)
end
	
capture program drop graph_return_chasing_box
program              graph_return_chasing_box
	syntax, var(string) sw_t(string) [file(string) option(string) if_opt(string)]
	preserve
	tsset ID_sw dif_`sw_t'
	local subsample event_`sw_t'==1  `if_opt'	//sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	local obs `r(N)'
	qui reg stat_dif_`sw_t'     if `subsample'               , vce(cluster date)
	local stat : disp %5.4f _b[_cons]
	local sd : disp %5.4f _se[_cons]
	scalar_txt, number(`stat') filename(stat_`var'`file') decimal(4)
	binscatter `var' dif_`sw_t' if `subsample' `if_opt', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.005 .02))  ///
		ttext(.02 12.5 ///
			"Statistic: return difference of""the past 3 months with respect""to past trend: `stat' (`sd')" ///
			 , place(sw) box just(right) margin(l+1 t+1 b+1 r+2) width(50) )	 `option' ///
		savegraph("$general/output/return_chasing_all_`sw_t'`file'.png") replace  
	restore
end

capture program drop graph_return_chasing
program              graph_return_chasing
	syntax, var(string) sw_t(string)
	preserve
	local subsample event_`sw_t'==1 	//sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	binscatter `var' dif_`sw_t' if `subsample', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.005 .015)) ///
		legend(row(1) symxsize(6))	///		 
		savegraph("$general/output/return_chasing_`var'_`sw_t'.png") replace 
	restore
end

capture program drop graph_return_chasing_demo
program              graph_return_chasing_demo
	syntax, var(string) sw_t(string)
	preserve
	rename age_ev_def Age
	rename gender Gender
	rename TI_ev_50 Percentile
	local subsample event_`sw_t'==1 	
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	foreach demo in Age Gender Percentile {
	binscatter `var' dif_`sw_t' if `subsample', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.005 .015)) ///
		legend(row(1) symxsize(6))  by(`demo') ///		 
		savegraph("$general/output/return_chasing_`sw_t'_`demo'.png") replace 
	}
	restore
end

capture program drop switch_to_best_option
program              switch_to_best_option
	syntax, past_months(integer) sw_t(string)
	preserve
	local p=`past_months' //`past_months' //avg return of past 3 months wrt past trend
	forvalues f = 1/5 {
	 bys ID_sw (date): egen ra_Tdif_f`f' =  mean(r`f' - rp_fr) if dif_`sw_t'<-`p' & event_`sw_t'==1
	 bys ID_sw (date): egen ra_tdif_f`f' =  mean(r`f' - rp_fr) if inrange(dif_`sw_t',-`p',-1) & event_`sw_t'==1
	 gen stat_dif_f`f' = (ra_tdif_f`f'[_n-1]-ra_Tdif_f`f'[_n-`p'-1])*100 if sw_ev_`sw_t'==1 & event_`sw_t'==1
	}
	gen stat_dif_max = max(stat_dif_f1,stat_dif_f2,stat_dif_f3,stat_dif_f4,stat_dif_f5)
	gen sw_better = (round(stat_dif_max,.0001)<=round(stat_dif_`sw_t',.0001)) if sw_ev_`sw_t'==1 & !mi(stat_dif_`sw_t')
	sum sw_better 
	scalar_txt, number(r(mean)*100) filename(sw_better) decimal(1)
	restore
end

capture program drop table_statistic
program              table_statistic
syntax, depvar(string)
	preserve
	egen tag = group(date)
	* Subsample correlations & Testing difference
	foreach var of varlist gender age_ev_def TI_ev_50 {
		local l_`var': variable label `var'
		qui levelsof `var', local(levels)   //di `levels'
		local words: word count `levels' //di `words'
		forvalues w = 1/`words' {
			local j: word `w' of `levels'
			qui reg `depvar' if `var'==`j' , vce(cluster tag)
			local b_`var'_`j'  =  _b[_cons]
			local s_`var'_`j' =  _se[_cons]
			local l_`var'_`j': label (`var') `j'
			gen M_`depvar'_`var'_`w' = `depvar' if `var'==`j'
		}
		forvalues w = 2/`words' {
			ttest  M_`depvar'_`var'_1 ==  M_`depvar'_`var'_`w', unpaired
			local j: word `w' of `levels'
			local p_`var'_`j' : disp %5.4f r(p)
		}
	}
	qui reg `depvar' , vce(cluster tag)
	local b_um = _b[_cons]
	local s_um = _se[_cons]
	* Create table
	file open myfile using "$general\output\table_`depvar'.txt", write replace
	file write myfile "\begin{threeparttable}" ///
					_n "\begin{tabular}{l|cc|c} \hline\hline"  ///
					_n " & Coeff. & SE & Diff.p-value \\ "  ///
					_n "All obs. & (1) & (2) & (3) \\ \hline"
	foreach var of varlist gender age_ev_def TI_ev_50 {
		file write myfile _n "`l_`var'' & & &  \\"
		qui levelsof `var', local(levels)  //di `levels'
		local words: word count `levels' //di `words'
		forvalues w = 1/`words' {
			local j: word `w' of `levels'
			file write myfile _n  "\hspace{0.3cm} `l_`var'_`j'' &" ///
								%5.4f (`b_`var'_`j'') "  & (" ///
								%5.4f (`s_`var'_`j'') ") &  " ///
								" `p_`var'_`j'' "        "  \\ "
		}
	}
	file write myfile _n " \hline Mean & " %5.4f (`b_um') " & " %5.4f (`s_um') " \\" ///
					  _n "\hline\hline" _n "\end{tabular}"
	file close myfile
	scalar_txt, number(`b_TI_ev_50_1') filename(`depvar'_sh_ti1) decimal(2)
	scalar_txt, number(`b_gender_1')   filename(`depvar'_sh_men) decimal(2)
	restore
end

capture program drop table_statistic_subs
program              table_statistic_subs
syntax, depvar(string)
	preserve
	label var TI_ev_50 "Income perc."
	*SE analysis
	gen n_month = month(dofm(date))
	gen subs = .
	forvalues s = 1/3 {
		local m1 = `s'
		local m2 = `m1'+3
		local m3 = `m2'+3
		local m4 = `m3'+3
		replace subs =`s' if (n_month==`m1'|n_month==`m2'|n_month==`m3'|n_month==`m4')
	}
	assert subs==1 if sw_ev_f==1 & (n_month==1|n_month==4|n_month==7|n_month==10)
	forvalues m1 = 1/3 {
		tab n_month if subs==`m1' & sw_ev_l==1
	}
	* Regressions
	forvalues s = 1/3 {
		foreach var of varlist gender TI_ev_50 {
			local l_`var': variable label `var'
			clttest `depvar' if subs==`s', cluster(date) by(`var')
			local p_`var'_1_`s' : disp %5.4f r(p)
			forvalues j = 1/2 {
				local x = `j'-1
				local b_`var'_`x'_`s' = r(mu_`j')
				local s_`var'_`x'_`s' = r(se_`j')
				local l_`var'_`x': label (`var') `x'
			}
		}
		local var age_ev_def
		local l_`var': variable label `var'
		forvalues age_num = 3/4 {
			clttest `depvar' if subs==`s' & (`var'==2|`var'==`age_num'), cluster(date) by(`var')
			local p_`var'_`age_num'_`s' : disp %5.4f r(p)
			local j = 1
			foreach x of numlist 2 `age_num' {
				local b_`var'_`x'_`s' = r(mu_`j')
				local s_`var'_`x'_`s' = r(se_`j')
				local l_`var'_`x': label (`var') `x'
				local j = `j' + 1
			}
		}
		qui reg `depvar' if subs==`s' , vce(cluster date)
		local b_um_`s'  : disp %5.4f _b[_cons]
		local s_um_`s'  : disp %5.4f _se[_cons]
	}
	* Table
	file open myfile using "$general\output\table_`depvar'_subs.txt", write replace
	file write myfile "\begin{threeparttable}" ///
					_n "\begin{tabular}{@{}l|cc|c|cc|c|cc|c@{}} \hline\hline"  ///
					_n "Subsamples & \multicolumn{3}{c|}{Jan-Apr-Jul-Oct} &  \multicolumn{3}{c|}{Feb-May-Aug-Nov} &  \multicolumn{3}{c}{Mar-Jun-Sep-Dec} \\ \hline " ///
					_n " &        &    & Diff.   &        &    & Diff.   &        &    & Diff.   \\ "  ///
					_n "Demographic & Coeff. & SE & p-value & Coeff. & SE & p-value & Coeff. & SE & p-value \\ "  ///
					_n "groups & (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) & (9) \\ \hline"
	foreach var of varlist gender age_ev_def TI_ev_50 {
		file write myfile _n "`l_`var'' & & & & & & & & &   \\"
		qui levelsof `var', local(levels)  //di `levels'
		local words: word count `levels' //di `words'
		forvalues w = 1/`words' {
			local j: word `w' of `levels'
			file write myfile _n  "\hspace{0.1cm} `l_`var'_`j'' & " ///
								%5.4f (`b_`var'_`j'_1') " & (" %5.4f (`s_`var'_`j'_1') ") & `p_`var'_`j'_1' & " ///
								%5.4f (`b_`var'_`j'_2') " & (" %5.4f (`s_`var'_`j'_2') ") & `p_`var'_`j'_2' & "  ///
								%5.4f (`b_`var'_`j'_3') " & (" %5.4f (`s_`var'_`j'_3') ") & `p_`var'_`j'_3' \\ "
		}
	}
	file write myfile _n " \hline Mean &  `b_um_1'  &  (`s_um_1')   & & " ///
										" `b_um_2'  &  (`s_um_2')   & & "  ///
										" `b_um_3'  &  (`s_um_3')  &  \\  " ///
					  _n "\hline\hline" _n "\end{tabular}"
	file close myfile
	restore
end

capture program drop table_statistic_agg
program              table_statistic_agg
	preserve
	gen sw_AE = (sw_f_1from1[_n-1]==1 & sw_f_1to5[_n-1]==1) if sw_ev_l==1
	gen sw_EA = (sw_f_1from5[_n-1]==1 & sw_f_1to1[_n-1]==1) if sw_ev_l==1
	gen sex = gender     if sw_ev_l==1
	gen ti  = TI_ev_50   if sw_ev_l==1
	gen ag  = age_ev_def if sw_ev_l==1
	gen r_toA = r1-r5
	gen r_toE = r5-r1
	collapse (sum) sw_AE sw_EA (mean) r_toA r_toE sex ti ag, by(date)
	tsset date
	isid date
	sort date 
	assert !mi(sw_AE) & !mi(sw_EA)
	gen net_toA = (sw_EA-sw_AE)/(sw_EA+sw_AE) 
	foreach w in toA toE {
		gen r_t_`w' = (r_`w'[_n-1]+r_`w'[_n-2]+r_`w'[_n-3])/3
		gen r_T_`w' = (r_`w'[_n-4]+r_`w'[_n-5]+r_`w'[_n-6]+r_`w'[_n-7]+r_`w'[_n-8]+r_`w'[_n-9]+r_`w'[_n-10]+r_`w'[_n-11]+r_`w'[_n-12])/9  
		gen stat_`w' = (r_t_`w'-r_T_`w')  
		sum stat_`w'
	}
	* Newey-West Regression			
	newey stat_toA net_toA , lag(3)
	local b_s : disp %5.4f  _b[net_toA]
	local s_s : disp %5.4f _se[net_toA]
	local p_s : disp %5.4f (2*ttail(e(df_r), abs(_b[net_toA]/_se[net_toA])))
	local b_c : disp %5.4f  _b[_cons]
	local s_c : disp %5.4f _se[_cons]
	local p_c : disp %5.4f (2*ttail(e(df_r), abs(_b[_cons]/_se[_cons])))
	local lag = e(lag)
	local b_net = _b[net_toA] +  _b[_cons]
	scalar_txt, number(`b_net') filename(stat_agg_b_net) decimal(3)
	scalar_txt, number(`b_s') filename(stat_agg_b_all) decimal(3)
	* Create table
	file open myfile using "$general\output\table_stat_agg_toA.txt", write replace
	file write myfile "\begin{threeparttable}" ///
					_n "\begin{tabular}{l|ccc} \hline\hline"         ///
					_n " Statistic       &        & Newey-West &         \\        " ///
					_n " from E to A     & Coeff. & Std. Error  & p-value \\        " ///
					_n "                 & (1)    & (2)        & (3)     \\ \hline " ///
					_n "Net flow from E to A & `b_s'  & (`s_s')    & `p_s'   \\        " ///
					_n "Constant         & `b_c'  & (`s_c')    & `p_c'   \\        " ///
					_n "\hline\hline" _n "\end{tabular}" 
	file close myfile
	restore
end
		
main
