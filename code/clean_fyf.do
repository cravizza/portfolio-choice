*** Portfolio Choice
*** DATABASE - Pension affiliates' history

capture program drop fyf_rec
program              fyf_rec
syntax, delay(integer)
	set more off
	//global general "../"
	//local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	//log using "$general/log/clean_fyf`date'.log", replace

	import delim "$general/raw/fyf_recommendations.csv", clear varn(1)
	di "-- Format dates, note that switches take at least 2 business days to be effective"	
	gen date     = date(iniciociclo,"DMY")+`delay'
	gen date_end = date(términociclo,"DMY")+(`delay'-1)
	format %td date*
	
	di "-- Create recommendation variables"
	gen rec = 1
	split fondotérmino, gen(rec_) parse(/)
	split rec_1, gen(rec_1_) destring ignore(%) limit(2)
	split rec_2, gen(rec_2_) destring ignore(%) limit(2)
	foreach f in A B C D E {
		gen rec`f'=.
	}
	foreach f in A B C D E {
		replace rec`f' = rec_1_1/100 if rec_1_2=="`f'"
		replace rec`f' = rec_2_1/100 if rec_2_2=="`f'"
	}
	drop rec_* fondot fondoi *ciclo v1
	tempfile fyf_rec
	save `fyf_rec'
	
	di "-- Merge returns"
	use "$general/raw/clean_sharevalue_all.dta", clear
	merge m:1 date using `fyf_rec', nogen keep(1 3)

	di "-- Find first date of recommendation: fund A before that"
	qui sum date_end
	gen temp=date if date_end==`r(min)'
	sort temp
	carryforward temp, replace	
	qui sum temp
	assert `r(sd)'==0 & temp!=.
	replace recA=1 if  date<temp
	
	di "-- Carryforward date_end"
	sort date afp_all
	carryforward date_end, replace
	assert date<=date_end
	
	di "-- Carryforward recommendations"
	replace date_end = temp if date_end==.
	assert  date_end!=.
	carryforward recA recB recC recD recE if date<=date_end & date_end==date_end[_n-1], replace
	foreach f in A B C D E {
		replace rec`f' = 0 if rec`f'==.
	}
	egen temp1 = rownonmiss(recA recB recC recD recE)
	egen temp2 = rowtotal(recA recB recC recD recE)
	assert temp1>=1 & temp1!=. & temp2==1
	assert recA !=.
	drop temp*

	di "-- Generate daily return fyf"
	gen rfyf_d = r1*recA + r2*recB+ r3*recC+ r4*recD + r5*recE 
	save "$general/raw/clean_fyf_delay`delay'daily.dta", replace
	
	di "-- Cumulative monthly return fyf"
	gen month = mofd(date)
	rename rfyf_d rfyf
	foreach name in 1 3 5 fyf {
	qui gen temp_lnr`name' = ln(1+r`name')                      
	qui	bys afp_all month (date): egen temp_slr`name' = sum(temp_lnr`name')   
		bys afp_all month (date): gen r_`name'  = exp(temp_slr`name')-1 
	}
	drop date* fondo* fyf* temp_* r1 r2 r3 r4 r5 rfyf
	rename r_fyf rfyf
	rename month date
	format %tm date
	assert rfyf==rfyf[_n-1] if afp_all==afp_all[_n-1] & date==date[_n-1]
	sort afp_all date
	collapse (last) recA recB recC recD recE rfyf r_* (max) rec, by(afp_all date)
	egen temp1 = rownonmiss(recA recB recC recD recE)
	egen temp2 = rowtotal(recA recB recC recD recE)
	assert temp1>=1 & temp1!=. & temp2==1
	assert recA !=.
	drop temp*
	
	di "-- Assert we get same returns as with first of month methodology"
	local new = _N + 1
    set obs `new'
	replace date=ym(2010,8) if date==.
	replace afp_all="mod" if afp_all==""
	sort date afp_all
	foreach var of varlist rec* {
		replace `var'=`var'[_n-1] if afp_all=="mod" & date==ym(2010,8) & `var'==.
	}
	merge 1:1 afp_all date using "$general/raw/clean_sharevalue.dta", assert(3)
	assert round(r1,-5) == round(r_1,-5) if _merge==3 & afp_all!="mod" & date!=ym(2010,8)
	assert round(r3,-5) == round(r_3,-5) if _merge==3 & afp_all!="mod" & date!=ym(2010,8)
	assert round(r5,-5) == round(r_5,-5) if _merge==3 & afp_all!="mod" & date!=ym(2010,8)
	replace rfyf = r1 if afp_all=="mod" & date==ym(2010,8)
	
	di "-- Keep rec vars"
	egen n_rec = group(date rec) if rec==1
	keep date afp_all rfyf rec* n_rec
	save "$general/raw/clean_fyf_rec_delay`delay'.dta", replace
	
	//log close
end	

capture program drop fyf_delays
program              fyf_delays
	qui fyf_rec, delay(0)
	qui fyf_rec, delay(1)
	qui fyf_rec, delay(2)
	use "$general/raw/clean_sharevalue.dta", clear
	merge 1:1 date afp_all using "$general/raw/clean_fyf_rec_delay0.dta", nogen assert(3)
	rename rfyf rfyf_0
	merge 1:1 date afp_all using "$general/raw/clean_fyf_rec_delay1.dta", ///
			nogen assert(3) keepus(rfyf)
	rename rfyf rfyf_1
	merge 1:1 date afp_all using "$general/raw/clean_fyf_rec_delay2.dta", ///
			nogen assert(3) keepus(rfyf)
	rename rfyf rfyf_2
	save "$general/raw/clean_fyf_rec_delays.dta", replace
end

fyf_rec, delay(0)
fyf_rec, delay(1)
fyf_rec, delay(2)
fyf_rec, delay(3)
fyf_rec, delay(4)
fyf_rec, delay(5)
fyf_delays
