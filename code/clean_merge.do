*** Portfolio Choice
*** Merge databases to be used
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/clean_merge`date'.log", replace
	import delim "$data/hpa/informacion_mensual_saldos.csv", delim(";") clear
	cleaning_main
	fill_gaps
	database_merge
	log close
end

capture program drop cleaning_main
program              cleaning_main
	qui do "$general/tools/hpa_labels_saldos.txt"
	rename v1 id
	label var id "id"
	date2vars_monthly, newdate(date) year_var(v2) month_var(v3)
	rename v5 f1
	rename v6 f2
	rename v7 f3
	rename v8 f4
	rename v9 f5
	rename v4 type_account
	label var type_account "1=CCICO,2=CAV,3=CAI,4=CCICV,5=CCIDC,6=CCIAV,7=CAPVC"
	isid id date type_account
end

capture program drop  fill_gaps
program               fill_gaps
	egen temp_id = group(id type_account)
	xtset temp_id date
	tsfill
	gen tag_fill = (mi(id) & mi(type_account))
	bys temp_id (date) : carryforward id type_account, replace
	drop temp_*
	isid id date type_account
end
capture program drop database_merge
program              database_merge
	save "$general/raw/hpa_merged.dta", replace
	egen temp_id = group(type_account id)
	merge m:1 id 		   using "$general/raw/clean_pre_characteristics.dta", assert(1 3) keep(3)   nogen
	merge m:1 id date 	   using "$general/raw/clean_pre_afp.dta"            , assert(1 3) keep(3)   nogen
	merge m:1 id date      using "$general/raw/clean_pre_TI.dta"             ,             keep(1 3) nogen
	merge m:1 id date      using "$general/raw/clean_pre_cav.dta"            ,             keep(1 3) nogen
	replace cav=0 if cav==.
	sort afp_all date
	merge m:1 afp_all date using "$general/raw/clean_pre_fees_custom.dta"    , assert(3)             nogen
	merge m:1 afp_all date using "$general/raw/clean_pre_returns.dta"        , assert(3)             nogen
	tsreport temp_id date, panel
	assert `r(N_gaps2)'==0
	drop temp_*
	isid id date type_account
	order date id afp_all type_account f1-f5 r1-r5
	save "$general/raw/hpa_merged.dta", replace
end


main

/*sort type_account id date //drop temp_date//gen temp_date = date[_n+1]-1//format temp_date %tm

*merge_save, match_vars(id) using_file(characteristics) master_file(hpa_merged) options(keep(3))
capture program drop merge_save
program              merge_save
	syntax, match_vars(string) using_file(string) master_file(string) ///
	        options(string) [other_cleaning(string)]
	merge m:1  `match_vars' using "${general}/raw/clean_"`using_file'".dta", `options' nogen
	`other_cleaning'
	save  "${general}/raw/"`master_file'".dta", replace
end
