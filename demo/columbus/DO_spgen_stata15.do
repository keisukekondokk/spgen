/*************************************************
** (C) Keisuke Kondo
** Uploaded Date: November 06, 2015
** Update Date: June 03, 2021
**
** [NOTES]
** ssc install esttab
** ssc install spgen
*************************************************/


/*************************************************
** Dataset
** 
** 
*************************************************/

** Load Dataset
import excel "data/columbus.xlsx", sheet("columbus") firstrow clear
save "data/columbus.dta", replace

** Load Dataset
use "data/columbus.dta", clear

** spset without shapefiles (stata 15 or later)
spset NEIG, coord(x_cntrd y_cntrd) coordsys(latlong)
describe

/*************************************************
** Spatial Weight Matrix
** 
*************************************************/

** Spatial Weight Matrix 
spmatrix create idistance W_idist1, replace normalize(row)
spmatrix summarize W_idist1


/*************************************************
** Spatial Weight Matrix using spgen
** 
*************************************************/

** Spatial Weight Matrix using spgen
** Export Spatial Weight Matrix
spgen NEIG, lat(y_cntrd) lon(x_cntrd) swm(pow 1) dunit(km) dist(.) replace
return list

** Obtain Distance Matrix from r()
matrix mD = r(D) + r(D)'

** Make Spatial Weight Matrix
** Mata is used to make SWM.
** You can change a distance decay parameter (currently, 4).
forvalues i = 2(2)10 {
	mata: mD = st_matrix("mD")
	mata: mDI= mD:^(-`i')
	mata: _diag(mDI,0)
	mata: mW = mDI :/ rowsum(mDI)

	** ID
	putmata vID = _ID, replace

	** Include SWM using spmatrix 
	** normalize(none) because its is done in mata
	spmatrix spfrommata W_idist`i' = mW vID, replace normalize(none)
}


/*************************************************
** Moran Scatter Plot
** 
** 
*************************************************/

** Standardize
egen std_CRIME = std(CRIME)

** Spatial Lag
forvalues i = 2(2)10 {
	spgenerate splag1_std_CRIME_p_d`i' = W_idist`i'*std_CRIME
}

** Moran's I
local VAR splag1_std_CRIME_p_d4 std_CRIME
reg `VAR', nocons

** Moran Scatter Plot
local VAR splag1_std_CRIME_p_d4 std_CRIME
twoway (scatter `VAR', ms(Oh) msize(large)) ///
	(lfit `VAR', lw(thick) est(nocon)), ///
	ytitle("{it:Wz}", tstyle(size(large))) ///
	xtitle("{it:z}", tstyle(size(large)) height(7)) ///
	ylabel(-2(1)2, format(%2.1f) grid ang(h) labsize(large)) ///
	xlabel(-2(1)2, format(%2.1f) grid labsize(large)) ///
	aspect(1) ///
	legend(off) ///
	graphregion(color(white) fcolor(white))
graph export "fig/FIG_columbus_msp_d4_by_spgenerate.eps", replace

** Moran Scatter Plot
local VAR splag1_std_CRIME_p_d8 std_CRIME
twoway (scatter `VAR', ms(Oh) msize(large)) ///
	(lfit `VAR', lw(thick) est(nocon)), ///
	ytitle("{it:Wz}", tstyle(size(large))) ///
	xtitle("{it:z}", tstyle(size(large)) height(7)) ///
	ylabel(-2(1)2, format(%2.1f) grid ang(h) labsize(large)) ///
	xlabel(-2(1)2, format(%2.1f) grid labsize(large)) ///
	aspect(1) ///
	legend(off) ///
	graphregion(color(white) fcolor(white))
graph export "fig/FIG_columbus_msp_d8_by_spgenerate.eps", replace


/*************************************************
** Estimation of Spatial Augtoregressive Model
** IV/GMM Estimation
** y = rho*Wy + XB + u
** Delta = 4, 6, 8, 10
** Sp commands of Stata ver. 15 or later
*************************************************/

** Spatial Lag
foreach VAR in CRIME INC HOVAL {
	forvalues i = 2(2)10 {
		spgenerate splag1_`VAR'_p_d`i' = W_idist`i'*`VAR'
		spgenerate splag2_`VAR'_p_d`i' = W_idist`i'*splag1_`VAR'_p_d`i'
		spgenerate splag3_`VAR'_p_d`i' = W_idist`i'*splag2_`VAR'_p_d`i'
	}
}


foreach i of numlist 2 4 6 8 10 {
	disp ""
	disp "+++++++++++++++++++++++++++++++++++++++"
	disp "SWM: delta = `i'"
	disp "+++++++++++++++++++++++++++++++++++++++"

	**Variable
	local YVAR CRIME
	local WYVAR splag1_CRIME_p_d`i'
	local XVAR INC HOVAL 
	local IVVAR splag1_INC_p_d`i' splag2_INC_p_d`i' splag1_HOVAL_p_d`i' splag2_HOVAL_p_d`i'

	** OLS: y = XB + u
	reg `YVAR' `XVAR', robust
	est store reg_ols_d`i'

	** OLS: y = rho*Wy + XB + u
	reg `YVAR' `WYVAR' `XVAR', robust
	est store spreg_ols_d`i'

	** ML: y = rho*Wy + XB + u
	spregress `YVAR' `XVAR', ml dvarlag(W_idist`i')
	est store spreg_ml_r_d`i'

	** 2SLS Robust: y = rho*Wy + XB + u, IV=WX, W2X
	spregress `YVAR' `XVAR', gs2sls dvarlag(W_idist`i') hetero impower(2)
	est store spreg_iv_r_d`i'

	** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
	ivregress 2sls `YVAR' (`WYVAR'  = `IVVAR') `XVAR', robust
	est store spreg_gmm_d`i'
}


** Estimation Results
foreach i of numlist 2 4 6 8 10 {
	disp ""
	disp ""
	disp "+++++++++++++++++++++++++++++++++++++++"
	disp "SWM: delta = `i'"
	disp "+++++++++++++++++++++++++++++++++++++++"

	esttab reg_ols_d`i' spreg_ols_d`i' spreg_ml_r_d`i' spreg_iv_r_d`i' spreg_gmm_d`i', ///
		b(%12.3f) se(%12.3f) ///
		keep(*CRIME splag* _cons INC HOVAL) ///
		order(splag* _cons INC HOVAL) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		scalars(r2_a rkf jp) ///
		sfmt(%12.3f) ///
		nogaps
}
