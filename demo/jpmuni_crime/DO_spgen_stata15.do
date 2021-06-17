/*************************************************
** (C) Keisuke Kondo
** Uploaded Date: November 06, 2015
** 
*************************************************/

log using "log/LOG_spgen_stata15.smcl", replace

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
gen double pop = labor + nonlabor
gen crimer = crime / pop * 1000

** Standardize
egen std_crimer = std(crimer)

** 
gen ur = unemp / labor * 100
gen lnpcinc = log(inc / incpop)

** Generate Spatial Lagged Variables: 
spgen _ID, lon(lon) lat(lat) dist(.) dunit(km) swm(pow 1) replace

** Obtain Distance Matrix from r()
matrix mD = r(D) + r(D)'

** SWM
mata: mD = st_matrix("mD")
mata: mDI= mD:^(-4)
mata: _diag(mDI, 0)
mata: mW = mDI :/ rowsum(mDI)

** ID
putmata vID = _ID, replace

** Include SWM using spmatrix 
** normalize(none) because its is done in mata
spmatrix spfrommata W_idist4 = mW vID, replace normalize(none)

**
spgenerate wcrimer = W_idist4*crimer
spgenerate wstd_crimer= W_idist4*std_crimer

** 
tab id_pref, gen(d_pref)

** Spatial Lag
local VARLIST ur lnpcinc 
foreach VAR in `VARLIST' {
	spgenerate w`VAR' = W_idist4*`VAR'
	spgenerate w2`VAR' = W_idist4*w`VAR'
	spgenerate w3`VAR' = W_idist4*w2`VAR'
}

ds d_pref*
local VARLIST `r(varlist)'
foreach VAR of varlist `VARLIST' {
	spgenerate w`VAR' = W_idist4*`VAR'
	spgenerate w2`VAR' = W_idist4*w`VAR'
	spgenerate w3`VAR' = W_idist4*w2`VAR'
}


/*************************************************
** Moran Scatter Plot
** 
** 
*************************************************/

** Scatter Plot
local VAR wstd_crimer std_crimer
twoway ///
	(scatter `VAR', ms(Oh)) ///
	(lfit `VAR', est(nocon)), ///
	ytitle("W crime rate", tstyle(size(medlarge))) ///
	xtitle("z", tstyle(size(medlarge)) height(7)) ///
	ylabel(, format(%2.1f) grid ang(h) labsize(medlarge)) ///
	xlabel(, format(%2.1f) grid labsize(medlarge)) ///
	aspect(1) legend(off) graphregion(color(white) fcolor(white))
graph export "fig/FIG_jpmuni_crime_msp_d4_by_spgenerate.eps", replace


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

** ML
spregress crimer ur lnpcinc i.id_pref, ml dvarlag(W_idist4)
est store spreg_ml

** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
spregress crimer ur lnpcinc i.id_pref, gs2sls dvarlag(W_idist4) impower(3) hetero 
est store spreg_gs2sls

** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
spregress crimer ur lnpcinc i.id_pref, gs2sls ivarlag(W_idist4: ur lnpcinc)
est store spreg_wxvar

** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
spregress crimer ur lnpcinc i.id_pref, ml dvarlag(W_idist4) errorlag(W_idist4)
est store spreg_ml_sac

** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
spregress crimer ur lnpcinc i.id_pref, gs2sls dvarlag(W_idist4) errorlag(W_idist4)
est store spreg_gs2sls_sac


** Estimation Results
esttab spreg_ml spreg_gs2sls spreg_wxvar spreg_ml_sac spreg_gs2sls_sac, ///
	b(%12.3f) se(%12.3f) ///
	drop(*var(*)* *id_pref*) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	scalars(r2_a rkf jp) ///
	sfmt(%12.3f) ///
	nogaps


** 
log close
