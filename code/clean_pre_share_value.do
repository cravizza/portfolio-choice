*** Data from Superintendencia Pensiones
*** DATABASE - Share value
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main_sv // http://www.spensiones.cl/safpstats/stats/apps/vcuofon/vcfAFP.php?tf=A
	capture qui do "$general/tools/tools_database.do"
	qui sv_import_yearfund
	sv_append_merge
	sv_adjustments_return
	save "$general/raw/clean_sharevalue.dta", replace
	clear
	qui sv_import_yearfund_all
	sv_append_merge_all
	sv_return
	save "$general/raw/clean_sharevalue_all.dta", replace
end

capture program drop sv_adjustments_return
program              sv_adjustments_return
	rename afp afp_all
	* Add starting SV of AFP Modelo
	local new1 = _N + 1
    set obs `new1'
	replace date=ym(2010,8) if date==.
	replace afp_all="mod" if afp_all==""
  	replace sv_f1=25000 if date==ym(2010,8) & afp_all=="mod"
	replace sv_f2=22000 if date==ym(2010,8) & afp_all=="mod"
	replace sv_f3=25000 if date==ym(2010,8) & afp_all=="mod"
	replace sv_f4=19000 if date==ym(2010,8) & afp_all=="mod"
	replace sv_f5=24000 if date==ym(2010,8) & afp_all=="mod"
	* Add sta 200804 for SV change (sta to cap name change in 200803) then drop in sv_return
	local new2 = _N + 1
    set obs `new2'
	replace date=ym(2008,4) if date==.
	replace afp_all="sta" if afp_all==""
	sort date afp_all
	forvalues f=1/5 {
		replace sv_f`f'=sv_f`f'[_n-5] if date==ym(2008,4) & afp_all=="sta"
	}
	* Add sta 200804 for SV change (ban to cap name change in 200803) then drop in sv_return
	local new3 = _N + 1
    set obs `new3'
	replace date=ym(2008,4) if date==.
	replace afp_all="ban" if afp_all==""
	sort date afp_all
	forvalues f=1/5 {
		replace sv_f`f'=sv_f`f'[_n+1] if date==ym(2008,4) & afp_all=="ban"
	}
	isid date afp_all
	sort afp_all date
	forvalues f=1/5 {
		gen r`f' = (sv_f`f'[_n+1]-sv_f`f')/sv_f`f' if afp_all==afp_all[_n+1]
		label var r`f' "Return rate fund `f'"
	}
	drop sv_f*
	drop if date==ym(2008,4) & afp_all=="sta"
	drop if date==ym(2008,4) & afp_all=="ban"
	drop if date==ym(2016,11)
	assert r1!=.
end

capture program drop sv_append_merge
program              sv_append_merge
	di "-- Append"
	foreach fund in A B C D E {
	use "$general/raw/temp/temp_sv_f`fund'_1", clear
	forvalues i=2/12 {
		append using "$general/raw/temp/temp_sv_f`fund'_`i'"
		}
	save "$general/raw/temp/temp_sv_f`fund'", replace
	isid date afp
	}
	di "-- Merge"
	use "$general/raw/temp/temp_sv_fA", clear
	rename sv_fA sv_f1
	local i=2
	foreach fund in B C D E {
		merge 1:1 date afp using "$general/raw/temp/temp_sv_f`fund'", assert(3) keep(3) nogen
		rename sv_f`fund' sv_f`i'
		local i=`i'+1
	}
end
	
capture program drop sv_import_yearfund
program              sv_import_yearfund
	local end_1=368
	local end_2=462
	local end_3=740
	local end_4=1108
	local end_5=1354
	local end_6=1479
	local end_7=1847
	local end_8=2216
	local end_9=2584
	local end_10=2952
	local end_11=3320
	local end_12=3628
	local num_1=2
	forvalues i=1/12 {
		local j=`i'+1
		local num_`j'=`end_`i''+2	
	}
	foreach letter in A B C D E {
		forvalues x = 1/12 {
		sv_reshape, fund(`letter') varn(`num_`x'') row_end(`end_`x'') filenumber(`x')
		}
	}
end

capture program drop sv_reshape
program              sv_reshape
	syntax, fund(string) varn(real) row_end(real) filenumber(string)
	local row_start=`varn'+2
	import delim "$data/financial_info_funds/vcf`fund'2007-2016.csv", ///
		   delim(";") clear varn(`varn') rowr(`row_start':`row_end') 
	drop v*
	capture replace fecha="2016-11-01" if fecha=="2016-10-31"
	keep if strmatch(fecha,"*-01") 
	dateYMDstr_monthly, newdate(date) olddate(fecha)
	capture gen sv_f`fund'ban =  real(subinstr(subinstr(bansander,".","",1),",",".",1))
	capture gen sv_f`fund'cup =  real(subinstr(subinstr(cuprum,".","",1),",",".",1))
	capture gen sv_f`fund'cap =  real(subinstr(subinstr(capital,".","",1),",",".",1))
	capture gen sv_f`fund'hab =  real(subinstr(subinstr(habitat,".","",1),",",".",1))
	capture gen sv_f`fund'mod =  real(subinstr(subinstr(modelo,".","",1),",",".",1))
	capture gen sv_f`fund'pli =  real(subinstr(subinstr(planvital,".","",1),",",".",1))
	capture gen sv_f`fund'prv =  real(subinstr(subinstr(provida,".","",1),",",".",1))
	capture gen sv_f`fund'sta =  real(subinstr(subinstr(santamaria,".","",1),",",".",1))
	keep date sv_f*
	reshape long sv_f`fund', i(date) j(afp) s
	save "$general/raw/temp/temp_sv_f`fund'_`filenumber'", replace
end

capture program drop sv_reshape_all
program              sv_reshape_all
	syntax, fund(string) varn(real) row_end(real) filenumber(string)
	local row_start=`varn'+2
	import delim "$data/financial_info_funds/vcf`fund'2007-2016.csv", ///
		   delim(";") clear varn(`varn') rowr(`row_start':`row_end') 
	drop v*
	capture replace fecha="2016-11-01" if fecha=="2016-10-31"
	gen date=date(fecha,"YMD")
	format %td date
	capture gen sv_f`fund'ban =  real(subinstr(subinstr(bansander,".","",1),",",".",1))
	capture gen sv_f`fund'cup =  real(subinstr(subinstr(cuprum,".","",1),",",".",1))
	capture gen sv_f`fund'cap =  real(subinstr(subinstr(capital,".","",1),",",".",1))
	capture gen sv_f`fund'hab =  real(subinstr(subinstr(habitat,".","",1),",",".",1))
	capture gen sv_f`fund'mod =  real(subinstr(subinstr(modelo,".","",1),",",".",1))
	capture gen sv_f`fund'pli =  real(subinstr(subinstr(planvital,".","",1),",",".",1))
	capture gen sv_f`fund'prv =  real(subinstr(subinstr(provida,".","",1),",",".",1))
	capture gen sv_f`fund'sta =  real(subinstr(subinstr(santamaria,".","",1),",",".",1))
	keep date sv_f*
	reshape long sv_f`fund', i(date) j(afp) s
	save "$general/raw/temp/temp_all_sv_f`fund'_`filenumber'", replace
end

capture program drop sv_import_yearfund_all
program              sv_import_yearfund_all
	local end_1=368
	local end_2=462
	local end_3=740
	local end_4=1108
	local end_5=1354
	local end_6=1479
	local end_7=1847
	local end_8=2216
	local end_9=2584
	local end_10=2952
	local end_11=3320
	local end_12=3628
	local num_1=2
	forvalues i=1/12 {
		local j=`i'+1
		local num_`j'=`end_`i''+2	
	}
	foreach letter in A B C D E {
		forvalues x = 1/12 {
		sv_reshape_all, fund(`letter') varn(`num_`x'') row_end(`end_`x'') filenumber(`x')
		}
	}
end

capture program drop sv_append_merge_all
program              sv_append_merge_all
	di "-- Append"
	foreach fund in A B C D E {
	use "$general/raw/temp/temp_all_sv_f`fund'_1", clear
	forvalues i=2/12 {
		append using "$general/raw/temp/temp_all_sv_f`fund'_`i'"
		}
	save "$general/raw/temp/temp_all_sv_f`fund'", replace
	isid date afp
	}
	di "-- Merge"
	use "$general/raw/temp/temp_all_sv_fA", clear
	rename sv_fA sv_f1
	local i=2
	foreach fund in B C D E {
		merge 1:1 date afp using "$general/raw/temp/temp_all_sv_f`fund'", assert(3) keep(3) nogen
		rename sv_f`fund' sv_f`i'
		local i=`i'+1
	}
end

capture program drop sv_return
program              sv_return
	rename afp afp_all
	isid afp_all date
	sort afp_all date
	forvalues f=1/5 {
		gen r`f' = (sv_f`f'[_n+1]-sv_f`f')/sv_f`f' if afp_all==afp_all[_n+1]
		label var r`f' "Return rate fund `f'"
	}
	drop sv_f*
	qui sum date
	drop if date==`r(max)'
	drop if date==date("31-03-2008","DMY") & (afp_all=="ban"|afp_all=="sta")
	assert r1!=.
end

main_sv

/* 	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(2) rowr(4:368)
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(370) rowr(372:462) 
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(464) rowr(466:740) 
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(742) rowr(744:1108)
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(1110) rowr(1112:1354) 
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(1356) rowr(1358:1479)
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(1481) rowr(1483:1847) 
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(1849) rowr(1851:2216) 
	import delim "$data/financial_info_funds/vcfA2007-2016.csv", delim(";") clear varn(2218) rowr(2220:2584) 

	share_value, fund(A) varn(`num_2') row_end(`end_2') filenumber(2)
	share_value, fund(A) varn(`num_3') row_end(`end_3') filenumber(3)
	share_value, fund(A) varn(2218) row_end(2584) filenumber(4)
	share_value, fund(A) varn(2218) row_end(2584) filenumber(5)
	share_value, fund(A) varn(2218) row_end(2584) filenumber(6)
	share_value, fund(A) varn(2218) row_end(2584) filenumber(7)
	share_value, fund(A) varn(2218) row_end(2584) filenumber(8)
	share_value, fund(A) varn(2218) row_end(2584) filenumber(9)
