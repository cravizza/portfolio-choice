*** Clean data for firms' percentage commission
import excel "$data/fees/estructura_comisiones.xls", ///
		cellrange(A2:AI351) firstrow case(lower) clear
replace planvital = w if planvital==.
replace planvital = x if planvital==.
replace qualitas = ac if qualitas==.
replace aportafomenta = aporta if aportafomenta==.
replace summabansander = summa if summabansander==.
drop alameda w x ac aporta summa
* some variables have same 3 first letters
rename banguardia bnguardia
rename bannuestra bnnuestra
rename proteccion prtccion
rename santamaria stamaria
foreach v of varlist _all {
	local vartype: type `v'
	*if substr("`vartype'",1,3)=="flo" {
	if substr("`vartype'",1,3)=="int" {
			continue
	}
	else {
			local newname = substr("`v'",1,3)
			rename `v' afp_`newname'
	}
}
reshape long afp_, s i(fecha) j(afp_all)
rename afp_ ch_var
label var 	ch_var "Variable fee (% of taxable income)"
label var 	fecha "Month"
save "$general/raw/clean_fees.dta", replace
