clear all
global data "../../../Data/SP"
global general "../"
global wb = "graphregion(color(white)) bgcolor(white)"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	return_monthly, filename(_drop) drop_stuff(drop if afp_all=="ban" & date==ym(2008,3))
	return_monthly
end

capture program drop return_monthly
program return_monthly
syntax, [drop_stuff(string) filename(string)]
	//use "$general/raw/clean_sharevalue.dta", clear
	//keep if afp_all=="cap"
	//assert _N==103
	//replace afp_all = "ban" if afp_all=="cap"
	//tempfile add_ban
	//save `add_ban'
	use "$general/raw/clean_sharevalue.dta", clear
	//append using `add_ban'
	replace afp_all = "cap" if afp_all=="sta"
	encode afp_all, generate(pfa)
	xtset pfa date
	tempfile return_fusion
	`drop_stuff'
	save `return_fusion'
	* Find min correlation of all pairs of firms for each fund
	drop afp_all
	reshape wide r1 r2 r3 r4 r5, i(date) j(pfa)
	foreach X in  r1 r2 r3 r4 r5 {
		replace `X'1=`X'2 if `X'1==.
	}
	qui foreach x in r1 r2 r3 r4 r5  { 
		gen min_corr`x' = 1 
		gen avg_corr`x' = 0
		local lowcorr = 1
		local avgcorr = 0
		local num = 0
		forvalues i=1/7 { 
			forvalues j=2/7 {
				if `j'>`i' {
					corr `x'`i' `x'`j' 
					if r(rho) < `lowcorr' { 
						local lowcorr = r(rho)
					} 
					local avgcorr = `avgcorr' + r(rho)
					local num = `num'+1
				}
			}
		}
		replace min_corr`x' = int(`lowcorr'*1000)
		replace avg_corr`x' = int(`avgcorr'/`num'*1000)
	} 	
	keep date *_corr*
	tempfile correlations
	save `correlations'
	* Add min correlations to the returns file
	use `return_fusion', clear
	merge m:1 date using `correlations'
	xtset pfa date
	* Plots
	rename r1 Fund_A
	rename r2 Fund_B
	rename r3 Fund_C
	rename r4 Fund_D
	rename r5 Fund_E
	foreach word in min avg {
		rename `word'_corrr1 `word'_corrA
		rename `word'_corrr2 `word'_corrB
		rename `word'_corrr3 `word'_corrC
		rename `word'_corrr4 `word'_corrD
		rename `word'_corrr5 `word'_corrE
	}
	label var date "Month"
	foreach X in A B C D E {
		label var Fund_`X' "Return (%)"
		qui sum avg_corr`X'
		scalar_txt, number(`r(mean)') filename(r`X'_corr`filename') decimal(0)
		local mincorr=string(`r(mean)')
		xtline Fund_`X', ${wb} ov legend(off) name(graph_f`X') ///
		ylabel(#5, format(%9.2f)) yscale(range(-.15 .2)) ///
		tlabel(#3) title("Fund `X' (corr: 0.`mincorr')")
	}
	
	graph combine graph_fA graph_fB graph_fC graph_fD graph_fE , graphregion(color(white)) ///
	rows(2) col(3) //title("Real returns") ysize(4) xsize(5.5) iscale(1.3) 
	 
	graph export "$general/output/returns_monthly`filename'.png", replace
	graph drop _all
	* Scalars
	foreach X in A B C D E {
		qui sum Fund_`X'
		scalar_txt, number(`r(mean)'*100) filename(r`X'_avg`filename') decimal(2)
	}
end	

main
		
