*** Portfolio Choice
*** ANALYSIS - Cumulative returns
clear all
global data "../../../Data/SP"
global general "../"
global wb = "graphregion(color(white)) bgcolor(white)"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "$general/log/analysis_cret_2-12`date'.log", replace
	use "$general/output/derived_ES.dta", clear
	table_cret,		varB(crdef) sw_t(l) title(Switchers) file(all) 
	table_cret,		varB(cr_fr) sw_t(l) title(Switchers) file(all) 
	table_cret,  varB(crdef) sw_t(l) title(Followers) file(foll)  if_opt(& fyf_follower==1 & date>=ym(2011,7))
	table_cret,  varB(cr_fr) sw_t(l) title(Followers) file(foll)  if_opt(& fyf_follower==1 & date>=ym(2011,7))
	graph_cret_12m
	log close
end	

capture program drop table_cret
program              table_cret
syntax, varB(string) title(string) sw_t(string) file(string) [if_opt(string)]
preserve
	//local varB crdef
	//local sw_t l
	gen     temp_cr2m  = (cr_to_`sw_t'_2m   - `varB'_`sw_t'_2m )*100 if dif_max==12
	qui sum temp_cr2m if !mi(ID) `if_opt'
	local   um_2m: disp %3.2f r(mean)
	gen     temp_cr12m = (cr_to_`sw_t'_12m  - `varB'_`sw_t'_12m)*100 if dif_max==12
	qui sum temp_cr12m if !mi(ID) `if_opt'
	local   um_12m: disp %3.2f r(mean)
	scalar_txt, number(`um_12m')   filename(cre_um_12m_`sw_t'_`varB'_`file') decimal(2)
	egen tag = group(date)
	* Subsample correlations & Testing difference	
	foreach depvar in 2m 12m { 
		foreach var of varlist gender TI_ev_50 {
			local l_`var': variable label `var'
			clttest temp_cr`depvar' if !mi(ID) `if_opt', cluster(tag) by(`var')
			local p_`depvar'_`var'_1 : disp %3.2f r(p)
			forvalues j = 1/2 {
				local x = `j'-1 
				local b_`depvar'_`var'_`x' = r(mu_`j')
				local s_`depvar'_`var'_`x' = r(se_`j')
				local l_`var'_`x': label (`var') `x'
			}
		}
		local var age_ev_def
		local l_`var': variable label `var'
		forvalues age_num = 3/4 {
			clttest temp_cr`depvar' if !mi(ID) & (`var'==2|`var'==`age_num') `if_opt', cluster(tag) by(`var')
			local p_`depvar'_`var'_`age_num' : disp %3.2f r(p)
			local j = 1
			foreach x of numlist 2 `age_num' {
				local b_`depvar'_`var'_`x' = r(mu_`j')
				local s_`depvar'_`var'_`x' = r(se_`j')
				local l_`var'_`x': label (`var') `x'
				local j = `j' + 1
			}
		}
		scalar_txt, number(`b_`depvar'_TI_ev_50_0') filename(`varB'_`sw_t'_`depvar'_`file'_til) decimal(1)
		scalar_txt, number(`b_`depvar'_TI_ev_50_1') filename(`varB'_`sw_t'_`depvar'_`file'_tih) decimal(1)
	}
	* Create table
	file open myfile using "$general\output\table_`varB'_`sw_t'_`file'.txt", write replace
	file write myfile "\begin{threeparttable}" ///
					_n "\begin{tabular}{l|cc|c|cc|c} \hline\hline"  ///
					_n "`title' & \multicolumn{3}{c|}{2 months} & \multicolumn{3}{c}{12 months} \\ \hline" ///
					_n " & Coeff. & SE & Diff.p-value & Coeff. & SE & Diff.p-value \\ "  ///
					_n " Subsamples & (1) & (2) & (3) & (4) & (5) & (6) \\ \hline"
	foreach var of varlist gender age_ev_def TI_ev_50 {
		file write myfile _n "`l_`var'' & & & & & & \\"
		qui levelsof `var', local(levels)  //di `levels'
		local words: word count `levels' //di `words'
		forvalues w = 1/`words' {
			local j: word `w' of `levels'
			file write myfile _n  "\hspace{0.3cm} `l_`var'_`j''   & " ///
								%3.2f (`b_2m_`var'_`j'') "  & (" ///
								%3.2f (`s_2m_`var'_`j'') ") & " ///
									"`p_2m_`var'_`j''" " & " ///
								%3.2f (`b_12m_`var'_`j'') " & (" ///
								%3.2f (`s_12m_`var'_`j'') ") & " ///
									"`p_12m_`var'_`j''" " \\"
		}
	}
	file write myfile _n " \hline Mean & `um_2m' & \multicolumn{2}{l|}{  } & `um_12m' & \multicolumn{2}{l}{  } \\" ///
					  _n "\hline\hline" _n "\end{tabular}" 
	file close myfile
	drop temp_*
	restore
end

capture program drop graph_cret_12m
program              graph_cret_12m
	preserve
		sort ID_sw date
		local sw_t l
		tsset ID_sw dif_`sw_t'
		local postsw "event_`sw_t'==1 & dif_`sw_t'>0 & dif_max==12"
		foreach w in def _to {
			bys ID_sw (dif_`sw_t'): gen cr`w'_`sw_t'_m = (1+rp`w')         if event_`sw_t'==1 & dif_`sw_t'>0 & dif_max==12 & dif_`sw_t'==1
			replace            cr`w'_`sw_t'_m = (1+rp`w')*l.cr`w'_`sw_t'_m if event_`sw_t'==1 & dif_`sw_t'>0 & dif_max==12 & mi(cr`w'_`sw_t'_m)
			replace            cr`w'_`sw_t'_m = cr`w'_`sw_t'_m-1           if event_`sw_t'==1 & dif_`sw_t'>0 & dif_max==12
		}
		
		gen cr_m  = (cr_to_`sw_t'_m   - crdef_`sw_t'_m )*100 if dif_max==12
		
		rename TI_ev_50 Percentile
		binscatter  cr_m dif_`sw_t' if dif_max==12, ${wb} line(connect)  by(Percentile) ///
			xtitle(Months) ytitle("Cumulative return of destination vs default") /// 
			xlab(#12) ylab(#6) discrete  yscale(r(0 -2.5)) ///		 
			savegraph("$general/output/crdef_0-12_income.png") replace  
			
		binscatter  cr_m dif_`sw_t' if dif_max==12 & fyf_follower==1, ${wb} line(connect)  by(Percentile) ///
			xtitle(Months) ytitle("Cumulative return of destination vs default") /// 
			xlab(#12) ylab(#6) discrete  yscale(r(0 -2.5)) ///		 
			savegraph("$general/output/crdef_0-12_income_fyf.png") replace  	
	restore
end

main
