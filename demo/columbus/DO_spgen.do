/*************************************************
** (C) Keisuke Kondo
** Uploaded Date: November 06, 2015
** Update Date: June 03, 2021
**
** [NOTES]
** ssc install esttab
** ssc install spgen
** ssc install ivreg2
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

** Generate Spatial Lagged Variables: CRIME, INC, HOVAL
local VAR = "CRIME INC HOVAL"
forvalue i = 4(2)10 {
	forvalue j = 1(1)3 {
		spgen `VAR', lat(y_cntrd) lon(x_cntrd) swm(pow `i') dist(.) dunit(km) o(`j') suffix(_d`i')
	}
}

/*************************************************
** Moran Scatter Plot
** 
** 
*************************************************/

** Standardize
egen std_CRIME = std(CRIME)

** Spatially Lagged 
forvalue i = 4(2)10 {
	spgen std_CRIME, lat(y_cntrd) lon(x_cntrd) swm(pow `i') dist(.) dunit(km) suffix(_d`i')
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
graph export "fig/FIG_columbus_msp_d4.eps", replace

** Moran's I
local VAR splag1_std_CRIME_p_d8 std_CRIME
reg `VAR', nocons

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
graph export "fig/FIG_columbus_msp_d8.eps", replace


/*************************************************
** Descriptive Statistics
** 
** 
*************************************************/

sum CRIME INC HOVAL splag1_CRIME_p_d8 splag1_INC_p_d8 splag1_HOVAL_p_d8

/*************************************************
** Estimation of Spatial Augtoregressive Model
** IV/GMM Estimation
** y = rho*Wy + XB + u
** Delta = 4, 6, 8, 10
** Classic commands of Stata using spgen
*************************************************/
forvalue i = 4(2)10 {
	disp ""
	disp "+++++++++++++++++++++++++++++++++++++++"
	disp "SWM: delta = `i'"
	disp "+++++++++++++++++++++++++++++++++++++++"

	**Variable
	local YVAR CRIME
	local WYVAR splag1_CRIME_p_d`i'
	local XVAR INC HOVAL 
	local WXVAR splag1_INC_p_d`i' splag1_HOVAL_p_d`i'
	local IVVAR splag1_INC_p_d`i' splag2_INC_p_d`i' splag3_INC_p_d`i' splag1_HOVAL_p_d`i' splag2_HOVAL_p_d`i' splag3_HOVAL_p_d`i'

	** OLS: y = XB + u
	reg `YVAR' `XVAR', robust
	est store reg_ols_d`i'

	** OLS: y = rho*Wy + XB + u
	reg `YVAR' `WYVAR' `XVAR', robust
	est store spreg_ols_d`i'

	** 2SLS Robust: y = rho*Wy + XB + u, IV=WX, W2X
	ivregress 2sls `YVAR' (`WYVAR'  = `IVVAR') `XVAR', robust
	est store spreg_iv_r_d`i'
	estat firststage
	estat overid

	** GMM Robust: y = rho*Wy + XB + u, IV=WX, W2X
	ivregress gmm `YVAR' (`WYVAR'  = `IVVAR') `XVAR', igmm wmat(robust)
	est store spreg_gmm_d`i'
	estat firststage
	estat overid

	** OLS: y = XB + WXG + u
	reg `YVAR' `XVAR' `WXVAR', robust
	est store spreg_ols_wx_d`i'
}

** Estimation Results
forvalue i = 4(2)10 {
	disp ""
	disp "+++++++++++++++++++++++++++++++++++++++"
	disp "SWM: delta = `i'"
	disp "+++++++++++++++++++++++++++++++++++++++"
	esttab reg_ols_d`i' spreg_ols_d`i' spreg_iv_r_d`i' spreg_gmm_d`i' spreg_ols_wx_d`i', ///
		b(%12.3f) se(%12.3f) ///
		order(splag* _cons INC HOVAL) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		scalars(r2_a rkf jp) ///
		sfmt(%12.3f) ///
		nogaps
}
