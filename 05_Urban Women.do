version 16
clear all
set more off

*=============================================================================*
* SAKERNAS CAPSTONE LABOR_POLARIZATION
* (4) Data Analysis - Urban Women
* Programmer: Tahtia Sazwara
*=============================================================================*

*=============================================================================*
* Urban occupational employment by birth cohort and gender
*=============================================================================*

local cohortdata "$output/sakernas_cohort_panel.dta"

use "`cohortdata'", clear

preserve

keep if inrange(_year, 2004, 2024)
keep if _is_rural == 0
keep if inrange(_yobcohort, 1, 6)
keep if _cell_weight > 0 & !missing(_cell_weight)

* Population-denominator employment rates, expressed as percentages
gen double __high_rate   = 100 * _employed * _occ_high
gen double __middle_rate = 100 * _employed * _occ_middle
gen double __low_rate    = 100 * _employed * _occ_low

* Aggregate education groups within year × sex × birth cohort
collapse (mean) _age __high_rate __middle_rate __low_rate ///
    [aw=_cell_weight], ///
    by(_year _is_female _yobcohort _is_rural)

* One common y-axis across all three figures
egen double __allmax = rowmax( ///
    __high_rate __middle_rate __low_rate)

quietly summarize __allmax, meanonly
local ymax = 10 * ceil(r(max) / 10)
drop __allmax

display "Common y-axis maximum = `ymax'%"


* Gender panel labels
label define gender_lbl 0 "Men" 1 "Women", replace
label values _is_female gender_lbl

*-------------------------------------------------------------*
* Figure definitions
*-------------------------------------------------------------*

local outcomes "__high_rate __middle_rate __low_rate"

local title1 "High-Skill Employment by Birth Cohort and Gender"
local title2 "Middle-Skill Employment by Birth Cohort and Gender"
local title3 "Low-Skill Employment by Birth Cohort and Gender"

local file1 "cohort_high_skill_gender_urban"
local file2 "cohort_middle_skill_gender_urban"
local file3 "cohort_low_skill_gender_urban"

*-------------------------------------------------------------*
* Three figures: Men above, women below
*-------------------------------------------------------------*

forvalues i = 1/3 {

    local outcome : word `i' of `outcomes'

    twoway ///
        (line `outcome' _age if _yobcohort == 1, ///
            sort cmissing(n) lcolor("$jpal_navy") ///
            lpattern(solid) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 2, ///
            sort cmissing(n) lcolor("$jpal_teal") ///
            lpattern(dash) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 3, ///
            sort cmissing(n) lcolor("$jpal_green") ///
            lpattern(shortdash) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 4, ///
            sort cmissing(n) lcolor("$jpal_yellow") ///
            lpattern(longdash) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 5, ///
            sort cmissing(n) lcolor("$jpal_orange") ///
            lpattern(dot) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 6, ///
            sort cmissing(n) lcolor("$jpal_gray") ///
            lpattern(dash_dot) lwidth(medthin)), ///
        by(_is_female, ///
            cols(1) ///
            title("`title`i''", size(medsmall)) ///
            subtitle("Urban population, SAKERNAS 2004–2024", ///
                size(small)) ///
            note( ///
                "Each line represents a 10-year birth cohort." ///
                "Education-specific cohort cells are aggregated across education groups." ///
                "All figures use a common y-axis.", ///
                size(vsmall)) ///
            graphregion(color(white))) ///
        xlabel(15 25 35 45 55 64, labsize(small)) ///
        ylabel(0(10)`ymax', angle(horizontal) labsize(small)) ///
		yscale(range(0 `ymax')) ///
        xtitle("Mean age") ///
        ytitle("Employment rate (%)") ///
        legend( ///
            order(1 "1940–1949" ///
                  2 "1950–1959" ///
                  3 "1960–1969" ///
                  4 "1970–1979" ///
                  5 "1980–1989" ///
                  6 "1990–1999") ///
            position(6) ring(1) ///
            cols(1) ///
            size(vsmall) ///
            symxsize(6) ///
            colgap(1) rowgap(0.5)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        xsize(10) ysize(11) ///
        name(gender_skill`i', replace)

    graph export ///
    "$urban_women/`file`i''.png", ///
    replace width(2400)
}

restore

*=============================================================================*
* Urban tertiary-educated employment by skill, cohort and gender
*=============================================================================

keep if inrange(_year, 2004, 2024)
keep if _is_rural == 0
keep if _educohort == 4
keep if inrange(_yobcohort, 1, 6)
keep if inrange(_age, 21, 64)
keep if _cell_weight > 0 & !missing(_cell_weight)

*-------------------------------------------------------------*
* Population-denominator skill employment rates
*-------------------------------------------------------------*

gen double __high_rate = ///
    100 * _employed * _occ_high

gen double __middle_rate = ///
    100 * _employed * _occ_middle

gen double __low_rate = ///
    100 * _employed * _occ_low

gen double __employment_rate = 100 * _employed

* Employment not assigned to the three occupation groups
gen double __classified_sum = ///
    __high_rate + __middle_rate + __low_rate

gen double __unclassified_gap = ///
    __employment_rate - __classified_sum

summarize __unclassified_gap, detail

display as text "Maximum unclassified employment gap: " ///
    as result %6.2f r(max) " percentage points"

*-------------------------------------------------------------*
* Common y-axis across all three figures
*-------------------------------------------------------------*

egen double __global_max = rowmax( ///
    __high_rate __middle_rate __low_rate)

quietly summarize __global_max, meanonly

local observed_max = r(max)
local ystep = 10
local ymax = `ystep' * ceil(`observed_max' / `ystep')

display as text "Global observed maximum: " ///
    as result %6.2f `observed_max' "%"

display as text "Common y-axis: 0 to " ///
    as result `ymax' "%"

drop __global_max

*-------------------------------------------------------------*
* Labels
*-------------------------------------------------------------*

label define gender_lbl ///
    0 "Men" ///
    1 "Women", replace

label values _is_female gender_lbl

local outcome1 __high_rate
local outcome2 __middle_rate
local outcome3 __low_rate

local title1 ///
    `"High-Skill Employment""Among Tertiary-Educated Urban Adults"'

local title2 ///
    `"Middle-Skill Employment""Among Tertiary-Educated Urban Adults"'

local title3 ///
    `"Low-Skill Employment""Among Tertiary-Educated Urban Adults"'

local file1 "urban_tertiary_gender_high_skill_cohort"
local file2 "urban_tertiary_gender_middle_skill_cohort"
local file3 "urban_tertiary_gender_low_skill_cohort"

*-------------------------------------------------------------*
* Three figures
*-------------------------------------------------------------*

forvalues i = 1/3 {

    local outcome "`outcome`i''"
    local graphtitle "`title`i''"
    local graphfile "`file`i''"

    twoway ///
        (line `outcome' _age if _yobcohort == 1, ///
            sort cmissing(n) lcolor("$jpal_navy") ///
            lpattern(solid) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 2, ///
            sort cmissing(n) lcolor("$jpal_teal") ///
            lpattern(dash) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 3, ///
            sort cmissing(n) lcolor("$jpal_green") ///
            lpattern(shortdash) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 4, ///
            sort cmissing(n) lcolor("$jpal_yellow") ///
            lpattern(longdash) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 5, ///
            sort cmissing(n) lcolor("$jpal_orange") ///
            lpattern(dot) lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 6, ///
            sort cmissing(n) lcolor("$jpal_gray") ///
            lpattern(dash_dot) lwidth(medthin)), ///
        by(_is_female, ///
            cols(1) compact ///
            note("") ///
            title("`graphtitle'", size(medsmall)) ///
            subtitle( ///
                "Urban tertiary-educated population, SAKERNAS 2004–2024", ///
                size(small))) ///
        xlabel(25 30 35 40 45 50 55 60 64, ///
            labsize(small)) ///
        xscale(range(25 64)) ///
        ylabel(0(`ystep')`ymax', ///
            angle(horizontal) labsize(small)) ///
        yscale(range(0 `ymax')) ///
        xtitle("Mean age") ///
        ytitle("Employment rate (%)") ///
        legend( ///
            order( ///
                1 "1940–1949" ///
                2 "1950–1959" ///
                3 "1960–1969" ///
                4 "1970–1979" ///
                5 "1980–1989" ///
                6 "1990–1999") ///
            cols(1) ///
            position(6) ring(1) ///
            size(vsmall)) ///
        note( ///
            "Each line represents a 10-year birth cohort." ///
            "Sample restricted to tertiary-educated urban population ages 21–64.", ///
            size(vsmall)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        xsize(9) ysize(10) ///
        name(urban_tertiary_gender_`i', replace)

    graph export ///
        "$urban_women/`graphfile'.png", ///
        replace width(2400)
}

*=============================================================================*
* Labour-market status among tertiary-educated urban women
*=============================================================================*

keep if inrange(_year, 2004, 2024)
keep if _is_female == 1
keep if _is_rural == 0
keep if _educohort == 4
keep if inrange(_yobcohort, 1, 6)
keep if inrange(_age, 25, 64)
keep if _cell_weight > 0 & !missing(_cell_weight)

*-------------------------------------------------------------*
* Labour-market-status decomposition
* Population denominator
*-------------------------------------------------------------*

gen double __employed_share = ///
    100 * _employed

gen double __unemployed_share = ///
    100 * _unemployed

gen double __olf_share = ///
    100 * (1 - _laborforce)

label variable __employed_share ///
    "Employment share (%)"

label variable __unemployed_share ///
    "Unemployed share of population (%)"

label variable __olf_share ///
    "Outside labour force share (%)"

*-------------------------------------------------------------*
* Outcome-specific y-axis calculations
*-------------------------------------------------------------*

local outcome1 __employed_share
local outcome2 __unemployed_share
local outcome3 __olf_share

local title1 ///
    "Employment Among Tertiary-Educated Urban Women"

local title2 ///
    "Unemployment Among Tertiary-Educated Urban Women"

local title3 ///
    "Outside the Labour Force Among Tertiary-Educated Urban Women"

local ytitle1 "Employment share (%)"
local ytitle2 "Unemployed share (%)"
local ytitle3 "Outside labour force share (%)"

local file1 "urban_tertiary_women_employment_cohort"
local file2 "urban_tertiary_women_unemployment_cohort"
local file3 "urban_tertiary_women_olf_cohort"

forvalues i = 1/3 {

    local outcome "`outcome`i''"

    quietly summarize `outcome', meanonly

    local observed_min`i' = r(min)
    local observed_max`i' = r(max)

    if r(max) <= 20 {
        local ystep`i' = 5
    }
    else {
        local ystep`i' = 10
    }

    local ymax`i' = ///
        `ystep`i'' * ceil(r(max) / `ystep`i'')

    display as text ///
        "Outcome `i': observed range = " ///
        as result %6.2f `observed_min`i'' ///
        " to " %6.2f `observed_max`i''

    display as text ///
        "Outcome `i': selected axis = 0 to " ///
        as result `ymax`i'' ///
        ", ticks every " `ystep`i''
}

*-------------------------------------------------------------*
* Create three figures
*-------------------------------------------------------------*

forvalues i = 1/3 {

    local outcome "`outcome`i''"
    local graphtitle "`title`i''"
    local axis_title "`ytitle`i''"
    local graphfile "`file`i''"
    local ystep = `ystep`i''
    local ymax = `ymax`i''

    twoway ///
        (line `outcome' _age if _yobcohort == 1, ///
            sort cmissing(n) ///
            lcolor("$jpal_navy") ///
            lpattern(solid) ///
            lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 2, ///
            sort cmissing(n) ///
            lcolor("$jpal_teal") ///
            lpattern(dash) ///
            lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 3, ///
            sort cmissing(n) ///
            lcolor("$jpal_green") ///
            lpattern(shortdash) ///
            lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 4, ///
            sort cmissing(n) ///
            lcolor("$jpal_yellow") ///
            lpattern(longdash) ///
            lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 5, ///
            sort cmissing(n) ///
            lcolor("$jpal_orange") ///
            lpattern(dot) ///
            lwidth(medthin)) ///
        (line `outcome' _age if _yobcohort == 6, ///
            sort cmissing(n) ///
            lcolor("$jpal_gray") ///
            lpattern(dash_dot) ///
            lwidth(medthin)), ///
        title("`graphtitle'", size(medsmall)) ///
        subtitle( ///
            "Urban tertiary-educated women, SAKERNAS 2004–2024", ///
            size(small)) ///
        xlabel(25 30 35 40 45 50 55 60 64, ///
            labsize(small)) ///
        xscale(range(25 64)) ///
        ylabel(0(`ystep')`ymax', ///
            angle(horizontal) ///
            labsize(small)) ///
        yscale(range(0 `ymax')) ///
        xtitle("Mean age") ///
        ytitle("`axis_title'") ///
        legend( ///
            order( ///
                1 "1940–1949" ///
                2 "1950–1959" ///
                3 "1960–1969" ///
                4 "1970–1979" ///
                5 "1980–1989" ///
                6 "1990–1999") ///
            rows(1) ///
            position(6) ring(1) ///
            symxsize(6) ///
            size(vsmall)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        xsize(9) ysize(7) ///
        name(urban_tertiary_women_`i', replace)

    graph export ///
        "$urban_women/`graphfile'.png", ///
        replace width(2400)
}


*============================================================*
* HIGH-SKILL REAL HOURLY WAGES BY GENDER
*============================================================*

* Assumes sakernas_recons_2000_2024.dta is already loaded
* High skill = _kbji_harmonized == 1
* Wage sample = employed workers with positive observed real hourly earnings

use "$output/sakernas_recons_2000_2024.dta", clear

preserve

keep if inrange(_year, 2004, 2024)
keep if _employed == 1
keep if _kbji_harmonized == 1
keep if !missing(_real_hourly_earnings) & _real_hourly_earnings > 0
keep if !missing(_weight) & _weight > 0
keep if inlist(_is_female, 0, 1)

label define sexlbl 0 "Men" 1 "Women", replace
label values _is_female sexlbl


*------------------------------------------------------------*
* 1. YEARLY MEAN + MEDIAN REAL HOURLY WAGE BY GENDER
*------------------------------------------------------------*

collapse ///
    (mean) mean_wage = _real_hourly_earnings ///
    (p50)  median_wage = _real_hourly_earnings ///
    (count) N = _real_hourly_earnings ///
    [pw = _weight], ///
    by(_year _is_female)

format mean_wage median_wage %12.0fc

list _year _is_female mean_wage median_wage N, ///
    sepby(_year) noobs clean


*------------------------------------------------------------*
* 2. GRAPH: MEDIAN REAL HOURLY WAGE
*------------------------------------------------------------*

twoway ///
    (line median_wage _year if _is_female == 0, ///
        sort lwidth(medthick)) ///
    (line median_wage _year if _is_female == 1, ///
        sort lwidth(medthick) lpattern(dash)), ///
    title("Median Real Hourly Wage of High-Skill Workers") ///
    subtitle("By gender, SAKERNAS 2004–2024") ///
    xtitle("Year") ///
    ytitle("Real hourly wage") ///
    legend(order(1 "Men" 2 "Women") rows(1) position(6)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(highskill_gender_median, replace)


*------------------------------------------------------------*
* 3. GRAPH: MEAN REAL HOURLY WAGE
*------------------------------------------------------------*

twoway ///
    (line mean_wage _year if _is_female == 0, ///
        sort lwidth(medthick)) ///
    (line mean_wage _year if _is_female == 1, ///
        sort lwidth(medthick) lpattern(dash)), ///
    title("Mean Real Hourly Wage of High-Skill Workers") ///
    subtitle("By gender, SAKERNAS 2004–2024") ///
    xtitle("Year") ///
    ytitle("Real hourly wage") ///
    legend(order(1 "Men" 2 "Women") rows(1) position(6)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(highskill_gender_mean, replace)


*------------------------------------------------------------*
* 4. FEMALE / MALE WAGE RATIO BY YEAR
*------------------------------------------------------------*

reshape wide mean_wage median_wage N, i(_year) j(_is_female)

gen median_female_male = 100 * median_wage1 / median_wage0
gen mean_female_male   = 100 * mean_wage1   / mean_wage0

label var median_female_male "Female/male median wage (%)"
label var mean_female_male   "Female/male mean wage (%)"

list _year median_wage0 median_wage1 median_female_male, ///
    noobs clean

twoway ///
    (line median_female_male _year, sort lwidth(medthick)), ///
    yline(100, lpattern(dash)) ///
    title("Female-to-Male Wage Ratio among High-Skill Workers") ///
    subtitle("Median real hourly wage, SAKERNAS 2004–2024") ///
    xtitle("Year") ///
    ytitle("Female wage as % of male wage") ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(highskill_gender_gap, replace)

restore


*============================================================*
* 5. SIMPLE TEST: DID WOMEN AND MEN HAVE DIFFERENT TRENDS?
*============================================================*

preserve

keep if inrange(_year, 2004, 2024)
keep if _employed == 1
keep if _kbji_harmonized == 1
keep if !missing(_real_hourly_earnings) & _real_hourly_earnings > 0
keep if !missing(_weight) & _weight > 0
keep if inlist(_is_female, 0, 1)

gen ln_hourly_wage = ln(_real_hourly_earnings)

* Linear time trend interacted with gender
reg ln_hourly_wage c._year##i._is_female [pw = _weight], vce(robust)

* Trend for men
lincom _year

* Trend for women
lincom _year + 1._is_female#c._year

* Difference in wage trend between women and men
lincom 1._is_female#c._year

restore


*============================================================*
* 6. TIRTA-COMPARABLE SAMPLE
* Urban + tertiary educated + age 25–34 + high skill
* Compare women against otherwise comparable men
*============================================================*

preserve

keep if inrange(_year, 2004, 2024)
keep if _employed == 1
keep if _kbji_harmonized == 1
keep if _is_rural == 0
keep if _educohort == 4
keep if inrange(_age, 25, 34)
keep if !missing(_real_hourly_earnings) & _real_hourly_earnings > 0
keep if !missing(_weight) & _weight > 0
keep if inlist(_is_female, 0, 1)

label define sexlbl2 0 "Men" 1 "Women", replace
label values _is_female sexlbl2

collapse ///
    (mean) mean_wage = _real_hourly_earnings ///
    (p50) median_wage = _real_hourly_earnings ///
    (count) N = _real_hourly_earnings ///
    [pw = _weight], ///
    by(_year _is_female)

twoway ///
    (line median_wage _year if _is_female == 0, ///
        sort lwidth(medthick)) ///
    (line median_wage _year if _is_female == 1, ///
        sort lwidth(medthick) lpattern(dash)), ///
    title("High-Skill Wages among Tertiary-Educated Urban Workers") ///
    subtitle("Ages 25–34, by gender, SAKERNAS 2004–2024") ///
    xtitle("Year") ///
    ytitle("Median real hourly wage") ///
    legend(order(1 "Men" 2 "Women") rows(1) position(6)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(tirta_gender_wages, replace)

reshape wide mean_wage median_wage N, i(_year) j(_is_female)

gen median_female_male = 100 * median_wage1 / median_wage0

list ///
    _year median_wage0 median_wage1 median_female_male ///
    N0 N1, ///
    noobs clean

restore
