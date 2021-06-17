/*************************************************
** (C) Keisuke Kondo
** Uploaded Date: November 06, 2015
** 
*************************************************/

log using "log/LOG_spgen.smcl", replace

/*************************************************
** Dataset
** 
** 
*************************************************/

**
set matsize 10000

** 
use "data/income2005.dta", clear 

** 
merge 1:1 id_muni using "data/income_pop2005.dta", keepusing(incpop)
drop _merge

** 
merge 1:1 id_muni using "data/labor2005.dta", keepusing(labor emp unemp nonlabor)
drop _merge

** 
merge 1:1 id_muni using "data/crime2006.dta", keepusing(crime)
drop _merge

** Tokyo 23 Wards
replace id_muni = 13100 if id_muni >= 13101 & id_muni <= 13123

** Tokyo 23 Wards
local VARLIST = "inc incpop labor emp unemp nonlabor crime"
foreach VAR in `VARLIST' {
	by id_muni, sort: egen total_`VAR' = total(`VAR')
	replace `VAR' = total_`VAR'
	drop total_`VAR'
}

** 
replace name_muni = "東京都特別区" if id_muni == 13100

** 
duplicates drop id_muni, force

** 
save "data/japan_muni2005.dta", replace 


/*************************************************
** Dataset
** 
** 
*************************************************/

** Load Dataset
use "data/DTA_japan_muni.dta", clear

** 
gen id_muni_old = id_muni
replace id_muni = 13100 if id_muni >= 13101 & id_muni <= 13123

** Tokyo 23 Wards
local VARLIST area iarea
foreach VAR in `VARLIST' {
	by id_muni, sort: egen total_`VAR' = total(`VAR')
	replace `VAR' = total_`VAR'
	drop total_`VAR'
}

** 
drop if id_muni_old >= 13102 & id_muni_old <= 13123
drop id_muni_old
	
** Lon Lat
merge 1:1 id_muni using "data/japan_muni2005.dta"
drop if _merge == 2
drop _merge

** SPSET
spset id_muni, coord(lon lat)

**
gen id_pref = floor(id_muni/1000), before(id_muni)

**
gen id_region = .
replace id_region = 1 if id_pref >= 1 & id_pref <= 7
replace id_region = 2 if id_pref >= 8 & id_pref <= 14
replace id_region = 3 if id_pref >= 15 & id_pref <= 20
replace id_region = 4 if id_pref >= 21 & id_pref <= 24
replace id_region = 5 if id_pref >= 25 & id_pref <= 30
replace id_region = 6 if id_pref >= 31 & id_pref <= 35
replace id_region = 7 if id_pref >= 36 & id_pref <= 39
replace id_region = 8 if id_pref >= 40 & id_pref <= 47
tab id_region, gen(d_region)

**
gen pop = labor + nonlabor
gen crimer = crime / pop * 1000

** Standardize
egen std_crimer = std(crimer)

** 
gen ur = unemp / labor * 100
gen lnpcinc = log(inc / incpop)

** Generate Spatial Lagged Variables: 
local VARLIST crimer std_crimer ur lnpcinc
spgen `VARLIST', lon(lon) lat(lat) dist(.) dunit(km) swm(pow 4) replace
foreach VAR in `VARLIST' {
	rename splag1_`VAR'_p w`VAR'
}

** Generate Spatial Lagged Variables: 2nd order
local VARLIST ur lnpcinc
spgen `VARLIST', lon(lon) lat(lat) dist(.) dunit(km) swm(pow 4) order(2) replace
foreach VAR in `VARLIST' {
	rename splag2_`VAR'_p w2`VAR'
}

** Generate Spatial Lagged Variables: 3rd order
local VARLIST ur lnpcinc
spgen `VARLIST', lon(lon) lat(lat) dist(.) dunit(km) swm(pow 4) order(3) replace
foreach VAR in `VARLIST' {
	rename splag3_`VAR'_p w3`VAR'
}


/*************************************************
** Moran Scatter Plot
** 
** 
*************************************************/

** Scatter Plot
local VAR wstd_crimer std_crimer
reg `VAR', nocons
twoway ///
	(scatter `VAR', ms(Oh)) ///
	(lfit `VAR', est(nocon) lw(thick)), ///
	yline(0) ///
	xline(0) ///
	ytitle("W crime rate", tstyle(size(medlarge))) ///
	xtitle("crime rate", tstyle(size(medlarge)) height(7)) ///
	ylabel(-2(2)6, format(%2.1f) grid ang(h) labsize(medlarge)) ///
	xlabel(-2(2)6, format(%2.1f) grid labsize(medlarge)) ///
	aspect(1) legend(off) graphregion(color(white) fcolor(white))
graph export "fig/FIG_jpmuni_crime_msp_d4.eps", replace

/*************************************************
** Descriptive Statistics
** 
** 
** 
*************************************************/

sum crimer ur lnpcinc wcrimer wur wlnpcinc


/*************************************************
** Estimation of Spatial Augtoregressive Model
** IV/GMM Estimation
** y = rho*Wy + XB + u
** Delta = 4
*************************************************/

** OLS: y = XB + u
reg crimer ur lnpcinc i.id_pref, robust
est store reg

** OLS: y = rho*Wy + XB + u
reg crimer wcrimer ur lnpcinc i.id_pref, robust
est store reg_sp

** 2SLS Robust: y = rho*Wy + XB + u, IV=WX, W2X
ivregress 2sls crimer (wcrimer = wur w2ur w3ur wlnpcinc w2lnpcinc w3lnpcinc) ur lnpcinc i.id_pref, robust
estat firststage
estat overid
est store ivreg_2sls_sp

** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
ivregress gmm crimer (wcrimer = wur w2ur w3ur wlnpcinc w2lnpcinc w3lnpcinc) ur lnpcinc i.id_pref, igmm wmat(robust)
estat firststage
estat overid
est store ivreg_gmm_sp

** OLS: y = rho*Wy + XB + u
reg crimer ur lnpcinc wur wlnpcinc i.id_pref, robust
est store reg_wxvar


** Estimation Results
esttab reg reg_sp ivreg_2sls_sp ivreg_gmm_sp reg_wxvar, ///
	b(%12.3f) se(%12.3f) ///
	drop(*id_pref*) ///
	order(wcrimer) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	scalars(r2_a rkf jp) ///
	sfmt(%12.3f) ///
	nogaps

	
** 
log close
