** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/analysis_event_study`date'.log", replace
	use "../output/derived_ES.dta", clear
	tsset ID_sw dif
	//presentation output
	//graph_ES, var(r1) fund(1) direc(from) file(_r1)
	regression_stat
	regression_cret, var(cret_avg_from)
	regression_cret, var(cret_def)
	graph_all_ES,    var(ret_avg_from) file(_from)
	graph_all_ES,    var(ret_avg_dif)  file(_follower) if_opt(& sw_follower==1)
	graph_all_ES,    var(ret_avg_dif)
	graph_all_ES_by, var(ret_avg_dif) 
	//table_stat
	//table_cret
	//graphs_event_direc_by_fund, target_var(ret_avg_dif)
	//graphs_event_direc
	log close
end

capture program drop regression_vars
program              regression_vars
	gen age_ev_def_3 = (age_ev_def==3)
	gen age_ev_def_4 = (age_ev_def==4)
	gen TI_ev_q_2 = (TI_ev_quart==2)
	gen TI_ev_q_3 = (TI_ev_quart==3)
	gen TI_ev_q_4 = (TI_ev_quart==4)
	gen TIy_q_2   = (TIy_quart==2)
	gen TIy_q_3   = (TIy_quart==3)
	gen TIy_q_4   = (TIy_quart==4)
end

capture program drop regression_stat
program              regression_stat
	preserve
	regression_vars
	qui reg stat_dif                     , vce(cluster date)
	est store full
		esttab full using "$general/output/reg_stat.tex", se(%3.2f) wide b(2) booktabs ///
		eqlabels(none) alignment(lc) nonumbers mtitles("$\Delta\bar{r}$") label nonotes replace ///
		width(3cm) compress nogaps noobs ///
		varlabels(_cons " ") 
		
	qui reg stat_dif gender              , vce(cluster date)
	est store gender
		esttab gender using "$general/output/reg_stat_gender.tex", se(%3.2f) wide b(2) booktabs ///
		eqlabels(none) alignment(lc) nonumbers mtitles("Gender") label nonotes replace ///
		width(.5\hsize) compress nogaps noobs ///
		varlabels(_cons Female\hspace{7ex} gender diff.Male)  order(_cons gender)
		
	qui reg stat_dif age_ev_def_*        , vce(cluster date)
	est store ages
		esttab ages using "$general/output/reg_stat_age.tex", se(%3.2f) wide b(2) booktabs ///
		eqlabels(none) alignment(lc) nonumbers mtitles("Age groups") label nonotes replace ///
		width(.5\hsize) compress nogaps noobs ///
		varlabels(_cons Young age_ev_def_3 "diff.Middle age" age_ev_def_4 diff.Old) ///
		order(_cons age_ev_def_3 age_ev_def_4)
		
	qui reg stat_dif TI_ev_q_*       , vce(cluster date)
	est store income
		esttab income using "$general/output/reg_stat_TI.tex", se(%3.2f) wide b(2) booktabs ///
		eqlabels(none) alignment(lc) nonumbers mtitles("Income quartile") label nonotes replace ///
		width(.5\hsize) compress nogaps noobs ///
		varlabels(_cons "1st quartile"      TI_ev_q_2 "diff.2nd quartile" ///
		      TI_ev_q_3 "diff.3rd quartile" TI_ev_q_4 "diff.4th quartile") ///
		order(_cons TI_ev_q_2 TI_ev_q_3 TI_ev_q_4) ///
		addnotes("Clustered standard errors in parenthesis" ///
		"* for p$<$.05, ** for p$<$.01,and *** for p$<$.001")
		
	qui reg stat_dif TIy_q_*       , vce(cluster date)
	est store incomey
		esttab incomey using "$general/output/reg_stat_TIy.tex", se(%3.2f) wide b(2) booktabs ///
		eqlabels(none) alignment(lc) nonumbers mtitles("Income quartile") label nonotes replace ///
		width(.5\hsize) compress nogaps noobs ///
		varlabels(_cons "1st quartile"      TIy_q_2 "diff.2nd quartile" ///
		        TIy_q_3 "diff.3rd quartile" TIy_q_4 "diff.4th quartile") ///
		order(_cons TIy_q_2 TIy_q_3 TIy_q_4) ///
		addnotes("Clustered standard errors in parenthesis" ///
		"* for p$<$.05, ** for p$<$.01,and *** for p$<$.001")
	
	est drop _all
	restore
end

capture program drop regression_cret
program              regression_cret
	syntax, var(string)
	preserve
	regression_vars
	
	gen     temp_cret2m  = (cret_avg_to2m   - `var'2m )*100 if dif_max==12
	gen     temp_cret12m = (cret_avg_to12m  - `var'12m)*100 if dif_max==12
	qui capture regression_vars
	
	qui reg temp_cret2m                      , vce(cluster date)
	est store full1
	qui reg temp_cret12m                    , vce(cluster date)
	est store full2
		esttab full1 full2 using "$general/output/reg_`var'.tex", se(%9.2f) wide b(2) booktabs ///
		eqlabels(none) alignment(lc) nonumbers mtitles("$\Delta \bar{r}$") label replace ///
		width(.65\hsize) compress nogaps noobs nonotes ///
		varlabels(_cons "Full sample") 
	
	qui reg temp_cret2m  gender              , vce(cluster date)
	est store gender1
	qui reg temp_cret12m gender              , vce(cluster date)
	est store gender2
		esttab gender1 gender2 using "$general/output/reg_`var'_gender.tex", se(%9.2f) wide b(2) ///
		eqlabels(none) alignment(lc) nonumbers mtitles("2 months" "12 months") label replace ///
		width(.65\hsize) compress nogaps noobs nonotes booktabs ///
		varlabels(_cons Female\hspace{7ex} gender diff.Male)  order(_cons gender)
	
	qui reg temp_cret2m  age_ev_def_*        , vce(cluster date)
	est store ages1
	qui reg temp_cret12m age_ev_def_*        , vce(cluster date)
	est store ages2
		esttab ages1 ages2 using "$general/output/reg_`var'_age.tex", se(%9.2f) wide b(2) ///
		eqlabels(none) alignment(lc) nonumbers mtitles("2 months" "12 months") label replace ///
		width(.65\hsize) compress nogaps noobs nonotes booktabs ///
		varlabels(_cons Young age_ev_def_3 "diff.Middle age" age_ev_def_4 diff.Old) ///
		order(_cons age_ev_def_3 age_ev_def_4)
	
	qui reg temp_cret2m  TI_ev_q_*       , vce(cluster date)
	est store income1
	qui reg temp_cret12m TI_ev_q_*       , vce(cluster date)
	est store income2
		esttab income1 income2 using "$general/output/reg_`var'_TI.tex", se(%9.2f) wide b(2) ///
		eqlabels(none) alignment(lc) nonumbers mtitles("2 months" "12 months") label replace ///
		width(.65\hsize) compress nogaps noobs nonotes booktabs ///
		addnotes("Clustered standard errors in parenthesis" ///
		"* for p$<$.05, ** for p$<$.01,and *** for p$<$.001") ///
		varlabels(_cons "1st quartile"      TI_ev_q_2 "diff.2nd quartile" ///
		      TI_ev_q_3 "diff.3rd quartile" TI_ev_q_4 "diff.4th quartile") ///
		order(_cons TI_ev_q_2 TI_ev_q_3 TI_ev_q_4)
		
	qui reg temp_cret2m  TIy_q_*       , vce(cluster date)
	est store incomy1
	qui reg temp_cret12m TIy_q_*       , vce(cluster date)
	est store incomy2
		esttab incomy1 incomy2 using "$general/output/reg_`var'_TIy.tex", se(%9.2f) wide b(2) ///
		eqlabels(none) alignment(lc) nonumbers mtitles("2 months" "12 months") label replace ///
		width(.65\hsize) compress nogaps noobs nonotes booktabs ///
		addnotes("Clustered standard errors in parenthesis" ///
		"* for p$<$.05, ** for p$<$.01,and *** for p$<$.001") ///
		varlabels(_cons "1st quartile"      TIy_q_2 "diff.2nd quartile" ///
		        TIy_q_3 "diff.3rd quartile" TIy_q_4 "diff.4th quartile") ///
		order(_cons TIy_q_2 TIy_q_3 TIy_q_4) ///
		
	est drop _all
	drop temp_*
	restore
end	

capture program drop graph_all_ES
program              graph_all_ES
	syntax, var(string) [file(string) option(string) if_opt(string)]
	
	local subsample event_window==1  `if_opt'	//sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	local obs `r(N)'
	
	binscatter `var' dif if `subsample' `if_opt', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.005 .015)) ///
		ti("Event: all switches (N=`obs')") `option' ///		 
		savegraph("$general/output/event_all`file'.png") replace  
end

capture program drop graph_all_ES_by
program              graph_all_ES_by
	syntax, var(string) [file(string) option(string) if_opt(string)]
	preserve
	rename gender Gender
	//rename TI_ev_50 Percentile
	rename TI_ev_quart Quartile
	rename age_ev_def Age
	local subsample event_window==1 	//sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	local obs `r(N)'
	//foreach demo in Gender Percentile Age_group {
	foreach demo in Gender Quartile Age {
	binscatter `var' dif if `subsample' `if_opt', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.005 .015)) ///
		legend(row(1) symxsize(6)) ///
		ti("Event: all switches, by `demo' (N=`obs')") by(`demo') ///		 
		savegraph("$general/output/event_all_`demo'.png") replace 
	}
	restore
	preserve
	rename TIy_quart Quartile
	local subsample event_window==1 	//sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	local obs `r(N)'
	binscatter `var' dif if `subsample' , xtitle(Months) ytitle("`mylabel'") ///
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.005 .015)) ///
		legend(row(1) symxsize(6)) ///
		ti("Event: all switches, by Quartile (N=`obs')") by(Quartile) ///		 
		savegraph("$general/output/event_all_Quartiley.png") replace 
	restore
end
	
capture program drop graphs_event_direc_by_fund
program              graphs_event_direc_by_fund
	syntax, target_var(string)
	* Options for target_var: r`fund',ret_avg_`direc', ret_avg_dif
	preserve
	rename gender Gender
	rename TI_ev_50 Percentile
	rename age_ev_def Age_group
	foreach way in from to {
	 forvalues f=1/5 {
	 graph_ES,    var(`target_var') direc(`way') fund(`f') 
	 graph_ES_by, var(`target_var') direc(`way') fund(`f') file(TI) option(by(Percentile) m(O T))
	 graph_ES_by, var(`target_var') direc(`way') fund(`f') file(gender) option(by(Gender) m(O T))
	 graph_ES_by, var(`target_var') direc(`way') fund(`f') file(age) option(by(Age_group) m(O T S))
	 }
	}
	restore
end	

capture program drop graph_ES
program              graph_ES
	syntax, var(string) fund(numlist) direc(string) [file(string) option(string) if_opt(string)]
	
	local subsample event_window==1 & sw_ev_`direc'`fund'==1 //sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	local obs `r(N)'
	
	binscatter `var' dif if `subsample' `if_opt', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.01 .03)) ///
		ti("Event: switch `direc' fund `fund' (N=`obs')") `option' ///
		savegraph("$general/output/event_`direc'_f`fund'`file'.png") replace  
end

capture program drop graph_ES_by
program              graph_ES_by
	syntax, var(string) fund(numlist) direc(string) [file(string) option(string) if_opt(string)]
	
	local subsample event_window==1 & sw_ev_`direc'`fund'==1	//sw_ev_`direc'==`fund'
	local mylabel : variable label `var'
	qui sum ID_sw if `subsample' 
	local obs `r(N)'
	
	binscatter `var' dif if `subsample' `if_opt', xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.01 .03)) ///
		ti("Event: switch `direc' fund `fund', by `file' (N=`obs')") `option' ///		 
		savegraph("$general/output/event_`direc'_f`fund'_`file'.png") replace  
end

capture program drop graphs_event_direc
program              graphs_event_direc
	preserve
	  keep if event_window==1
	  expand 5, gen(tag)
	  sort ID_sw date tag
	  replace tag = 2 if tag[_n-1]==1 & tag[_n-2]==0
	  replace tag = 3 if tag[_n-1]==2 & tag[_n-2]==1
	  replace tag = 4 if tag[_n-1]==3 & tag[_n-2]==2
	  assert  tag==4 & tag[_n+1]==0 if date<date[_n+1] & ID_sw==ID_sw[_n+1]
	  
	  foreach direc in to from {
		gen      `direc' = .
	 	forvalues f=1/5 {
		 replace `direc' = `f' if tag==`f'-1 & sw_ev_`direc'`f'==1 
		}
		local mylabel : variable label ret_avg_dif
		qui sum ID_sw 
		local obs=`r(N)'/5
		
		la var `direc'  "`direc'"
		la def `direc' 1 "Fund 1" 2 "Fund 2" 3 "Fund 3" 4 "Fund 4" 5 "Fund 5"
		la val `direc' `direc'
		
		binscatter ret_avg_dif dif, xtitle(Months) ytitle("`mylabel'") /// 
		line(connect) xlab(#13) ylab(#9) discrete rd(-0.5) yscale(r(-.01 .025)) ///
		ti("Event: switch `direc' all funds (N=`obs')") by(`direc') ///		 
		savegraph("$general/output/event_`direc'.png") replace
	  }
	restore
end		

capture program drop table_stat
program              table_stat
	preserve
	  keep if sw_event==1
	  gen wt = 1
	  svyset [pw=wt]  // dropc(4) twidth(9) layout(row) ptotal(all)
		
	  foreach direc in to from {
		tabout gender age_ev_def TI_ev_quart s_`direc' using "$general/output/stat_`direc'.tex", rep ///
		style(tex) font(bold) clab(_ _) h3(nil) c(mean stat_`direc' se) sum svy npos(lab) ///
		fn(Note: sample mean, and its standard error in parenthesis.) ///
		title(Statistic: change in returns before switch) ///
		format(2p 2) ptotal(none) show(prepost) dropc(6 7) twidth(9.5)
	  }
	  replace s_dif = 0 if dif_min<-2
		tabout gender age_ev_def TI_ev_quart s_dif using "$general/output/stat_dif.tex", rep ///
		style(tex) font(bold) clab(_ _) h3(nil) c(mean stat_dif     se) sum svy npos(lab) ///
		fn(Note: sample mean, and its standard error in parenthesis.) ///
		title(Statistic: change in returns before switch) ///
		format(2p 2) ptotal(none) show(prepost) dropc(4 5) twidth(8)  h2(nil)
		
	  svyset, clear
	restore
end

capture program drop table_cret
program              table_cret
	preserve
	  keep if sw_event==1
	  gen wt = 1
	  svyset [pw=wt]  // dropc(4) twidth(9) layout(row) ptotal(all)
	  expand 2, gen(tag)
	  gen     temp_cret_from = cret_avg_to2m  - cret_avg_from2m  if tag==0 & dif_max==12
	  replace temp_cret_from = cret_avg_to12m - cret_avg_from12m if tag==1 & dif_max==12
	  gen     temp_cret_def  = cret_avg_to2m  - cret_def2m       if tag==0 & dif_max==12
	  replace temp_cret_def  = cret_avg_to12m - cret_def12m      if tag==1 & dif_max==12
	  
	  la var tag       "Cumulative return difference"
	  la def tag       0 "2 months" 1 "12 months"
	  la val tag tag
	  
		tabout gender age_ev_def TI_ev_quart tag using "$general/output/cret_from_2_12.tex", rep ///
		style(tex) font(bold) clab(_ _) h3(nil) c(mean temp_cret_from se) sum svy ///
		fn(Note: sample mean, and its standard error in parenthesis.) ///
		title(Destination vs Origin allocation, after switch) ///
		format(4) ptotal(none) show(prepost) dropc(6 7) twidth(9.5) 
	
		tabout gender age_ev_def TI_ev_quart tag using "$general/output/cret_def_2_12.tex", rep ///
		style(tex) font(bold) clab(_ _) h3(nil) c(mean temp_cret_def se) sum svy ///
		fn(Note: sample mean, and its standard error in parenthesis.) ///
		title(Destination vs Default allocation, after switch) ///
		format(4) ptotal(none) show(prepost) dropc(6 7) twidth(9.5)
	restore
end

main

/*
*binscatter ret_avg_dif dif if event_window==1 & sw_ev_from1==1, xtitle(Months) ytitle("AAA") line(connect) xlab(#13) ylab(#10) discrete rd(-0.5) yscale(r(-.01 .03)) by(gender)

program tables
	syntax, direction(string) 
	table fund_`direction' gender	 ,  c(mean r_`direction' count r_`direction') col format(%9.4f)
	table fund_`direction' TIp50below,  c(mean r_`direction' count r_`direction') col format(%9.4f)
	table fund_`direction' age_def   ,  c(mean r_`direction' count r_`direction') col format(%9.4f)
end
table  gender tag,      c(mean temp_cret sem temp_cret) col format(%9.4f)
table  gender s_dif if tag==0 & dif_max==12,      c(mean temp_cret sem temp_cret) col format(%9.4f)
*table  gender s_dif ,      c(mean cret_avg_dif2m sem cret_avg_dif2m) col format(%9.4f)
foreach way in to from {graph_ES,var(ret_avg_`way') direc(`way') fund(1)}
graph_ES, var(ret_avg_dif) direc(from) fund(1)

local mylabel : variable label ret_avg_dif //var'
binscatter ret_avg_dif dif if event_window==1 & sw_event_to==5, line(connect)  ///
by(age_def) m(O T S) rd(-0.5) yscale(r(-.01 .03)) ylab(#10) discrete ytitle("`mylabel'")	
