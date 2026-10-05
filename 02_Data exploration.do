version 16
clear all
set more off

*=============================================================================*
* SAKERNAS CAPSTONE LABOR_POLARIZATION
* (2) Data Exploration - Individual level
* Programmer: Tahtia Sazwara
*=============================================================================*

local workbook "$output/Sakernas_summary_stats.xlsx"

local dataset "$output/sakernas_recons_2000_2024.dta"

use "`dataset'", clear
	
/*=============================================================================*
* Correlation tables
*=============================================================================*

preserve

keep if inrange(_age, 15, 64)

set seed 1906317354
sample 1

capture drop yobdummy_* edudummy* famstatdummy* ///
    empdummy* kblidummy*

quietly tab _yobcohort, gen(yobdummy_)
quietly tab _educohort, gen(edudummy)
quietly tab _fam_stat, gen(famstatdummy)

*--------------------------------------------------------------------------
* Table 1: All individuals
*--------------------------------------------------------------------------

local corr_all ///
    _age _birthyear ///
    _is_rural _is_female _is_married _hh_n_children ///
    _laborforce _employed _unemployed ///
    yobdummy_* edudummy* famstatdummy*

quietly pwcorr `corr_all' [aw = _weight]

matrix corr_all = r(C)

putexcel set "`workbook'", ///
    sheet("Corr all persons", replace) modify

putexcel A1 = "Correlations among all individuals aged 15-64"
putexcel A3 = matrix(corr_all), names

*--------------------------------------------------------------------------
* Table 2: Employed individuals
*--------------------------------------------------------------------------

keep if _employed == 1

quietly tab _empltype, gen(empdummy)
quietly tab _kbli_harmonized, gen(kblidummy)

local corr_employed ///
    _age _birthyear ///
    _is_rural _is_female _is_married _hh_n_children ///
    _formal _informal _hoursworked _hourly_earnings ///
    yobdummy_* edudummy* famstatdummy* ///
    empdummy* kblidummy* ///
    _occ_high _occ_middle _occ_low _occ_missing

quietly pwcorr `corr_employed' [aw = _weight]

matrix corr_employed = r(C)

putexcel set "`workbook'", ///
    sheet("Corr employed", replace) modify

putexcel A1 = "Correlations among employed individuals aged 15-64"
putexcel A3 = matrix(corr_employed), names

restore

*/
*=============================================================================*
*  Figure 1: Occupation skill-shares among employed persons
*=============================================================================*

preserve

keep if inrange(_age, 15, 64) & _employed == 1 & inrange(_year, 2004, 2024)

collapse (mean) ///
    _occ_low _occ_middle _occ_high _occ_missing ///
    [pw = _weight], by(_year)

foreach v in _occ_low _occ_middle _occ_high _occ_missing {
    replace `v' = 100 * `v'
}

* Cumulative boundaries
gen double __zero = 0
gen double __one  = 100
gen double __cum_low = _occ_low
gen double __cum_middle = _occ_low + _occ_middle
gen double __cum_high = _occ_low + _occ_middle + _occ_high

sort _year

twoway ///
    rarea __zero __cum_low _year, color("$jpal_teal%80") ///
    || rarea __cum_low __cum_middle _year, color("$jpal_orange%90") ///
    || rarea __cum_middle __cum_high _year, color("$jpal_navy%85") ///
    || rarea __cum_high __one _year, color("$jpal_gray") ///
    title("Occupation-skill composition among employed persons") ///
    subtitle("Employed persons ages 15-64; survey-weighted") ///
    xtitle("Year") ///
    ytitle("Share of employed persons (%)") ///
    xlabel(2004(2)2024, angle(45)) ///
    ylabel(0(20)100, angle(horizontal)) ///
    yscale(range(0 100)) ///
    plotregion(margin(zero)) ///
    legend(order(1 "Low" 2 "Middle" 3 "High" ///
                 4 "Excluded/missing KBJI") ///
           rows(1) position(6)) ///
    graphregion(color(white)) ///
    name(figure1, replace)

restore

graph export "$individual_exploration/figure001_occupation_skill_shares.png", ///
    replace width(2400)
	

*=============================================================================*
*  Figure 4: Labour-market status over time
*=============================================================================*

use "`dataset'", clear

preserve 

keep if inrange(_age, 15, 30)
keep if inrange(_year, 2004, 2024)

gen byte lm_status = .

replace lm_status = 1 if _employed == 1
replace lm_status = 2 if missing(lm_status) & _unemployed == 1
replace lm_status = 3 if missing(lm_status) & ///
    _laborforce == 0 & _inschool == 1
replace lm_status = 4 if missing(lm_status) & ///
    _laborforce == 0 & _inschool == 0

* Exclude observations whose status cannot be identified
keep if inrange(lm_status, 1, 4) & !missing(_year, _weight)

gen byte share_working    = lm_status == 1
gen byte share_unemployed = lm_status == 2
gen byte share_school     = lm_status == 3
gen byte share_other_olf  = lm_status == 4

collapse (mean) share_working share_unemployed ///
    share_school share_other_olf [aw=_weight], by(_year)

replace share_working    = share_working * 100
replace share_unemployed = share_unemployed * 100
replace share_school     = share_school * 100
replace share_other_olf  = share_other_olf * 100

twoway ///
    (line share_working _year, sort lcolor("$jpal_navy") lwidth(medthick)) ///
    (line share_unemployed _year, sort lcolor("$jpal_orange") lwidth(medthick)) ///
    (line share_school _year, sort lcolor("$jpal_green") lwidth(medthick)) ///
    (line share_other_olf _year, sort lcolor("$jpal_gray") lwidth(medthick)), ///
    title("Labour-market status, 2004–2024") ///
    subtitle("Persons ages 15–30; survey-weighted") ///
    ytitle("Share of population (%)") ///
    xtitle("Year") ///
    ylabel(0(10)100) ///
    legend(order(1 "Working" 2 "Unemployed" ///
                 3 "In school" 4 "Other outside labour force") rows(1) position(6)) ///
    graphregion(color(white)) ///
    name(graph_lm_status, replace)

graph export "$individual_exploration/figure004_labor_over_time.png", ///
    replace width(2400)
	
restore

*=============================================================================*
*  Figure 5: Educational composition across birth cohorts
*=============================================================================*

preserve

keep if inrange(_age, 15, 64)
keep if inrange(_educohort, 1, 4)
keep if inrange(_yobcohort, 1, 6)
keep if !missing(_yobcohort, _weight)

* Education indicators
gen byte edu_primary = _educohort == 1
gen byte edu_lower   = _educohort == 2
gen byte edu_upper   = _educohort == 3
gen byte edu_tertiary = _educohort == 4

collapse (mean) edu_primary edu_lower edu_upper ///
    edu_tertiary [aw=_weight], by(_yobcohort)

replace edu_primary  = edu_primary  * 100
replace edu_lower    = edu_lower    * 100
replace edu_upper    = edu_upper    * 100
replace edu_tertiary = edu_tertiary * 100

graph bar (asis) edu_primary edu_lower edu_upper edu_tertiary, ///
    over(_yobcohort, label(angle(40))) ///
    stack ///
    title("Educational composition across birth cohorts") ///
    subtitle("Persons ages 15–64; survey-weighted") ///
    ytitle("Share of cohort (%)") ///
    ylabel(0(20)100) ///
    bar(1, color("$jpal_teal%85")) ///
    bar(2, color("$jpal_green%85")) ///
    bar(3, color("$jpal_yellow%85")) ///
    bar(4, color("$jpal_navy%85")) ///
    legend(order(1 "Primary or below" ///
                 2 "Lower secondary" ///
                 3 "Upper secondary" ///
                 4 "Tertiary") rows(1) position(6)) ///
    graphregion(color(white)) ///
    name(graph_education_cohort, replace)
	
graph export "$individual_exploration/figure005_education_in_yobcohort.png", ///
    replace width(2400)

restore

*=============================================================================*
*  Figure 6: Employment share by broad sector
*=============================================================================*
preserve

keep if inrange(_age, 15, 64) & _employed == 1
keep if inrange(_kbli_broad, 1, 3)
keep if inrange(_year, 2004, 2024)
keep if !missing(_year, _weight)

gen byte sector_primary   = _kbli_broad == 1
gen byte sector_secondary = _kbli_broad == 2
gen byte sector_tertiary  = _kbli_broad == 3

collapse (mean) sector_primary sector_secondary ///
    sector_tertiary [aw=_weight], by(_year)

replace sector_primary   = sector_primary   * 100
replace sector_secondary = sector_secondary * 100
replace sector_tertiary  = sector_tertiary  * 100

* Cumulative boundaries for stacked area chart
gen zero = 0
gen cumulative_primary = sector_primary
gen cumulative_secondary = sector_primary + sector_secondary
gen cumulative_total = sector_primary + sector_secondary + sector_tertiary

twoway ///
    (rarea zero cumulative_primary _year, ///
        sort color("$jpal_teal%85") lcolor("$jpal_teal")) ///
    (rarea cumulative_primary cumulative_secondary _year, ///
        sort color("$jpal_orange%85") lcolor("$jpal_orange")) ///
    (rarea cumulative_secondary cumulative_total _year, ///
        sort color("$jpal_navy%75") lcolor("$jpal_navy")), ///
    title("Employment composition by broad economic sector") ///
    subtitle("Employed persons ages 15–64; survey-weighted") ///
    ytitle("Share of employment (%)") ///
    xtitle("Year") ///
    ylabel(0(20)100) ///
    legend(order(1 "Primary" 2 "Secondary" ///
                 3 "Tertiary/services") position(6) cols(1)) ///
    graphregion(color(white)) ///
    name(graph_sector_shares, replace)
	
graph export "$individual_exploration/figure006_employment_by_sector.png", ///
    replace width(2400)

restore
*=============================================================================*
*  Figure 7: Occupation-skill composition within sectors
*=============================================================================*
preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64) & _employed == 1
keep if inrange(_kbli_broad, 1, 3)
keep if inrange(_kbji_harmonized, 1, 3)
keep if !missing(_weight)

gen byte occ_high   = _kbji_harmonized == 1
gen byte occ_middle = _kbji_harmonized == 2
gen byte occ_low    = _kbji_harmonized == 3

collapse (mean) occ_high occ_middle occ_low ///
    [aw=_weight], by(_year _kbli_broad)

replace occ_high   = occ_high * 100
replace occ_middle = occ_middle * 100
replace occ_low    = occ_low * 100

* Cumulative boundaries
gen zero = 0
gen cumulative_low = occ_low
gen cumulative_middle = occ_low + occ_middle
gen cumulative_total = occ_low + occ_middle + occ_high

label define graph_sector ///
    1 "Primary sector" ///
    2 "Secondary sector" ///
    3 "Tertiary/services", replace

label values _kbli_broad graph_sector

twoway ///
    (rarea zero cumulative_low _year, ///
        sort color("$jpal_teal%85") lcolor("$jpal_teal")) ///
    (rarea cumulative_low cumulative_middle _year, ///
        sort color("$jpal_orange%85") lcolor("$jpal_orange")) ///
    (rarea cumulative_middle cumulative_total _year, ///
        sort color("$jpal_navy%75") lcolor("$jpal_navy")), ///
    by(_kbli_broad, cols(3) ///
        title("Occupation-skill composition within sectors") ///
        note("")) ///
    xscale(range(2004 2024)) ///
	xlabel(2004 2024, labsize(small)) ///
    yscale(range(0 100)) ///
    ylabel(0(20)100) ///
    xtitle("Year") ///
    ytitle("Share of sector employment (%)") ///
    legend(order(1 "Low skill" 2 "Middle skill" 3 "High skill") position(6) cols(1)) ///
    graphregion(color(white)) ///
    name(graph_occ_within_sector, replace)

graph export "$individual_exploration/figure007_occskill_by_sector.png", ///
    replace width(2400)
	
restore

*=============================================================================*
*  Figure 10: Price Test Middle skill 2004-2024
*=============================================================================*

*--------------------------------------------------*
* Panel A: middle-skill share of total employment
*--------------------------------------------------*

preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if !missing(_weight) & _weight > 0

* Denominator: all employed persons
gen byte middle_employed = (_kbji_harmonized == 2)

collapse (mean) middle_share=middle_employed [aw=_weight], by(_year)
replace middle_share = 100 * middle_share

tempfile quantity
save `quantity'

restore


*--------------------------------------------------*
* Panel B: middle-minus-low log wage premium
*--------------------------------------------------*

preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1

* Comparable wage sample: wage/salaried employees
keep if _empltype == 2

* Keep middle and low occupations only
keep if inlist(_kbji_harmonized, 2, 3)

keep if !missing(_weight) & _weight > 0

gen byte middle = (_kbji_harmonized == 2)

* Separate weighted regression for each year
* Coefficient on middle = mean ln(wage)_middle - mean ln(wage)_low
statsby wage_premium=_b[middle] ///
        premium_se=_se[middle], ///
        by(_year) clear: ///
        regress _ln_real_hourly_wage middle [aw=_weight], vce(robust)

* 95% confidence interval for the difference itself
gen ci_lower = wage_premium - invnormal(.975) * premium_se
gen ci_upper = wage_premium + invnormal(.975) * premium_se

merge 1:1 _year using `quantity', nogen keep(match)
sort _year


* Confirm that the CI exists
gen ci_width = ci_upper - ci_lower
list _year wage_premium ci_lower ci_upper ci_width, noobs


* Panel A
twoway ///
    (connected middle_share _year, ///
        lcolor("$jpal_navy") lwidth(medium) ///
        mcolor("$jpal_navy") msymbol(O) msize(small)), ///
    xscale(range(2004 2024)) ///
    xlabel(2004(4)2024, nogrid) ///
    ytitle("Middle-skill employment share (%)", size(small)) ///
    xtitle("Year", size(small)) ///
    title("A. Middle-skill employment share", size(medsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    name(price_panel_a, replace)


* Panel B
twoway ///
    (rarea ci_upper ci_lower _year, ///
        fcolor("$jpal_teal%70") lcolor("$jpal_teal") lwidth(vthin)) ///
    (connected wage_premium _year, ///
        lcolor("$jpal_navy") lwidth(thin) ///
        mcolor("$jpal_navy") msymbol(O) msize(small)) ///
    (lfit wage_premium _year, ///
        lcolor("$jpal_orange") lwidth(medium) lpattern(dash)), ///
    xscale(range(2004 2024)) ///
    xlabel(2004(4)2024, nogrid) ///
    yline(0, lcolor("$jpal_gray") lpattern(shortdash)) ///
    ytitle("Middle-low log wage premium", size(small)) ///
    xtitle("Year", size(small)) ///
    title("B. Wage premium relative to low skill", size(medsmall)) ///
    subtitle("Shading = 95% CI; dashed line = fitted trend", size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    name(price_panel_b, replace)


* Combine
graph combine price_panel_a price_panel_b, ///
    cols(1) xcommon ///
    title("Middle-skill employment and relative wages, 2004-2024", ///
        size(medsmall)) ///
    graphregion(color(white)) ///
    xsize(10) ysize(8) ///
    iscale(.85) ///
    name(figure_price_test, replace)
	
graph export "$individual_exploration/figure010_supplyvswage.png", ///
    replace width(2400)

restore

preserve

keep if inlist(_year, 2004, 2014, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1 & _empltype == 2
keep if inlist(_kbji_harmonized, 2, 3)
keep if !missing(_hourly_earnings, _weight)
keep if _hourly_earnings > 0 & _weight > 0

gen double ln_hourly_wage = ln(_hourly_earnings)
gen byte middle = (_kbji_harmonized == 2)

* 2004 is the reference year
regress ln_hourly_wage ib2004._year##i.middle ///
    [pw=_weight], vce(robust)

* Display the middle-minus-low premium in each year
margins _year, dydx(middle)

* 2014 premium minus 2004 premium
lincom 2014._year#1.middle

* 2024 premium minus 2014 premium
lincom 2024._year#1.middle - 2014._year#1.middle

* 2024 premium minus 2004 premium
lincom 2024._year#1.middle

restore


*=============================================================================*
*  Figure 11: Price Test Middle skill [tertiary sector] 2004-2024
*=============================================================================*
*=============================================================================*
* SERVICE-SECTOR PRICE TESTS, 2004-2024
* Occupation: 1 = high, 2 = middle, 3 = low
* Sector:     3 = services
*=============================================================================*


preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if _kbli_broad == 3
keep if inlist(_kbji_harmonized, 2, 3)
keep if !missing(_weight) & _weight > 0

gen double middle_weight = _weight * (_kbji_harmonized == 2)
gen double low_weight    = _weight * (_kbji_harmonized == 3)

collapse (sum) middle_weight low_weight, by(_year)

gen double ln_quantity_ml = ln(middle_weight / low_weight)

tempfile quantity_ml
save `quantity_ml'

restore


preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if _kbli_broad == 3
keep if _empltype == 2
keep if inlist(_kbji_harmonized, 2, 3)

gen byte middle = (_kbji_harmonized == 2)

statsby premium_ml=_b[middle] ///
        se_ml=_se[middle], ///
        by(_year) clear: ///
        regress _ln_real_hourly_wage middle [aw=_weight], vce(robust)

gen lower_ml = premium_ml - invnormal(.975) * se_ml
gen upper_ml = premium_ml + invnormal(.975) * se_ml

merge 1:1 _year using `quantity_ml', nogen keep(match)
sort _year


twoway ///
    (connected ln_quantity_ml _year, ///
        lcolor("$jpal_navy") lwidth(medium) ///
        mcolor("$jpal_navy") msymbol(O) msize(small)), ///
    xscale(range(2004 2024)) ///
    xlabel(2004(4)2024, nogrid) ///
    ytitle("ln(middle employment / low employment)") ///
    xtitle("Year") ///
    title("A. Relative employment quantity", size(medsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    name(ml_panel_a, replace)


twoway ///
    (rarea upper_ml lower_ml _year, ///
        fcolor("$jpal_teal%70") lcolor("$jpal_teal") lwidth(vthin)) ///
    (connected premium_ml _year, ///
        lcolor("$jpal_navy") lwidth(thin) ///
        mcolor("$jpal_navy") msymbol(O) msize(small)), ///
    xscale(range(2004 2024)) ///
    xlabel(2004(4)2024, nogrid) ///
    yline(0, lcolor("$jpal_gray") lpattern(shortdash)) ///
    ytitle("Middle-low log wage premium") ///
    xtitle("Year") ///
    title("B. Relative wage price", size(medsmall)) ///
    subtitle("Shading = 95% confidence interval", size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    name(ml_panel_b, replace)


graph combine ml_panel_a ml_panel_b, ///
    cols(1) xcommon ///
    title("Middle versus low skill employment and wages within services", ///
        size(medsmall)) ///
    graphregion(color(white)) ///
    xsize(10) ysize(8) iscale(.85) ///
    name(figure_middle_low_services, replace)
	
graph export "$individual_exploration/figure011_middleservice.png", ///
    replace width(2400)

restore


*=============================================================================*
*  Figure 12: Price Test High skill wage premium 2004-2024
*=============================================================================*
preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if _kbli_broad == 3
keep if inlist(_kbji_harmonized, 1, 2)
keep if !missing(_weight) & _weight > 0

gen double high_weight   = _weight * (_kbji_harmonized == 1)
gen double middle_weight = _weight * (_kbji_harmonized == 2)

collapse (sum) high_weight middle_weight, by(_year)

gen double ln_quantity_hm = ln(high_weight / middle_weight)

tempfile quantity_hm
save `quantity_hm'

restore

preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if _kbli_broad == 3
keep if _empltype == 2
keep if inlist(_kbji_harmonized, 1, 2)

gen byte high = (_kbji_harmonized == 1)

statsby premium_hm=_b[high] ///
        se_hm=_se[high], ///
        by(_year) clear: ///
        regress _ln_real_hourly_wage high [aw=_weight], vce(robust)

gen lower_hm = premium_hm - invnormal(.975) * se_hm
gen upper_hm = premium_hm + invnormal(.975) * se_hm

merge 1:1 _year using `quantity_hm', nogen keep(match)
sort _year


twoway ///
    (connected ln_quantity_hm _year, ///
        lcolor("$jpal_navy") lwidth(medium) ///
        mcolor("$jpal_navy") msymbol(O) msize(small)), ///
    xscale(range(2004 2024)) ///
    xlabel(2004(4)2024, nogrid) ///
    ytitle("ln(high employment / middle employment)") ///
    xtitle("Year") ///
    title("A. Relative employment quantity", size(medsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    name(hm_panel_a, replace)


twoway ///
    (rarea upper_hm lower_hm _year, ///
        fcolor("$jpal_teal%70") lcolor("$jpal_teal") lwidth(vthin)) ///
    (connected premium_hm _year, ///
        lcolor("$jpal_navy") lwidth(thin) ///
        mcolor("$jpal_navy") msymbol(O) msize(small)), ///
    xscale(range(2004 2024)) ///
    xlabel(2004(4)2024, nogrid) ///
    yline(0, lcolor("$jpal_gray") lpattern(shortdash)) ///
    ytitle("High-middle log wage premium") ///
    xtitle("Year") ///
    title("B. Relative wage price", size(medsmall)) ///
    subtitle("Shading = 95% confidence interval", size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    name(hm_panel_b, replace)


graph combine hm_panel_a hm_panel_b, ///
    cols(1) xcommon ///
    title("High versus middle skill employment and wages within services", ///
        size(medsmall)) ///
    graphregion(color(white)) ///
    xsize(10) ysize(8) iscale(.85) ///
    name(figure_high_middle_services, replace)
	
graph export "$individual_exploration/figure012_highwagepremium.png", ///
    replace width(2400)

restore


*=============================================================================*
*  Figure 14: Real wage by skill
*=============================================================================*
preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if _empltype == 2
keep if inrange(_kbji_harmonized, 1, 3)
keep if _real_hourly_earnings > 0 ///
    & !missing(_real_hourly_earnings, _weight)

collapse (mean) real_wage = _real_hourly_earnings ///
    [pw=_weight], by(_year _kbji_harmonized)

reshape wide real_wage, i(_year) j(_kbji_harmonized)

twoway ///
    (connected real_wage1 _year, mcolor("$jpal_navy") lcolor("$jpal_navy")) ///
    (connected real_wage2 _year, mcolor("$jpal_orange") lcolor("$jpal_orange")) ///
    (connected real_wage3 _year, mcolor("$jpal_teal") lcolor("$jpal_teal")), ///
    xlabel(2004(4)2024) ///
    xtitle("Year") ///
    ytitle("Mean real hourly wage (2024 IDR)") ///
    title("Real hourly wages by occupational skill") ///
    subtitle("Wage employees ages 15–64; survey-weighted") ///
    legend(order(1 "High skill" 2 "Middle skill" 3 "Low skill") rows(3)) ///
    graphregion(color(white)) ///
    name(real_wage_by_skill, replace)

graph export "$individual_exploration/figure014_real_wage_by_skill.png", replace width(2400)

restore
*/

*=============================================================================*
*  Figure 15: Real wage by occupation skill on urban vs. rural
*=============================================================================*
preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if _empltype == 2
keep if inrange(_kbji_harmonized, 1, 3)
keep if inlist(_is_rural, 0, 1)
keep if _real_hourly_earnings > 0 ///
    & !missing(_real_hourly_earnings, _weight)

collapse (mean) real_wage = _real_hourly_earnings ///
    [pw=_weight], by(_year _is_rural _kbji_harmonized)

reshape wide real_wage, i(_year _is_rural) j(_kbji_harmonized)

label define location 0 "Urban" 1 "Rural", replace
label values _is_rural location

twoway ///
    (connected real_wage1 _year, mcolor("$jpal_navy") lcolor("$jpal_navy")) ///
    (connected real_wage2 _year, mcolor("$jpal_orange") lcolor("$jpal_orange")) ///
    (connected real_wage3 _year, mcolor("$jpal_teal") lcolor("$jpal_teal")), ///
    by(_is_rural, cols(1) note("Top panel: Urban  Bottom panel: Rural")) ///
    xlabel(2004(4)2024) ///
    xtitle("Year") ///
    ytitle("Mean real hourly wage (2024 IDR)") ///
    title("Real hourly wages by occupational skill and location") ///
    subtitle("Wage employees ages 15–64; survey-weighted") ///
    legend(order(1 "High skill" 2 "Middle skill" 3 "Low skill") rows(3)) ///
    graphregion(color(white)) ///
    name(real_wage_skill_location, replace)

graph export "$individual_exploration/Figure015_real_wage_skill_location.png", ///
    replace width(2400)

restore

*=============================================================================*
* Real hourly wages by economic sector
*=============================================================================*

preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if inrange(_kbli_harmonized, 1, 9)
keep if _real_hourly_earnings > 0 ///
    & !missing(_real_hourly_earnings)
keep if _weight > 0 & !missing(_weight)

collapse (mean) real_wage=_real_hourly_earnings ///
    [pw=_weight], by(_year _kbli_harmonized)

format real_wage %12.0fc

local sector1 "Agriculture, forestry and fishing"
local sector2 "Mining and quarrying"
local sector3 "Manufacturing"
local sector4 "Electricity, gas and water"
local sector5 "Construction"
local sector6 "Trade, restaurants and accommodation"
local sector7 "Transport, storage and communication"
local sector8 "Finance, real estate and business services"
local sector9 "Community, social and personal services"

forvalues s = 1/9 {

    local sectorname "`sector`s''"

    twoway ///
        (connected real_wage _year ///
            if _kbli_harmonized == `s', ///
            sort ///
            lcolor("$jpal_navy") lwidth(medium) ///
            mcolor("$jpal_navy") msymbol(O) msize(small)), ///
        title("Real Hourly Earnings") ///
        subtitle("`sectorname'") ///
        note("Employed workers ages 15–64 with positive observed earnings; survey-weighted.") ///
        xtitle("Year") ///
        ytitle("Mean real hourly earnings (2024 IDR)") ///
        xlabel(2004(4)2024) ///
        ylabel(, angle(horizontal) format(%12.0fc)) ///
        graphregion(color(white)) ///
        plotregion(margin(small)) ///
        xsize(10) ysize(7) ///
        name(real_wage_sector`s', replace)

    graph export ///
        "$individual_exploration/real_wage_sector`s'.png", ///
        replace width(2400)
}

restore

*=============================================================================*
* Bridge: demographic composition of national middle-skill employment
*=============================================================================*

preserve

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if !missing(_weight) & _weight > 0

capture drop __mid_total __mid_rm __mid_rw __mid_um __mid_uw
capture drop __component_sum __gap __zero __cum1 __cum2 __cum3 __cum4

gen byte __mid_total = ///
    (_employed == 1 & _kbji_harmonized == 2)

gen byte __mid_rm = ///
    (__mid_total == 1 & _is_rural == 1 & _is_female == 0)

gen byte __mid_rw = ///
    (__mid_total == 1 & _is_rural == 1 & _is_female == 1)

gen byte __mid_um = ///
    (__mid_total == 1 & _is_rural == 0 & _is_female == 0)

gen byte __mid_uw = ///
    (__mid_total == 1 & _is_rural == 0 & _is_female == 1)


* National working-age population is the denominator for every variable
collapse (mean) __mid_total __mid_rm __mid_rw __mid_um __mid_uw ///
    [pw=_weight], by(_year)

foreach v in __mid_total __mid_rm __mid_rw __mid_um __mid_uw {
    replace `v' = 100 * `v'
}


* Cumulative boundaries for absolute stacked areas
gen double __zero = 0
gen double __cum1 = __mid_rm
gen double __cum2 = __cum1 + __mid_rw
gen double __cum3 = __cum2 + __mid_um
gen double __cum4 = __cum3 + __mid_uw

* Insert missing calendar years so the graph does not connect across gaps
tsset _year
tsfill, full

* Dynamic y-axis
quietly summarize __cum4, meanonly
local ystep = cond(r(max) <= 20, 5, 10)
local ymax  = ceil(r(max) / `ystep') * `ystep'
if `ymax' < `ystep' local ymax = `ystep'

twoway ///
    (rarea __zero __cum1 _year, ///
        fcolor("$jpal_green%75") lcolor("$jpal_green")) ///
    (rarea __cum1 __cum2 _year, ///
        fcolor("$jpal_yellow%75") lcolor("$jpal_yellow")) ///
    (rarea __cum2 __cum3 _year, ///
        fcolor("$jpal_navy%75") lcolor("$jpal_navy")) ///
    (rarea __cum3 __cum4 _year, ///
        fcolor("$jpal_orange%75") lcolor("$jpal_orange")) ///
    (line __mid_total _year, ///
        sort cmissing(n) lcolor("$jpal_gray") lwidth(medthin)), ///
    title("Who Makes Up Middle-Skill Employment?", size(medsmall)) ///
    subtitle("Contribution to the national middle-skill employment rate, SAKERNAS 2004–2024", ///
        size(small)) ///
    xtitle("Survey year") ///
    ytitle("Contribution to middle-skill employment rate (pp)") ///
    xlabel(2004(4)2024, labsize(small)) ///
    ylabel(0(`ystep')`ymax', angle(horizontal) labsize(small)) ///
    yscale(range(0 `ymax')) ///
    legend(order(1 "Rural men" ///
                 2 "Rural women" ///
                 3 "Urban men" ///
                 4 "Urban women") ///
           position(6) ring(1) cols(4) size(small)) ///
    note("All components use the national working-age population denominator. Black line = total middle-skill employment rate.", ///
        size(vsmall)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    xsize(10) ysize(7) ///
    name(middle_skill_bridge, replace)

graph export "$individual_exploration/middle_skill_gender_location_bridge.png", ///
    replace width(2600)

restore


*=============================================================================*
* Within vs. Between Industry Analysis
*=============================================================================*

tempfile cells_nat main_results industry_results ///
         cells_location location_results annual_results

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if !missing(_weight) & _weight > 0

gen double __allw  = _weight
gen double __indw  = _weight * inrange(_kbli_harmonized, 1, 9)
gen double __bothw = _weight * ///
    inrange(_kbli_harmonized, 1, 9) * ///
    inrange(_kbji_harmonized, 1, 3)

preserve
    collapse (sum) __allw __indw __bothw, by(_year)

    gen double kbli_coverage_pct = 100 * __indw / __allw
    gen double kbji_coverage_pct = 100 * __bothw / __allw

    format kbli_coverage_pct kbji_coverage_pct %9.3f

    list _year kbli_coverage_pct kbji_coverage_pct, ///
        noobs sep(0)
restore

keep if inrange(_kbli_harmonized, 1, 9)

gen double __empw    = _weight
gen double __highw   = _weight * (_kbji_harmonized == 1)
gen double __middlew = _weight * (_kbji_harmonized == 2)
gen double __loww    = _weight * (_kbji_harmonized == 3)

collapse (sum) __empw __highw __middlew __loww, ///
    by(_year _kbli_harmonized)

bysort _year: egen double __total_emp = total(__empw)
gen double __s = __empw / __total_emp

foreach g in high middle low {

    gen double __q_`g' = __`g'w / __empw

    * Reconstruct national skill share from s_jt × q_gjt
    gen double __piece_`g' = __s * __q_`g'
    bysort _year: egen double __reconstructed_`g' = ///
        total(__piece_`g')

    * Direct national skill share
    bysort _year: egen double __skill_total_`g' = ///
        total(__`g'w)

    gen double __direct_`g' = ///
        __skill_total_`g' / __total_emp

    gen double __error_`g' = ///
        abs(__reconstructed_`g' - __direct_`g')
}

save `cells_nat'

*=============================================================================*
* 2. NATIONAL MIDPOINT SHIFT-SHARE DECOMPOSITION
*=============================================================================*

tempname P_MAIN P_IND

postfile `P_MAIN' ///
    str9 period ///
    str6 skill_group ///
    double total_change_pp ///
           between_pp ///
           within_pp ///
    using `main_results', replace

postfile `P_IND' ///
    str6 skill_group ///
    byte _kbli_harmonized ///
    double total_contribution_pp ///
           between_contribution_pp ///
           within_contribution_pp ///
    using `industry_results', replace

forvalues p = 1/5 {

    if `p' == 1 {
        local t0 2004
        local t1 2009
        local period "2004-09"
    }
    if `p' == 2 {
        local t0 2009
        local t1 2014
        local period "2009-14"
    }
    if `p' == 3 {
        local t0 2014
        local t1 2019
        local period "2014-19"
    }
    if `p' == 4 {
        local t0 2019
        local t1 2024
        local period "2019-24"
    }
    if `p' == 5 {
        local t0 2004
        local t1 2024
        local period "2004-2024"
    }

    foreach g in high middle low {

        if "`g'" == "high"   local G "High"
        if "`g'" == "middle" local G "Middle"
        if "`g'" == "low"    local G "Low"

        use `cells_nat', clear

        keep if inlist(_year, `t0', `t1')
        keep _year _kbli_harmonized __s __q_`g'

        reshape wide __s __q_`g', ///
            i(_kbli_harmonized) j(_year)

        assert !missing( ///
            __s`t0', __s`t1', ///
            __q_`g'`t0', __q_`g'`t1')

        * Midpoint decomposition
        gen double __between = ///
            ((__q_`g'`t0' + __q_`g'`t1') / 2) * ///
            (__s`t1' - __s`t0')

        gen double __within = ///
            ((__s`t0' + __s`t1') / 2) * ///
            (__q_`g'`t1' - __q_`g'`t0')

        * Exact industry contribution to total change
        gen double __total = ///
            (__s`t1' * __q_`g'`t1') - ///
            (__s`t0' * __q_`g'`t0')

        gen double __industry_error = ///
            abs(__total - __between - __within)

        assert __industry_error < 1e-10

        * Save 2004–2024 industry contributions
        if `p' == 5 {

            forvalues i = 1/`=_N' {

                post `P_IND' ///
                    ("`G'") ///
                    (_kbli_harmonized[`i']) ///
                    (100 * __total[`i']) ///
                    (100 * __between[`i']) ///
                    (100 * __within[`i'])
            }
        }

        collapse (sum) __total __between __within

        post `P_MAIN' ///
            ("`period'") ///
            ("`G'") ///
            (100 * __total[1]) ///
            (100 * __between[1]) ///
            (100 * __within[1])
    }
}

postclose `P_MAIN'
postclose `P_IND'

*=============================================================================*
* 3. RESULTS TABLE AND VALIDATION
*=============================================================================*

use `main_results', clear

gen byte period_order = .
replace period_order = 1 if period == "2004-09"
replace period_order = 2 if period == "2009-14"
replace period_order = 3 if period == "2014-19"
replace period_order = 4 if period == "2019-24"
replace period_order = 5 if period == "2004-2024"

gen byte skill_order = .
replace skill_order = 1 if skill_group == "High"
replace skill_order = 2 if skill_group == "Middle"
replace skill_order = 3 if skill_group == "Low"


sort period_order skill_order

format total_change_pp between_pp within_pp %9.3f

list period skill_group total_change_pp between_pp within_pp, ///
    noobs sepby(period)

save "$output/shiftshare_skill_results.dta", replace

export excel ///
    period skill_group total_change_pp between_pp within_pp ///
    using "$output/shiftshare_skill_results.xlsx", ///
    firstrow(variables) replace

*=============================================================================*
* 4. MAIN THREE-PANEL GRAPH
*=============================================================================*

keep if period_order <= 4

label define skill_panel ///
    1 "A. High skill" ///
    2 "B. Middle skill" ///
    3 "C. Low skill", replace

label values skill_order skill_panel

gen double x_between = period_order - 0.18
gen double x_within  = period_order + 0.18

twoway ///
    (bar between_pp x_between, ///
        barwidth(0.32) ///
        fcolor("$jpal_navy%70") lcolor("$jpal_navy")) ///
    (bar within_pp x_within, ///
        barwidth(0.32) ///
        fcolor("$jpal_orange%70") lcolor("$jpal_orange")) ///
    (connected total_change_pp period_order, ///
        sort ///
        msymbol(D) msize(small) ///
        mcolor("$jpal_gray") ///
        lcolor("$jpal_gray") lwidth(thin)), ///
    by(skill_order, cols(3) compact ///
        title("Between- and Within-Industry" "Contributions to Occupational Change", ///
              size(medsmall)) ///
        subtitle("SAKERNAS, 2004–2024", size(small)) ///
        note("Between captures changes in industry employment shares; within captures changes in occupational-skill composition within industries.", ///
             size(vsmall)) ///
        graphregion(color(white))) ///
    xlabel(1 "2004–09" 2 "2009–14" 3 "2014–19" 4 "2019–24", ///
        labsize(vsmall) angle(45)) ///
    xscale(range(0.5 4.5)) ///
    yline(0, lcolor("$jpal_gray") lpattern(dash)) ///
    ytitle("Contribution to employment-share change (pp)") ///
    legend(order(1 "Between industries" ///
                 2 "Within industries" ///
                 3 "Total change") ///
           cols(1) position(6) ring(1) size(small)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(shiftshare_main, replace)

graph export "$individual_exploration/shiftshare_skill_between_within.png", ///
    replace width(2600)

*=============================================================================*
* 5. INDUSTRY CONTRIBUTIONS, 2004–2024
*=============================================================================*

use `industry_results', clear

label define kbli9_lbl ///
    1 "Agriculture, forestry, hunting and fishing" ///
    2 "Mining and quarrying" ///
    3 "Manufacturing" ///
    4 "Electricity, gas and water" ///
    5 "Construction" ///
    6 "Trade, restaurants and accommodation" ///
    7 "Transport, storage and communication" ///
    8 "Finance, real estate and business services" ///
    9 "Community, social and personal services", replace

label values _kbli_harmonized kbli9_lbl

sort skill_group _kbli_harmonized

save "$output/shiftshare_industry_contributions_2004_2024.dta", ///
    replace

export excel ///
    skill_group _kbli_harmonized ///
    total_contribution_pp ///
    between_contribution_pp ///
    within_contribution_pp ///
    using "$output/shiftshare_industry_contributions_2004_2024.xlsx", ///
    firstrow(variables) replace

keep if skill_group == "Middle"

* Between-industry contribution
twoway ///
    (bar between_contribution_pp _kbli_harmonized, ///
        horizontal ///
        barwidth(0.65) ///
        fcolor("$jpal_navy%70") lcolor("$jpal_navy")), ///
    ylabel(1(1)9, valuelabel angle(horizontal) labsize(small)) ///
    yscale(reverse range(0.5 9.5)) ///
    xline(0, lcolor("$jpal_gray") lpattern(dash)) ///
    xtitle("Contribution to middle-skill change (pp)") ///
    ytitle("") ///
    title("Between-industry contributions", size(medsmall)) ///
    subtitle("Change in middle-skill employment, 2004–2024", ///
             size(small)) ///
    note("Positive values raise the middle-skill employment share; negative values reduce it.", ///
         size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    xsize(12) ysize(7) ///
    name(middle_between_industry, replace)

graph export ///
    "$individual_exploration/shiftshare_middle_between_by_industry.png", ///
    replace width(2600)

* Within-industry contribution
twoway ///
    (bar within_contribution_pp _kbli_harmonized, ///
        horizontal ///
        barwidth(0.65) ///
        fcolor("$jpal_orange%70") lcolor("$jpal_orange")), ///
    ylabel(1(1)9, valuelabel angle(horizontal) labsize(small)) ///
    yscale(reverse range(0.5 9.5)) ///
    xline(0, lcolor("$jpal_gray") lpattern(dash)) ///
    xtitle("Contribution to middle-skill change (pp)") ///
    ytitle("") ///
    title("Within-industry contributions", size(medsmall)) ///
    subtitle("Change in middle-skill employment, 2004–2024", ///
             size(small)) ///
    note("Positive values raise the middle-skill employment share; negative values reduce it.", ///
         size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    xsize(12) ysize(7) ///
    name(middle_within_industry, replace)

graph export ///
    "$individual_exploration/shiftshare_middle_within_by_industry.png", ///
    replace width(2600)

*=============================================================================*
* 6. URBAN/RURAL MIDDLE-SKILL DECOMPOSITION
*=============================================================================*

use "`dataset'", clear

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if inrange(_is_rural, 0, 1)
keep if inrange(_kbli_harmonized, 1, 9)
keep if !missing(_weight) & _weight > 0

gen double __empw    = _weight
gen double __middlew = ///
    _weight * (_kbji_harmonized == 2)

collapse (sum) __empw __middlew, ///
    by(_is_rural _year _kbli_harmonized)

bysort _is_rural _year: assert _N == 9

bysort _is_rural _year: egen double __total_emp = ///
    total(__empw)

gen double __s = __empw / __total_emp
gen double __q_middle = __middlew / __empw

save `cells_location'

tempname P_LOC

postfile `P_LOC' ///
    byte _is_rural ///
    str9 period ///
    double total_change_pp ///
           between_pp ///
           within_pp ///
    using `location_results', replace

forvalues loc = 0/1 {

    forvalues p = 1/5 {

        if `p' == 1 {
            local t0 2004
            local t1 2009
            local period "2004-09"
        }
        if `p' == 2 {
            local t0 2009
            local t1 2014
            local period "2009-14"
        }
        if `p' == 3 {
            local t0 2014
            local t1 2019
            local period "2014-19"
        }
        if `p' == 4 {
            local t0 2019
            local t1 2024
            local period "2019-24"
        }
        if `p' == 5 {
            local t0 2004
            local t1 2024
            local period "2004-2024"
        }

        use `cells_location', clear

        keep if _is_rural == `loc'
        keep if inlist(_year, `t0', `t1')

        keep _year _kbli_harmonized __s __q_middle

        reshape wide __s __q_middle, ///
            i(_kbli_harmonized) j(_year)

        assert !missing( ///
            __s`t0', __s`t1', ///
            __q_middle`t0', __q_middle`t1')

        gen double __between = ///
            ((__q_middle`t0' + __q_middle`t1') / 2) * ///
            (__s`t1' - __s`t0')

        gen double __within = ///
            ((__s`t0' + __s`t1') / 2) * ///
            (__q_middle`t1' - __q_middle`t0')

        gen double __total = ///
            (__s`t1' * __q_middle`t1') - ///
            (__s`t0' * __q_middle`t0')

        gen double __error = ///
            abs(__total - __between - __within)

        assert __error < 1e-10

        collapse (sum) __total __between __within

        post `P_LOC' ///
            (`loc') ///
            ("`period'") ///
            (100 * __total[1]) ///
            (100 * __between[1]) ///
            (100 * __within[1])
    }
}

postclose `P_LOC'

use `location_results', clear

gen byte period_order = .
replace period_order = 1 if period == "2004-09"
replace period_order = 2 if period == "2009-14"
replace period_order = 3 if period == "2014-19"
replace period_order = 4 if period == "2019-24"
replace period_order = 5 if period == "2004-2024"

gen double decomposition_error_pp = ///
    abs(total_change_pp - between_pp - within_pp)

assert decomposition_error_pp < 1e-6

label define location_panel ///
    0 "A. Urban" ///
    1 "B. Rural", replace

label values _is_rural location_panel

sort _is_rural period_order

save "$output/shiftshare_middle_by_location.dta", replace

keep if period_order <= 4

gen double x_between = period_order - 0.18
gen double x_within  = period_order + 0.18

twoway ///
    (bar between_pp x_between, ///
        barwidth(0.32) ///
        fcolor("$jpal_navy%70") lcolor("$jpal_navy")) ///
    (bar within_pp x_within, ///
        barwidth(0.32) ///
        fcolor("$jpal_orange%70") lcolor("$jpal_orange")) ///
    (connected total_change_pp period_order, ///
        sort ///
        msymbol(D) msize(small) ///
        mcolor("$jpal_gray") ///
        lcolor("$jpal_gray") lwidth(thin)), ///
    by(_is_rural, cols(2) compact ///
        title("Sources of Middle-Skill Employment Change by Location", ///
              size(medsmall)) ///
        subtitle("SAKERNAS, 2004–2024", size(small)) ///
        note("Between captures changes in industry employment shares; within captures occupational change inside industries.", ///
             size(vsmall)) ///
        graphregion(color(white))) ///
    xlabel(1 "2004–09" 2 "2009–14" 3 "2014–19" 4 "2019–24", ///
        labsize(small)) ///
    xscale(range(0.5 4.5)) ///
    yline(0, lcolor("$jpal_gray") lpattern(dash)) ///
    ytitle("Contribution to middle-skill change (pp)") ///
    legend(order(1 "Between industries" ///
                 2 "Within industries" ///
                 3 "Total change") ///
           rows(1) position(6) ring(1) size(small)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(shiftshare_location, replace)

graph export ///
    "$individual_exploration/shiftshare_middle_between_within_location.png", ///
    replace width(2600)

*=============================================================================*
* 7. OPTIONAL ANNUAL AND CUMULATIVE DECOMPOSITION
*    This section runs only after all preceding validations pass.
*=============================================================================*

tempname P_ANN

postfile `P_ANN' ///
    int year ///
    str6 skill_group ///
    double between_annual ///
           within_annual ///
           total_annual ///
    using `annual_results', replace

forvalues t1 = 2005/2024 {

    local t0 = `t1' - 1

    foreach g in high middle low {

        if "`g'" == "high"   local G "High"
        if "`g'" == "middle" local G "Middle"
        if "`g'" == "low"    local G "Low"

        use `cells_nat', clear

        keep if inlist(_year, `t0', `t1')
        keep _year _kbli_harmonized __s __q_`g'

        reshape wide __s __q_`g', ///
            i(_kbli_harmonized) j(_year)

        gen double __between = ///
            ((__q_`g'`t0' + __q_`g'`t1') / 2) * ///
            (__s`t1' - __s`t0')

        gen double __within = ///
            ((__s`t0' + __s`t1') / 2) * ///
            (__q_`g'`t1' - __q_`g'`t0')

        gen double __total = ///
            (__s`t1' * __q_`g'`t1') - ///
            (__s`t0' * __q_`g'`t0')

        collapse (sum) __between __within __total

        post `P_ANN' ///
            (`t1') ///
            ("`G'") ///
            (100 * __between[1]) ///
            (100 * __within[1]) ///
            (100 * __total[1])
    }
}

postclose `P_ANN'

use `annual_results', clear

gen byte skill_order = .
replace skill_order = 1 if skill_group == "High"
replace skill_order = 2 if skill_group == "Middle"
replace skill_order = 3 if skill_group == "Low"

sort skill_order year

by skill_order: gen double cum_between = ///
    sum(between_annual)

by skill_order: gen double cum_within = ///
    sum(within_annual)

by skill_order: gen double cum_total = ///
    sum(total_annual)

gen double cumulative_error = ///
    abs(cum_total - cum_between - cum_within)

assert cumulative_error < 1e-6

save "$output/shiftshare_annual_cumulative.dta", replace

export excel using ///
    "$output/shiftshare_annual_cumulative.xlsx", ///
    firstrow(variables) replace

keep if skill_group == "Middle"

twoway ///
    (connected cum_between year, ///
        sort msymbol(O) msize(vsmall) ///
        lcolor("$jpal_navy") mcolor("$jpal_navy")) ///
    (connected cum_within year, ///
        sort msymbol(T) msize(vsmall) ///
        lcolor("$jpal_orange") mcolor("$jpal_orange")) ///
    (connected cum_total year, ///
        sort msymbol(D) msize(vsmall) ///
        lcolor("$jpal_gray") mcolor("$jpal_gray")), ///
    yline(0, lcolor("$jpal_gray") lpattern(dash)) ///
    xlabel(2005(5)2020 2024) ///
    ytitle("Cumulative contribution since 2004 (pp)") ///
    xtitle("Year") ///
    title("Cumulative Sources of Middle-Skill Employment Change", ///
          size(medsmall)) ///
    subtitle("SAKERNAS, 2004–2024", size(small)) ///
    legend(order(1 "Between industries" ///
                 2 "Within industries" ///
                 3 "Observed total") ///
           rows(1) position(6) ring(1) size(small)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(shiftshare_middle_cumulative, replace)

graph export ///
    "$individual_exploration/shiftshare_middle_cumulative.png", ///
    replace width(2600)
	
