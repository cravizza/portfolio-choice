*** Data from Superintendencia Pensiones
*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	data_create
	data_merge
	returns_graph
end

program data_create
	foreach X in a b c d e {
	import excel "$data/returns/rentabilidad_real_anual_fondo_pensiones_tipo_`X'_deflactada_uf.xls", first clear
	rename A PFA
		local i 4
		foreach x in B C D E F G {
			rename `x' `X'200`i'
			local i=`i'+1
		}
		local i 10
		foreach x in H I J K L M {
		rename `x' `X'20`i'
			local i=`i'+1
		}
	reshape long `X', i(PFA) j(year)
	drop if PFA=="MAGISTER(4)"

	save "$data/returns/return_`X'.dta", replace
	}
end

program data_merge
	use "$data/returns/return_a.dta", clear
	foreach X in b c d e {
		merge 1:1 PFA year using "$data/returns/return_`X'.dta"
		drop _merge
	}
	save "$general/raw/returns.dta", replace
end

program returns_graph
	use "$general/raw/returns.dta", clear
	encode PFA, generate(pfa)
	xtset pfa year
	* Find min correlation of all pairs of firms for each fund
	drop PFA
	drop if pfa==8 // drop SISTEMA
	reshape wide a b c d e, i(year) j(pfa)
	foreach X in a b c d e {
	replace `X'1=`X'2 if `X'1==.
	}
	qui foreach x in a b c d e  { 
		gen min_corr`x' = 1 
		local lowcorr = 1
		forvalues i=1/7 { 
			forvalues j=2/7 {
				if `j'>`i' {
					corr `x'`i' `x'`j' 
					if r(rho) < `lowcorr' { 
						local lowcorr = r(rho)
					} 
				}
			}
		}
		replace min_corr`x' = int(`lowcorr'*1000)
	} 	
	keep year min_corr*
	tempfile min_correlations
	save `min_correlations'
	* Add min correlations to the returns file
	use "$general/raw/returns.dta", clear
	merge m:1 year using `min_correlations'
	encode PFA, generate(pfa)
	xtset pfa year
	* Plots
	preserve
	local i=1
	foreach X in a b c d e {
		rename `X' Fund_`i'
		label var Fund_`i' "Real return (%)"
		qui sum min_corr`X'
		local mincorr=string(`r(mean)')
		xtline Fund_`i', ov legend(off) name(graph_f`i') ///
		ylabel(#5, format(%9.0f)) yscale(range(-40 40)) ///
		title("Fund `i' (corr: 0.`mincorr')")
		local i=`i'+1
	}
	graph combine graph_f1 graph_f2 graph_f3 graph_f4 graph_f5 , ///
	rows(2) col(3) //title("Real returns") ysize(4) xsize(5.5) iscale(1.3) 
	 
	graph export "$general/output/returnsnumber.png", replace
	restore
	graph drop _all
	* Plots
	rename a Fund_A
	rename b Fund_B
	rename c Fund_C
	rename d Fund_D
	rename e Fund_E
	rename min_corra min_corrA
	rename min_corrb min_corrB
	rename min_corrc min_corrC
	rename min_corrd min_corrD
	rename min_corre min_corrE
	foreach X in A B C D E {
		label var Fund_`X' "Real return (%)"
		qui sum min_corr`X'
		local mincorr=string(`r(mean)')
		xtline Fund_`X', ov legend(off) name(graph_f`X') ///
		ylabel(#5, format(%9.0f)) yscale(range(-40 40)) ///
		title("Fund `X' (corr: 0.`mincorr')")
	}
	graph combine graph_fA graph_fB graph_fC graph_fD graph_fE , ///
	rows(2) col(3) //title("Real returns") ysize(4) xsize(5.5) iscale(1.3) 
	 
	graph export "$general/output/returns.png", replace
	graph drop _all
end

main
