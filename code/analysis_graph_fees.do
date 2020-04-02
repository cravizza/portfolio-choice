*** Graph of firms' percentage commission
clear
global data "../../..\Data/SP"
global general "../"

use "$general/raw/comporc_long.dta", replace
* Graph
format date %td
gen date2=mofd(date)
format date2 %tm
drop date
rename date2 date
label var 	comporc "Variable fee (% of taxable income)"
label var 	date "Month"
gen     	afp = "afp"
replace 	afp = "AFP Aporta"		if firm=="apo"
replace     afp = "AFP Armoniza"    if firm=="arm"
replace    	afp = "AFP Banguardia"  if firm=="bgd"
replace    	afp = "AFP Bannuestra"  if firm=="bnn"
replace 	afp = "AFP Bansander"	if firm=="ban"
replace 	afp = "AFP Capital"		if firm=="cap"
replace 	afp = "AFP Cuprum"		if firm=="cup"
replace 	afp = "AFP Habitat"		if firm=="hab"
replace 	afp = "AFP Magister"    if firm=="mag"
replace 	afp = "AFP Modelo"		if firm=="mod"
replace 	afp = "AFP Plan Vital"	if firm=="pla"
replace 	afp = "AFP Provida"		if firm=="pro"
replace 	afp = "AFP Santa Maria"	if firm=="san"
replace 	afp = "AFP SummaBansander" if firm=="sum"
encode 		afp, gen(afp_name)
xtset 		afp_name date

* Graph short
sum comporc if date>=ym(2007,1) & date<ym(2014,1), det
local median_fee = `r(p50)'
di "median fee over 2007 to 2013 is `median_fee'"
xtline comporc if date>=ym(2007,1) & date<ym(2014,1), ov ylabel(#12, labs(small)) ymtick(0.005(0.005)0.035) ///
	   legend(c(3) size(small)) tline(2010m8 2012m8) tlabel(2007m1(12)2013m12, labs(small)) ///
	   title("Variable fees and auctions") ///
       note("Note: Vertical lines indicate when new fees from auction processes begin." ///
	   "Source: own elaboration with data from www.spensiones.cl")
graph export "$general\output\perc_comm_short.png", replace
* Graph
xtline comporc if date>=ym(2007,1), ov ylabel(#5, labs(small)) ymtick(0(0.005)0.04) ///
	   legend(c(3) size(small)) tline(2010m8 2012m8 2014m8) tlabel(2007m1(12)2016m2, labs(small)) ///
	   title("Variable fees and auctions") ///
       note("Note: Vertical lines indicate when new fees from auction processes begin." ///
	   "Source: own elaboration with data from www.spensiones.cl")
graph export "$general\output\perc_comm.png", replace
* Graph long
xtline comporc , ov ylabel(#5, labs(small)) ymtick(0(0.005)0.04) ///
	   legend(c(3) size(small)) tline(2010m8 2012m8) tlabel(2000m1(24)2015m12, labs(small)) ///
	   title("Variable fees and auctions") ///
       note("Note: Vertical lines indicate when auction processes occur." ///
	   "Source: own elaboration with data from www.spensiones.cl")
graph export "$general\output\perc_comm_long.png", replace
