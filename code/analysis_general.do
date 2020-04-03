*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
global wb = "graphregion(color(white)) bgcolor(white)"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "$general/log/analysis_general`date'.log", replace
	use "$general/output/derived_hpa.dta", clear
	tab sw_fund sw_fundfirm if sw_fund==1
	sum cav
	egen temp_tag=tag(ID)
	tab sw_fund cav if sw_fund==1
	bys ID: egen temp_cav = max(cav)
	sum temp_cav if temp_tag==1
	drop temp_*
	graph_switches
	graph_cret
	graph_money
	graph_reports
	graph_share_funds
	graphs_income
	table_default_alloc , title(0)
	table_number_switch
	table_direction_switch	
	log close
end

capture program drop graph_switches
program              graph_switches
	preserve
		qui sum id if (sw_fund==1 & sw_fund==1)
		local obs `r(N)'
		duplicates drop date sw_fund_freq, force
		sort date
		tw (line sw_fund_freq date) (line sw_firmfund_freq date), ${wb} ///
			ylabel(#4, labs(small)) ytitle("Number of switches over total accounts")  ///
			tlabel(2007m1(12)2013m12, labs(small)) ttitle("Month") /// *ymtick(0(0.005)0.015)
			legend(label(1 "All fund switches") label(2 "Fund switches when switching firm")) 
		graph export "$general\output\switches_all.png", replace
	restore
end

**OK

capture program drop graph_cret
program              graph_cret
	preserve
		keep if sw_post==1
		gen cr_m_p_l_0 = cr_m_p_l if TIy_a50==0
		gen cr_m_p_l_1 = cr_m_p_l if TIy_a50==1
		collapse (mean) cr_m_pdef cr_m_p_l* (count) ID, by(sw_months)
		keep if ID>=1000
		insobs 1
		replace sw_months = sw_months+1
		foreach var of varlist _all {
			replace   `var' = 0 if `var'==.
		}
		sort sw_months
		tw (line cr_m_pdef cr_m_p_l            sw_months), ${wb} ///
			ylabel(#5, labs(small)) ytitle("Cumulative return")  ///
			tlabel(0(12)75, labs(small)) ttitle("Months after first switch") ///
			legend(label(1 "Default") label(2 "Actual"))
		graph export "$general\output\cret_1st_switch.png", replace
		tw (line cr_m_p_l_0 cr_m_p_l_1            sw_months),  ///
			ylabel(#5, labs(small)) ytitle("Cumulative return")  ///
			tlabel(0(12)75, labs(small)) ttitle("Months after first switch") ///
			legend(label(1 "Low") label(2 "High"))
		graph export "$general\output\cret_1st_switch_gender.png", replace
	restore
end

capture program drop graph_money
program              graph_money
	preserve
		collapse (sum) f1 f2 f3 f4 f5, by(age_def)
		graph bar (mean) f1 f2 f3 f4 f5, ${wb} over(age_def)  perc ///
			ylabel(#4, labs(small)) ytitle("% of money in each fund")  legend(label(1 "Fund A") ///
			label(2 "Fund B") label(3 "Fund C") label(4 "Fund D") label(5 "Fund E") row(1) symxsize(6)  )
		graph export "$general\output\money.png", replace
	restore
end

capture program drop graph_reports
program              graph_reports
	preserve
	  qui sum id if (sw_fund==1 & sw_fund==1)
	  local obs `r(N)'
	  duplicates drop date sw_fund_freq, force
	  sort date
	  tw line sw_fund_freq date,  ///
		ylabel(#4, labs(small)) ytitle("Change of funds (% of total accounts)")  ///
		tlabel(2007m1(12)2013m12, labs(small)) ttitle("Month") /// *ymtick(0(0.005)0.015)
		tline(2007m03 2007m07 2007m11 2008m03 2008m07 2008m11 2009m03 2009m07 2009m11 2010m03 ///
		2010m07 2010m11 2011m03 2011m07 2011m11 2012m03 2012m07 2012m11 2013m03 2013m07 2013m11) ///
		title("Fund switches and Reports") ///
		note("Note: Vertical solid lines indicate reports receipt by individuals (obs=`obs').")
	  graph export "$general\output\reports.png", replace
	restore
end

capture program drop graph_share_funds
program              graph_share_funds
	preserve
		keep if default==0 & n_f==2 & sw_fund==1
		gen share_funds = sh_f1           if nmf1 
		forvalues f=2/5 {
			replace share_funds = sh_f`f' if nmf`f' & sh_f`f'<=share_funds
		}
		assert share_funds<=0.5 if share_funds!=.
		la var share_funds "Fund share"
		hist share_funds , freq width(0.005) ///
		title("Share of funds for individuals out of default ") ///
		note("Note: the bars show the smallest share of the two funds, at the time of the switch.")
		graph export "$general\output\share_funds.png", replace
	restore
end

capture program drop graphs_income
program              graphs_income
	preserve
		la var TI "Taxable income (CLP)"
		local TC    = 675
		local TC100 = 675*100
		
		qui sum TI, det
		local TIa  = round(`r(mean)'/`TC')
		local TIaY = round(`r(mean)'/`TC'*12)
		
		hist TI if TI<r(p99), freq width(`TC100') title("Taxable income frequency") ///
			addplot(pci 0 `r(mean)' 160000 `r(mean)') legend(off) ///
			note("Note: the graph shows the distribution of the TI up to the 99th percentile. Bins represent" ///
			"current 100 USD (`TC100' CLP). Red line shows the mean: `TIa' USD/month, `TIaY' USD/year.")
		graph export "$general\output\TI_all.png", replace
	
		bys ID: egen TI_mean= mean(TI)
		la var TI_mean "Average TI by individual (CLP)"
		duplicates drop ID, force
		
		qui sum TI_mean, det
		local TIa  = round(`r(mean)'/`TC')
		local TIaY = round(`r(mean)'/`TC'*12)
		
		hist TI_mean        , freq width(`TC100') title("Taxable income frequency") ///
			addplot(pci 0 `r(mean)' 4000 `r(mean)')   legend(off) ///
			note("Note: the graph shows distributionthe of the mean TI of each individual. Bins represent" ///
			"current 100 USD (`TC100' CLP). Red line shows the mean: `TIa' USD/month, `TIaY' USD/year.")
		graph export "$general\output\TI_mean.png", replace
	restore
end

capture program drop table_default_alloc
program              table_default_alloc
	syntax , title(integer)
	  if `title'==1 {
			local options title(Portfolio allocation) caplab(default_alloc)
	  }
	  else  
	  
	preserve	
		tabout default_rev n_f using "$general\output\default_alloc.tex", rep ///
		style(tex) font(bold) h3(nil) c(cell) h1(nil) `options' ///
		format(0p) ptotal(none) show(prepost) dropc(4) twidth(6.5) 
	restore
end

capture program drop table_number_switch
program              table_number_switch
	preserve
		duplicates drop ID, force
		replace N_sw_fund = 1 if N_sw_fund>1
		la var N_sw_fund "Number of fund switches"
		la def N_sw_fund 0 "None" 1 "At least once"
		la val N_sw_fund N_sw_fund
		tabout gender age_def TI_a50 N_sw_fund using "$general\output\number_switch.tex", rep ///
		style(tex) font(bold) h3(nil) c(row) h1(nil) ///
		format(0p 0p) ptotal(none) show(prepost) dropc(4) twidth(7.5) 
	restore
end

capture program drop table_direction_switch
program              table_direction_switch
	preserve
		keep if sw_fund==1
		keep ID date sw_f_*
		expand 5, gen(tag)
		sort ID date tag
		replace tag = 2 if tag[_n-1]==1 & tag[_n-2]==0
		replace tag = 3 if tag[_n-1]==2 & tag[_n-2]==1
		replace tag = 4 if tag[_n-1]==3 & tag[_n-2]==2
		assert  tag==4 & tag[_n+1]==0 if date<date[_n+1] & ID==ID[_n+1]
		gen to = .
		forvalues f=1/5 {
			replace to = `f' if tag==`f'-1 & sw_f_1to`f'==1
		}
		collapse (sum) res1=sw_f_1from1 (sum) res2=sw_f_1from2 (sum) res3=sw_f_1from3 ///
		         (sum) res4=sw_f_1from4 (sum) res5=sw_f_1from5, by(to)
		reshape long res, i(to) j(from)
		replace  res=. if to==from
		drop if to==.
		label var to "Destination fund"
		label var from "Origin fund"
		tabout from to using "$general\output\direction_switch.tex", rep ///
		style(tex) font(bold) h3(nil) c(mean res) sum ///
		format(0c) ptotal(none) show(prepost) dropc(7) twidth(6.5) 
	restore
end

main
