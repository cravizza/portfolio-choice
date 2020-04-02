*** Portfolio Choice
*** DATABASE - Pension affiliates' history
clear all
global data "../../../Data/SP"
global general "../"
set more off

capture program drop main
program              main
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/clean_basic`date'.log", replace
	use "$general/raw/hpa_merged.dta", clear
	basic_cleaning
	fix_blnc0_ifswfirm
	def_blnc0_spells
	fix_blnc0_true0_1month_spell
	fix_blnc0_true0_missing_cf
	fix_blnc0_true0_miss_0funds
	fix_blnc0_true0_f0
	fix_blnc0_true0_f0fp
	fix_checks
	save "$general/raw/hpa_clean.dta", replace
	log close
end

capture program drop basic_cleaning
program              basic_cleaning
	di "-- Basic_cleaning"
	egen ID     = group(id)
	egen IDacc  = group(type_account ID)
	gen  gender = (c2=="M")
	gen  age    = floor((date-date_c3)/12) if date<=date_c4
	drop if age==. | age>65
	drop if c23!=. & date_c4!=. //if receives pension having date of death
	* Define AFP switches //drop id c2 c8-c14 c21-c35
	assert !mi(afp_all)
	keep if type_account==1 | type_account==2  //only CCICO & CAV
	isid ID date type_account
	gen 	afp = afp_all                 //w/fusions,no switch //replace afp_f="pli" if afp_f="mag"
	replace afp = "cap" if afp_all=="sta" //03-17-2008: name change Sta->Cap
	replace afp = "cap" if afp_all=="ban" //04-01-2008: fusion Cap-Ban
	bys type_account ID (date): gen sw_firm = (afp[_n]!=afp[_n-1] & ID[_n]==ID[_n-1]) //firm switch
	* Drop if non-miss pension date, after checking that this won't produce gaps
	assert !(date_c22!=. & date_c22[_n+1]==. & IDacc==IDacc[_n+1])
	assert date_c22!=. if IDacc!=IDacc[_n+1] &  IDacc==IDacc[_n-1] & date_c22[_n-1]!=.
	//drop if date_c22!=.
end
	
capture program drop fix_blnc0_ifswfirm
program              fix_blnc0_ifswfirm
	di "-- Fix if balance is zero at the month of a firm switch"
	forvalues f=1/5 {
		gen F`f'=f`f'
		replace F`f'=0 if mi(f`f')    //		replace f`f'=0 if mi(f`f')
	}
	egen _balance = rowtotal(F1 F2 F3 F4 F5) //egen _balance = rowtotal(f1 f2 f3 f4 f5)
	bys type_account ID (date): egen _balance_period = total(_balance)
	drop if _balance_period == 0
	gen _zero = ( (sw_firm[_n-1]==1 | sw_firm==1 | sw_firm[_n+1]==1) ///
					& ID==ID[_n-1] & ID==ID[_n+1] ///
					& _balance==0  & _balance[_n-1]>0 & _balance[_n+1]>0)
	forvalues f=1/5 {	
		foreach fund in f F {
			replace `fund'`f' = round(`fund'`f'[_n-1]*(1+r`f'[_n-1]),10000) ///
				if _zero==1 & afp==afp[_n-1] & F`f'==0
			replace `fund'`f' = round(`fund'`f'[_n+1]/(1+r`f')      ,10000) ///
				if _zero==1 & afp==afp[_n+1] & F`f'==0
		}
	}
	drop _*
end

capture program drop def_blnc0_spells
program              def_blnc0_spells
	di "-- Fix balance 0 spells at the beginning/end of the id-date sequence"
	egen _blnc = rowtotal(F1 F2 F3 F4 F5)
	sort type_account ID date
	forvalues f=1/5 {
		local j = `f'+9
		gen f`f'_b0 = (v`j'==1 & _blnc==0) //Indicator of fund0 when blnc0
	}
	egen  _id = group(type_account ID)
	tsset _id date, monthly
	*Define blnc0 spells
	tsspell , cond(_blnc==0) spell(_sp_b0) seq(_seq0) end(_end0) //ADD LOCAL NEXT
	local 1match_ind_b0 f1==0&f1_b0==1|f2==0&f2_b0==1|f3==0&f3_b0==1|f4==0&f4_b0==1|f5==0&f5_b0==1
	gen _Iend = (_end0==1 & _id!=_id[_n+1])               if type_account==1
	gen _Ibeg = (_seq0==1 & _id!=_id[_n-1])               if type_account==1
	bys _id _sp_b0: egen _Iendmax = max(_Iend)            if type_account==1
	bys _id _sp_b0: egen _Ibegmax = max(_Ibeg)            if type_account==1
	bys _id _sp_b0: egen _Imatch  = min(`1match_ind_b0')  if type_account==1
	gen _Idrop = ((_Iendmax==1|_Ibegmax==1) & _Imatch==0) if type_account==1
	* Drop blnc0 spells without indicator match at the beginning/end of the id-month sequence
	drop if _Idrop==1
	drop _Idrop _Iend _Ibeg _Imatch 
	tsreport _id date, panel
	assert `r(N_gaps2)'==0
end

capture program drop fix_blnc0_true0_1month_spell //Fix one-month zero-balance spells
program              fix_blnc0_true0_1month_spell
	di "-- fix_blnc0_true0_1month" //use "$general\code\temp_clean.dta", clear
	sort type_account ID date //br date ID afp_all _Inm0 f1 f2 f3 f4 f5 f*_b0 if ID==5618 //ID==433
	egen _Inm0 = rownonmiss(f1 f2 f3 f4 f5) if type_account==1 
	forvalues f=1/5 {	
		local 1m_sp_b0 _sp_b0>0 & _seq0==1 & _end0==1 & type_account==1
		local sp_nmi_mid (f`f'[_n-1]!=. & f`f'[_n+1]!=.)
		local sp_mis_mid (f`f'[_n-1]==. & f`f'[_n+1]==.)
		local sp_nmi_beg (_Ibegmax==1   & f`f'[_n+1]!=.)
		local sp_mis_beg (_Ibegmax==1   & f`f'[_n+1]==.)
		local sp_nmi_end (_Iendmax==1   & f`f'[_n-1]!=.)
		local sp_mis_end (_Iendmax==1   & f`f'[_n-1]==.)
		replace f`f'=.    if f`f'==0 & `1m_sp_b0' & (`sp_mis_beg'|`sp_mis_end'|`sp_mis_mid')
		replace f`f'_b0=0 if f`f'==. & `1m_sp_b0' & (`sp_mis_beg'|`sp_mis_end'|`sp_mis_mid') 
		replace f`f'=0    if f`f'==. & `1m_sp_b0' & (`sp_nmi_beg'|`sp_nmi_end'|`sp_nmi_mid') 
		replace f`f'_b0=1 if f`f'==0 & `1m_sp_b0' & (`sp_nmi_beg'|`sp_nmi_end'|`sp_nmi_mid')
	}
end

capture program drop fix_blnc0_true0_missing_cf //Fix missing from carryforward
program              fix_blnc0_true0_missing_cf
	di "-- fix_blnc0_true0_missing_cf"
	egen _Inm1 = rownonmiss(f1 f2 f3 f4 f5)      if type_account==1
	local miss_from_cf _Inm1==0 & _sp_b0>0 & tag_afp_cf==1 & tag_fill==1
	carryforward f1 f2 f3 f4 f5 if `miss_from_cf', replace
	forvalues f=1/5 {
		replace  f`f'_b0=0 if f`f'>0 & f`f'!=. & `miss_from_cf'
	}
end

capture program drop fix_blnc0_true0_miss_0funds
program              fix_blnc0_true0_miss_0funds
	di "-- fix_blnc0_true0_miss_0funds"
	*Drop all obs for id's with at least one obs with 3 nonmissing & nonzero funds
	egen   _Inm2     = rownonmiss(f1 f2 f3 f4 f5)      if type_account==1
	assert _Inm2!=0 //Works if missings are only from cf
	gen _Ifund0      = (f1==0|f2==0|f3==0|f4==0|f5==0) if type_account==1
	gen _Inm_nofund0 = (_Ifund0==0 & _Inm2>2)          if type_account==1
	bys _id (date) : egen _Idrop = max(_Inm_nofund0)   if type_account==1
	drop if _Idrop==1 //bys _id (date) : egen _Inmmax = max(_Inm) 
	*Fix fund balance when fund has a period-balance equal to 0 
	forvalues f=1/5 {
		bys _id (date): egen _If`f'tot = total(f`f') //gen zerof`f'= (_If`f'tot==0 & f`f'==0)
		local alwaysf0 _If`f'tot==0 & _Inm2>1 & type_account==1
		local 0m_0m (f`f'[_n-1]==.|f`f'[_n-1]==0) & type_account==1  ///
		          & (f`f'[_n+1]==.|f`f'[_n+1]==0) & _id==_id[_n-1] & _id==_id[_n+1]
		local 0_0  f`f'[_n-1]==0 & f`f'[_n+1]==0 & _id==_id[_n-1] & _id==_id[_n+1] & type_account==1 
		replace f`f'=.    if `alwaysf0' & f`f'==0 & `0m_0m'
		replace f`f'=0    if `alwaysf0' & f`f'==. & `0_0'
		replace f`f'_b0=0 if `alwaysf0' & f`f'==. & _blnc==0  
		replace f`f'_b0=1 if `alwaysf0' & f`f'==0 & _blnc==0  
	}
end

capture program drop fix_blnc0_true0_f0
program              fix_blnc0_true0_f0
	di "-- fix_blnc0_true0_f0"
	*Replace fund=. when fund=0 and at least 3 nonmissing funds //bys_iddate:egena=max(_Inm_fund0)
	egen _Inm3     = rownonmiss(f1 f2 f3 f4 f5)               if type_account==1
	gen _Inm_fund0 = (_Ifund0==1 & _Inm3>2 & type_account==1) if type_account==1
	egen _In0      = anycount(f1 f2 f3 f4 f5), values(0)
	forvalues f=1/5 {
		replace f`f'=.          if f`f'==0 & _Inm_fund0==1 & f`f'[_n-1]==. & f`f'[_n+1]==.
		replace f`f'=.          if f`f'==0 & _Inm_fund0==1 & _Inm3-_In0==2
	}
	local i=1
	while `i'<=5 {
		egen _Inm3`i'    = rownonmiss(f1 f2 f3 f4 f5) if type_account==1
		gen _Inm_fund0`i'=(_Ifund0==1 & _Inm3`i'>2 & _Inm3`i'-_In0==1 & type_account==1)
		forvalues f=1/5 {
			replace f`f'=. if f`f'==0 & _Inm_fund0`i'==1 & (_Inm3`i'[_n-1]==1 |_Inm3`i'[_n+1]==1)
		}
		local i=`i'+1
	}
	*Fix fund when missing value with above&below zero fund for some individual
	forvalues f=1/5 {
		local ta1_b0 type_account==1 & _blnc==0
		local 0_0  f`f'[_n-1]==0          &          f`f'[_n+1]==0 & _id==_id[_n-1] & _id==_id[_n+1]
		local m_m  f`f'[_n-1]==.          &          f`f'[_n+1]==. & _id==_id[_n-1] & _id==_id[_n+1]
		local b_0  _Ibegmax==1 & _seq0==1 &          f`f'[_n+1]==0 &                  _id==_id[_n+1]
		local b_m  _Ibegmax==1 & _seq0==1 &          f`f'[_n+1]==. &                  _id==_id[_n+1]
		local 0_e  f`f'[_n-1]==0          & _Iendmax==1 & _end0==1 & _id==_id[_n-1] 
		local m_e  f`f'[_n-1]==.          & _Iendmax==1 & _end0==1 & _id==_id[_n-1] 
		replace f`f'=0    if  f`f'==. & `ta1_b0' & ((`b_0')|(`0_0')|(`0_e'))
		replace f`f'_b0=1 if  f`f'==0 & `ta1_b0' & ((`b_0')|(`0_0')|(`0_e'))
		replace f`f'=.    if  f`f'==0 & `ta1_b0' & ((`b_m')|(`m_m')|(`m_e'))
		replace f`f'_b0=0 if  f`f'==. & `ta1_b0' & ((`b_m')|(`m_m')|(`m_e'))
	}
end

capture program drop fix_blnc0_true0_f0fp
program              fix_blnc0_true0_f0fp
	di "-- fix_blnc0_true0_f0fp"
	egen   _Inm4= rownonmiss(f1 f2 f3 f4 f5) if type_account==1
	gen _If0_fp = (type_account==1 & _Inm4==2 & (f1==0|f2==0|f3==0|f4==0|f5==0) ///
		          & ((f1>0&f1!=.)|(f2>0&f2!=.)|(f3>0&f3!=.)|(f4>0&f4!=.)|(f5>0&f5!=.)))
	egen _blnc2 = rowtotal(f1 f2 f3 f4 f5)
	forvalues f=1/5 {
		replace f`f'=. if f`f'==0 & _If0_fp==1 & _blnc2>20000
		replace f`f'=. if f`f'==0 & _If0_fp==1 & _blnc2>=10000 & f`f'[_n+1]==. & _id!=_id[_n-1]
		replace f`f'=. if f`f'==0 & _If0_fp==1 & _blnc2>=10000 & f`f'[_n-1]==. & _id!=_id[_n+1]
	}
	forvalues f=1/5 {
	local miss_fr_a_b _Inm4==0 & f`f'==. & _id==_id[_n+1] & _id==_id[_n-1]
	replace f`f'=0 if `miss_fr_a_b' & f`f'[_n-1]>=0 & f`f'[_n-1]!=. & f`f'[_n+1]>=0 & f`f'[_n+1]!=.
	}
end

capture program drop fix_checks
program              fix_checks
	di "-- fix_checks"
	egen   _Inm5= rownonmiss(f1 f2 f3 f4 f5) if type_account==1
	assert _Inm5==1 | _Inm5==2               if type_account==1
	tsreport _id date, panel
	assert `r(N_gaps2)'==0
	drop _I* _id _blnc* _*0 F* ID*	
	order  date id age gender afp_all afp type_account f1-f5 r1-r5 f*_b0 sw_firm ///
	       TI reld pRT pRP bhijo ch_* I_* cav* date_* tag* 
end

main
