** Portfolio Choice
*** INCOME
clear all
global data "../../../Data/SP"
global general "../"
set more off

qui capture do "$general/tools/tools_database.do"
use "../output/derived_hpa.dta", clear
* Set spells of missing and non-missing income information & keep only the first spell of each
tsspell, cond(TIy_avg==.) spell(_sp_miss) end(_end_miss) seq(_seq_smiss)
tsspell, cond(TIy_avg!=.) spell(_sp_nmis) end(_end_nmis) seq(_seq_nmis)
drop _end* _seq*
keep if _sp_miss<=1 & _sp_nmis<=1
* Keep only invididuals that actually have both missing and non-missing income information
bys ID : egen temp_min = min(_sp_miss)
bys ID : egen temp_max = max(_sp_miss)
gen temp_change = (temp_min==0 & temp_max==1)
keep if temp_change==1
* Need to compute this over the same number of months on both sides
gen temp_year = year(dofm(date))
bys ID: gen year0 = temp_year if ID==ID[_n+1] & _sp_miss!=_sp_miss[_n+1]
bys ID (year0): replace year0 = year0[1]  if year0==.
keep if temp_year==year0 | temp_year==year0+1
bys ID : egen miss_months = total(_sp_miss)
bys ID : egen nmis_months = total(_sp_nmis)
keep if nmis_months==miss_months
* Set data at the individual level
bys ID : egen nmis_sw = total(sw_fund==1 & _sp_nmis==1)
bys ID : egen miss_sw = total(sw_fund==1 & _sp_miss==1)
collapse (first) N_sw_fund  nmis_sw miss_sw gender age TI0 TI TI_avg TI_a50 TI_quart TIy_avg TIy_a50 TIy_quart TI0_avg TI0_a50 TI0_quart TI0y_avg TI0y_quart age_def, by(ID)
gen difference  = abs(nmis_sw - miss_sw)
label var difference "Difference in yearly switches between years with and without income information"

gen aa = (difference<=1)
qui sum aa
scalar_txt, number(r(mean)*100)  filename(TI_sw_comparison) decimal(1)
gen aa_sw = (difference<=1)
qui sum aa_sw if N_sw_fund>0
scalar_txt, number(r(mean)*100)  filename(TI_sw_comparison_sw) decimal(1)

sum difference 
local obsN=r(N)
di `obsN'
qui levelsof difference, local(levels)
di `levels'
gen lower = .
gen upper = .
local words: word count `levels' //di `words'
forvalues w = 1/`words' {
	local j: word `w' of `levels'
	sum difference if difference==`j'
	local Nobs`j'=r(N)
	cii `obsN' `Nobs`j''
	replace lower = r(lb)*100 if difference==`j'
	replace upper = r(ub)*100 if difference==`j'
}

twoway hist difference, discrete percent || rcap upper lower difference, sort legend(off)
graph export "$general/output/TI_sw_comparison.png", replace

twoway hist difference if N_sw_fund>0, discrete percent legend(off)
graph export "$general/output/TI_sw_comparison_sw.png", replace

*hist difference2 if N_sw_fund>0, percent  
* Do they change direction?
* Probably not relevant since inds switch very rarely
/*egen gr_tag = group(ID date)
keep if 
bys ID _spell: egen sw_TI = sum(sw_fund)
bys ID : egen sw_TIm = sum(sw_fund) if _spell==0
gen temp_year = year(dofm(date))
bys ID temp_year: gen temp_mTI = (TIy_avg==.)
gen change = (temp_min==0 & temp_max==1)
bys ID temp_year: gen aam = (TIy_a50 == . )
