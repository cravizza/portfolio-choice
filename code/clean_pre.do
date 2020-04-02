*** Portfolio Choice
*** Clean databases to be used
clear all
global data "../../../Data/SP"
global general "../"
set more off

capture program drop  main
program main
	qui capture do "$general/tools/tools_database.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "../log/clean_pre`date'.log", replace
	database_characteristics
	database_afp_nogaps
	database_ccico
	database_cav
	database_fees
	database_return
	log close
end

capture program drop database_characteristics
program              database_characteristics
	import delim "$data/hpa/caracteristicas_afiliados.csv", delim(";") clear
	* hpa.pdf: Word=copy merging format. Translate 1st column. Excel=gen cols for: label var v1 " ". Save=.txt
	qui do "$general/tools/hpa_labels_char.txt"
	foreach x of numlist 1/35 {
		rename v`x' c`x'
	}
	rename c1 id
	dateYMnum_monthly , dates(c3 c4 c5 c22 c25)
	drop if c21==2 //drop switch to 2nd pension to avoid duplicates in id 
	isid id
	save "$general/raw/clean_pre_characteristics.dta", replace
end

capture program drop database_afp_nogaps
program              database_afp_nogaps
	import delim "$data/hpa/informacion_mensual_afp.csv", delim(";") clear
	date2vars_monthly, newdate(date) year_var(v2) month_var(v3)
	rename v1 id
	rename v4 afp_all
	label var afp_all "afp"
	tsset id date
	tsspell , cond(mi(afp_all)) spell(_sp_mi)
	bys id _sp_mi (date): egen _mi = count(_sp_mi) if _sp_mi>0
	sort id date
	gen _Iend = (_end==1 & id!=id[_n+1])
	bys id _sp_mi: egen _Iendmax = max(_Iend)
	sort id date
	carryforward afp_all if _mi<=4 & _Iendmax==0, replace
	replace afp_all="cap" if afp_all=="sta" & date>ym(2008,3)
	gen tag_afp_cf = (_mi<=4 & _Iendmax==0)
	replace _mi=. if  _mi<=4 & _Iendmax==0
	tsspell , cond(!mi(afp_all)) spell(_sp_nm) seq(_seqn) end(_endn)
	by id: egen _max_nm = max(_sp_nm) //how many spells with non-missing values
	drop if _max_nm==0
	egen _length = max(_seqn), by(id _sp_nm) //spell length by id-spell
	egen _length_id = max(_seqn), by(id) //longest spell by id
	keep if _length==_length_id & _length>=12 //keep longest spell
	drop  _*
	tsreport id date, panel
	assert `r(N_gaps2)'==0
	isid id date
	assert !mi(afp_all) | !mi(id) | !mi(date)
	save "$general/raw/clean_pre_afp.dta", replace
end
	
capture program drop database_ccico
program              database_ccico
	import delim "$data/hpa/informacion_mensual_ccico.csv", delim(";") clear
	date2vars_monthly, newdate(date) year_var(v2) month_var(v3)
	rename v1 id
	drop if date<ym(2007,1)
	duplicates drop
	bys id date: egen TI 	   = total(v4)
	bys id date: egen pRP 	   = total(v5)
	bys id date: egen pRT 	   = total(v6)
	bys id date: egen reld     = total(v7)
	bys id date: egen bhijo	   = total(v8)
	bys id date: egen ch_f_cot =   max(v9)
	bys id date: egen ch_v_cot = total(v10)
	bys id date: egen ch_f_RP  =   max(v11)
	bys id date: egen ch_v_RP  = total(v12)
	bys id date: egen ch_f_RT  =   max(v13)
	bys id date: egen ch_v_RT  = total(v14)
	bys id date: egen ch_f_mtc =   max(v15)
	bys id date: egen ch_v_mtc = total(v16)
	bys id date: egen I_0TI    =   max(v17)
	bys id date: egen I_maxTI  =   max(v18)
	bys id date: egen I_0RP    =   max(v19)
	bys id date: egen I_0RT    =   max(v20)
	bys id date: egen I_0eld   =   max(v21)
	bys id date: egen I_0bhijo =   max(v22)
    bys id date: egen I_0cvcot =   max(v23)
    bys id date: egen I_0cvRP  =   max(v24)
    bys id date: egen I_0cvRT  =   max(v25)
	bys id date: egen I_0cvmtc =   max(v26)
	drop v*
	duplicates drop
	isid id date
	label var TI "Taxable income" //drop if date == date[_n-1] & TI==.
	save "$general/raw/clean_pre_TI.dta", replace
end

capture program drop database_cav
program              database_cav
	import delim "$data/hpa/informacion_mensual_cav.csv", delim(";") clear
	date2vars_monthly, newdate(date) year_var(v2) month_var(v3)
	rename v1 id
	bys id date: egen cav_dep = total(v4)
	bys id date: replace cav_dep=. if cav_dep==0 & v7==0
	bys id date: egen cav_wit = total(v5)
	bys id date: replace cav_wit=. if cav_wit==0 & v8==0
	gen cav=1
	keep id date cav*
	duplicates drop
	isid date id
	save "$general/raw/clean_pre_cav.dta", replace
end

capture program drop database_fees
program              database_fees
	qui capture do "$general/code/clean_pre_variable_fee.do"
	date_repl_monthly, date_var(fecha)
	rename fecha date
	label var 	date "Month"
	replace afp_all="pli" if afp_all=="pla"
	replace afp_all="prv" if afp_all=="pro"
	keep if date>=ym(2007,1) & date<ym(2014,1)
	drop if ch_var==.
	drop if afp_all=="mod" & date==ym(2010,7)
	save "$general/raw/clean_pre_fees_custom.dta", replace
end

capture program drop database_return
program              database_return
	qui capture do "$general/code/clean_pre_share_value.do"
	use  "$general/raw/clean_sharevalue.dta", clear
	drop if date>=ym(2014,1)
	//return_min
	save "$general/raw/clean_pre_returns.dta", replace
end

capture program drop return_min
program              return_min
	forvalues f=1/5 {
		gen minret3m_r`f' = r`f'
			forvalues i=1/2 {
			replace minret3m_r`f' = cond(minret3m_r`f'[_n]>r`f'[_n-`i'],r`f'[_n-`i'],minret3m_r`f'[_n])
		}
		gen minret3ml_r`f' = r`f'
			forvalues i=1/2 {
			replace minret3ml_r`f' = cond(minret3ml_r`f'[_n-1]>r`f'[_n-1-`i'],r`f'[_n-1-`i'],minret3ml_r`f'[_n-1])
		}
	}
end

main
