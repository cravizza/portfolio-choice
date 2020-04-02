clear all
global data "../../../Data/SP"
global general "../"
set more off

program main
	qui capture do "$general/tools/tools_database.do"
	*qui do "$general/code/clean_fyf.do"
	local date : di %tdCCYY-NN-DD date(c(current_date),"DMY")
	log using "$general/log/analysis_fyf_follower_corr`date'.log", replace
	data_fyf_follower 
	data_fyf_sh_sw_rec
	tables_follower_corr
	log close
end

program data_fyf_follower
	* Setup sample at the individual level
	use "$general/output/derived_hpa.dta", clear
	keep if date>=ym(2011,6) & rec==1
	rename gender sex
	rename TI_a50 ti
	rename TI_quart tiq
	by ID: egen ad = mean(age_def)
	replace ad = round(ad)
	la var ad  "Age group"
	la def ad  2 "Young" 3 "Middle age" 4 "Old"
	la val ad ad
	duplicates drop ID rec N_sw_fund N_sw_fyf fyf_follower sex ti tiq ad, force
	isid ID
	egen tag = group(ID)
	keep ID rec N_sw_fund N_sw_fyf fyf_follower sex ti tiq ad tag
//	save "$general/output/tab_ind_level.dta", replace 
	save "$general/output/tab_fyf_follower.dta", replace
end

program data_fyf_sh_sw_rec
	* Setup sample at the recommendation/individual level
	use "$general/output/derived_hpa.dta", clear
	keep if date>=ym(2011,6) & rec==1 & fyf_follower_t==1 & !mi(n_sw_fyf) //gen tag = (rec==1 & fyf_follower_t==1 & !mi(n_sw_fyf))
	assert !mi(n_rec) & !mi(n_sw_fyf) & !mi(N_sw_fyf) & !mi(sw_fyf)
	gen _temp = -n_rec
	bys ID (_temp): gen fyf_rec_left = _n //if tag==1
	gen fyf_sw_left = N_sw_fyf - n_sw_fyf + sw_fyf //if tag==1
	sort ID date
	isid ID fyf_rec_left
	gen fyf_sh_sw_rec = fyf_sw_left/fyf_rec_left
	
	rename gender sex
	rename TI_a50 ti
	rename TI_quart tiq
	by ID: egen ad = mean(age_def)
	replace ad = round(ad)
	la var ad  "Age group"
	la def ad  2 "Young" 3 "Middle age" 4 "Old"
	la val ad ad
	egen tag = group(ID n_rec)
	keep ID rec n_rec *fyf* sex ti tiq ad tag
//	save "$general/output/tab_ind_rec_level.dta", replace  
	save "$general/output/tab_fyf_sh_sw_rec.dta", replace
end
	
program              tables_follower_corr
    ************************************************************************************************
	* Subsample correlations & Testing difference	
	foreach depvar in fyf_follower fyf_sh_sw_rec {
		* Use data at the relevant level
		use "$general/output/tab_`depvar'.dta",  clear
		foreach var of varlist sex ad ti {
			local label_`var': variable label `var'
			qui levelsof `var', local(levels)   //di `levels'
			local words: word count `levels' //di `words'
				forvalues w = 1/`words' {
					local j: word `w' of `levels'
					qui reg `depvar' if `var'==`j' , vce(cluster tag)
					local b_`depvar'_`var'_`j' =  _b[_cons]
					local s_`depvar'_`var'_`j' = _se[_cons]
					local label_`var'_`j': label (`var') `j'
				}
			qui reg `depvar' i.`var' , vce(cluster tag) 
			forvalues w = 2/`words' {
				local j: word `w' of `levels'
				local p_`depvar'_`var'_`j' : disp %5.4f ((2*ttail(e(df_r), abs(_b[`j'.`var']/_se[`j'.`var']))))
			}
		}
		scalar_txt, number(`b_`depvar'_sex_1'*100) filename(`depvar'_men) decimal(1)
		scalar_txt, number(`b_`depvar'_ti_1'*100)  filename(`depvar'_tih) decimal(1)
	}
	* Create table
	file open myfile using "$general\output\table_follower_corr.txt", write replace
	file write myfile "\begin{threeparttable}" ///
					_n "\begin{tabular}{l|cc|c|cc|c} \hline\hline"  ///
					_n " & \multicolumn{3}{c|}{Followers} & \multicolumn{3}{c}{Following} \\ \hline" ///
					_n "`title' & Coeff. & SE & Diff.p-value & Coeff. & SE & Diff.p-value \\ "  ///
					_n " Subsamples & (1) & (2) & (3) & (4) & (5) & (6) \\ \hline"
	foreach var of varlist sex ad ti {
		file write myfile _n "`label_`var'' & & & & & & \\"
		qui levelsof `var', local(levels)  //di `levels'
		local words: word count `levels' //di `words'
		forvalues w = 1/`words' {
			local j: word `w' of `levels'
			file write myfile _n  "\hspace{0.3cm} `label_`var'_`j''   & " ///
								%5.4f (`b_fyf_follower_`var'_`j'') "  & (" ///
								%5.4f (`s_fyf_follower_`var'_`j'') ") & " ///
									"`p_fyf_follower_`var'_`j''" "& " ///
								%5.4f (`b_fyf_sh_sw_rec_`var'_`j'') " & (" ///
								%5.4f (`s_fyf_sh_sw_rec_`var'_`j'') ") & " ///
									"`p_fyf_sh_sw_rec_`var'_`j''" " \\"
		}
	}
	file write myfile _n "\hline\hline" _n "\end{tabular}" 
	file close myfile
	************************************************************************************************
	* All interactions
	local        main_vars _Isex_1      _Iti_1       _Iad_3 	  _Iad_4
	local interaction_vars _IsexXti_1_1 _IsexXad_1_3 _IsexXad_1_4 _ItiXad_1_3 _ItiXad_1_4
	local    constant_vars _cons
	foreach depvar in fyf_follower fyf_sh_sw_rec {
		use "$general/output/tab_`depvar'.dta",  clear
		qui xi: reg `depvar' i.sex*i.ti i.sex*i.ad i.ti*i.ad, vce(cluster tag)
		foreach vlist in main interaction constant {
			foreach  var in ``vlist'_vars' {
				local b_`depvar'_`var' =  _b[`var']
				local s_`depvar'_`var' = _se[`var']
				local p_`depvar'_`var' =  ((2*ttail(e(df_r), abs(_b[`var']/_se[`var']))))
				di "`var' " `b_`depvar'_`var'' " , " `s_`depvar'_`var'' " , " `p_`depvar'_`var''
			}
		}
		scalar_txt, number(`b_`depvar'__IsexXti_1_1'*100)  filename(`depvar'_mentih) decimal(1)
		scalar_txt, number(`b_`depvar'__IsexXad_1_4'*100)  filename(`depvar'_menold) decimal(1)
		reg `depvar'   sex##ti   i.ad##sex   i.ad##ti , vce(cluster tag)
	}
	local	l_Isex_1	  "Male"
	local	l_Iti_1       "Above 50th percentile"
	local 	l_Iad_3 	  "Middle age"
	local 	l_Iad_4		  "Old"
	local 	l_IsexXti_1_1 "Male\#Above 50th"
	local 	l_IsexXad_1_3 "Male\#Middle age"
	local 	l_IsexXad_1_4 "Male\#Old"
	local 	l_ItiXad_1_3  "Above 50th\#Middle age"
	local 	l_ItiXad_1_4  "Above 50th\#Old"
	
	file open myfile using "$general\output\table_follower_corr_int.txt", write replace
	file write myfile  "\begin{threeparttable}" _n "\begin{tabular}{l|ccc|ccc} \hline\hline"   ///
					_n " & \multicolumn{3}{c|}{Followers} & \multicolumn{3}{c}{Following} \\ \hline" ///
					_n " & Coeff. & SE & p-value & Coeff. & SE & p-value \\ "  ///
					_n " & (1) & (2) & (3) & (4) & (5) & (6) \\ \hline" ///
					_n "Constant & " ///
							%5.4f (`b_fyf_follower__cons')  "  & (" ///
							%5.4f (`s_fyf_follower__cons')  ") &  " ///
							%5.4f (`p_fyf_follower__cons')  "  &  " ///
							%5.4f (`b_fyf_sh_sw_rec__cons') "  & (" ///
							%5.4f (`s_fyf_sh_sw_rec__cons') ") &  " ///
							%5.4f (`p_fyf_sh_sw_rec__cons') "  \\ "
	file write myfile	_n "Main effects & & & & & & \\"
	foreach  var in `main_vars' {
		file write myfile	_n 	"\hspace{0.3cm}  `l`var''  & " ///
								%5.4f (`b_fyf_follower_`var'')  "  & (" ///
								%5.4f (`s_fyf_follower_`var'')  ") &  " ///
								%5.4f (`p_fyf_follower_`var'')  "  &  " ///
								%5.4f (`b_fyf_sh_sw_rec_`var'') "  & (" ///
								%5.4f (`s_fyf_sh_sw_rec_`var'') ") &  " ///
								%5.4f (`p_fyf_sh_sw_rec_`var'') "  \\ "
	}
	file write myfile	_n "Interactions & & & & & & \\"
	foreach  var in `interaction_vars' {
		file write myfile	_n 	"\hspace{0.3cm} `l`var'' & " ///
								%5.4f (`b_fyf_follower_`var'')  "  & (" ///
								%5.4f (`s_fyf_follower_`var'')  ") &  " ///
								%5.4f (`p_fyf_follower_`var'')  "  &  " ///
								%5.4f (`b_fyf_sh_sw_rec_`var'') "  & (" ///
								%5.4f (`s_fyf_sh_sw_rec_`var'') ") &  " ///
								%5.4f (`p_fyf_sh_sw_rec_`var'') "  \\ "
	}	
											
	file write myfile  _n "\hline\hline" _n "\end{tabular}"
	file close myfile					
	************************************************************************************************
end	

main

