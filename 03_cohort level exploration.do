version 16
clear all
set more off

*=============================================================================*
* SAKERNAS CAPSTONE LABOR_POLARIZATION
* (3) Data Exploration - Cohort level
* Programmer: Tahtia Sazwara
*=============================================================================*

local cohortdata "$output/sakernas_cohort_panel.dta"

use "`cohortdata'", clear

*=============================================================================*
*  Figure 2: High-skill employment minus tertiary attainment
*=============================================================================*

preserve

* These three year-cohort combinations are all approximately ages 21-34
keep if inlist(_year, 2004, 2014, 2024) & inrange(_age, 21, 34)

gen byte __birth = 1 if _year == 2004
replace  __birth = 2 if _year == 2014
replace  __birth = 3 if _year == 2024
label define birth_lbl 1 "1970s" 2 "1980s" 3 "1990s", replace
label values __birth birth_lbl

* Convert the population cell weight into an employed-person cell weight
gen double __emp_weight = _cell_weight * _employed
drop if missing(__emp_weight) | __emp_weight <= 0

gen byte __tertiary = (_educohort == 4)

* Both shares now use employed persons as their denominator
collapse (mean) __tertiary _occ_high [aw = __emp_weight], ///
    by(__birth _is_female _is_rural)

gen double __gap = 100 * (_occ_high - __tertiary)

gen byte __group = 1 if _is_female == 0 & _is_rural == 0
replace  __group = 2 if _is_female == 1 & _is_rural == 0
replace  __group = 3 if _is_female == 0 & _is_rural == 1
replace  __group = 4 if _is_female == 1 & _is_rural == 1

label define group_lbl ///
    1 "Urban men" 2 "Urban women" ///
    3 "Rural men" 4 "Rural women", replace
label values __group group_lbl

graph hbar (asis) __gap, ///
    over(__birth, label(labsize(small))) ///
    by(__group, cols(2) compact note("") ///
        title("High-skill employment relative to tertiary attainment") ///
        subtitle("Employed persons ages 25-34; percentage-point gap")) ///
    yline(0, lcolor("$jpal_gray")) ///
    ytitle("High-skill occupation share minus tertiary-educated share (pp)") ///
    ylabel(, grid) ///
    blabel(bar, format(%4.1f) position(outside)) ///
    bar(1, color("$jpal_navy%85")) ///
    graphregion(color(white)) ///
    xsize(12) ysize(8) ///
    name(figure2, replace)

graph export "$cohort_exploration/figure002_education_occupation_gap.png", ///
    replace width(2400)

restore

*=============================================================================*
*  Figure 3: Occupational destinations among tertiary workers
*=============================================================================*

preserve

use "`cohortdata'", clear

* Same-age comparison across the 1970s, 1980s and 1990s birth cohorts
keep if inlist(_year, 2004, 2014, 2024) & inrange(_age, 25, 34)
keep if _educohort == 4

gen byte __birth = 1 if _year == 2004
replace  __birth = 2 if _year == 2014
replace  __birth = 3 if _year == 2024
label define birth_lbl 1 "1970s" 2 "1980s" 3 "1990s", replace
label values __birth birth_lbl

gen double __emp_weight = _cell_weight * _employed
drop if missing(__emp_weight) | __emp_weight <= 0

collapse (mean) ///
    _occ_low _occ_middle _occ_high _occ_missing ///
    [aw = __emp_weight], ///
    by(__birth _is_female _is_rural)

foreach v in _occ_low _occ_middle _occ_high _occ_missing {
    replace `v' = 100 * `v'
}

gen byte __group = 1 if _is_female == 0 & _is_rural == 0
replace  __group = 2 if _is_female == 1 & _is_rural == 0
replace  __group = 3 if _is_female == 0 & _is_rural == 1
replace  __group = 4 if _is_female == 1 & _is_rural == 1

label define group_lbl ///
    1 "Urban men" 2 "Urban women" ///
    3 "Rural men" 4 "Rural women", replace
label values __group group_lbl

graph bar (asis) ///
    _occ_low _occ_middle _occ_high _occ_missing, ///
    over(__birth, gap(10) label(labsize(small))) ///
    over(__group, gap(45) label(labsize(small))) ///
    stack ///
    title("Occupational destinations of tertiary workers") ///
    subtitle("Employed persons ages 25-34; survey-weighted") ///
    ytitle("Share of tertiary-educated workers (%)") ///
    ylabel(0(20)100, angle(horizontal)) ///
    bar(1, color("$jpal_teal%80")) ///
    bar(2, color("$jpal_orange%90")) ///
    bar(3, color("$jpal_navy%85")) ///
    bar(4, color("$jpal_gray")) ///
    legend(order(1 "Low" 2 "Middle" 3 "High" 4 "Excluded/missing KBJI") ///
        rows(1) position(6) ring(1)) ///
    graphregion(color(white)) ///
    xsize(12) ysize(7) ///
    name(figure3, replace)

graph export "$cohort_exploration/figure003_tertiary_occupation_destinations.png", ///
    replace width(2400)

restore

*=============================================================================*
* Occupational employment profiles using existing cohort-panel dataset
*=============================================================================*

preserve

keep if inrange(_year, 2004, 2024)
keep if _cell_n >= 100
keep if !missing(_cell_weight, _age, _yobcohort, _is_rural)
keep if inrange(_yobcohort, 1, 6)

* Employment rate in each occupation group relative to total population
gen double _emp_high   = 100 * _employed * _occ_high
gen double _emp_middle = 100 * _employed * _occ_middle
gen double _emp_low    = 100 * _employed * _occ_low
gen double _emp_missing = 100 * _employed * _occ_missing

* Combine education and sex cells while retaining birth cohort and location
bysort _year _yobcohort _is_rural: egen long _profile_n = ///
    total(_cell_n)

collapse (mean) ///
    _age _emp_high _emp_middle _emp_low _emp_missing _profile_n ///
    [aw=_cell_weight], ///
    by(_year _yobcohort _is_rural)

* Convert occupation outcomes to long format
rename _emp_high   employment_rate1
rename _emp_middle employment_rate2
rename _emp_low    employment_rate3

reshape long employment_rate, ///
    i(_year _yobcohort _is_rural) j(_skill)

label define skill_lbl ///
    1 "High skill" ///
    2 "Middle skill" ///
    3 "Low skill", replace
label values _skill skill_lbl

gen byte _panel = 2*(_skill - 1) + _is_rural + 1

label define panel_lbl ///
    1 "High skill - Urban" ///
    2 "High skill - Rural" ///
    3 "Middle skill - Urban" ///
    4 "Middle skill - Rural" ///
    5 "Low skill - Urban" ///
    6 "Low skill - Rural", replace
label values _panel panel_lbl

* Common y-axis
quietly summarize employment_rate, meanonly
local ystep = ceil((r(max)/3)/5)*5
if `ystep' < 5 local ystep = 5

local ymax = ceil(r(max)/`ystep')*`ystep'
if `ymax' > 100 local ymax = 100

*-----------------------------------------------------------------------------*
* Three separate cohort-profile figures
*-----------------------------------------------------------------------------

label define location_lbl 0 "Urban" 1 "Rural", replace
label values _is_rural location_lbl

local skilltitle1 "High-skill employment by birth cohort"
local skilltitle2 "Middle-skill employment by birth cohort"
local skilltitle3 "Low-skill employment by birth cohort"

local skillfile1 "cohort_high_skill"
local skillfile2 "cohort_middle_skill"
local skillfile3 "cohort_low_skill"

			* Common y-axis across all three figures
			quietly summarize employment_rate, meanonly

			local ystep = ceil((r(max)/4)/5)*5
			if `ystep' < 5 local ystep = 5

			local ymax = 4 * `ystep'
			if `ymax' > 100 local ymax = 100
			
forvalues s = 1/3 {

    twoway ///
        (line employment_rate _age ///
            if _skill == `s' & _yobcohort == 1, ///
            sort cmissing(n) lcolor("$jpal_navy") lpattern(solid)) ///
        (line employment_rate _age ///
            if _skill == `s' & _yobcohort == 2, ///
            sort cmissing(n) lcolor("$jpal_teal") lpattern(dash)) ///
        (line employment_rate _age ///
            if _skill == `s' & _yobcohort == 3, ///
            sort cmissing(n) lcolor("$jpal_green") lpattern(shortdash)) ///
        (line employment_rate _age ///
            if _skill == `s' & _yobcohort == 4, ///
            sort cmissing(n) lcolor("$jpal_yellow") lpattern(longdash)) ///
        (line employment_rate _age ///
            if _skill == `s' & _yobcohort == 5, ///
            sort cmissing(n) lcolor("$jpal_orange") lpattern(dot)) ///
        (line employment_rate _age ///
            if _skill == `s' & _yobcohort == 6, ///
            sort cmissing(n) lcolor("$jpal_gray") lpattern(dash_dot)), ///
        by(_is_rural, cols(1) compact iscale(*0.85) ///
            title("`skilltitle`s''", size(medsmall)) ///
            subtitle("SAKERNAS cohort panel, 2004–2024", size(small)) ///
            note("X-axis uses weighted mean age.", ///
                 size(vsmall))) ///
        xlabel(15 25 35 45 55 64, labsize(small)) ///
        ylabel(0(`ystep')`ymax', angle(horizontal) labsize(small)) ///
        yscale(range(0 `ymax')) ///
        xtitle("Mean age") ///
        ytitle("Employment rate (%)") ///
        legend(order(1 "1940–1949" 2 "1950–1959" 3 "1960–1969" ///
                     4 "1970–1979" 5 "1980–1989" 6 "1990–1999" ) ///
               cols(1) size(vsmall)) ///
        graphregion(color(white)) ///
        xsize(9) ysize(10) ///
        name(cohort_skill`s', replace)

    graph export "$cohort_exploration/`skillfile`s''.png", ///
        replace width(2400)
}

restore


*=============================================================================*
* Middle-skill workers across secondary-sector subsectors
*=============================================================================*

preserve

local individualdata "$output/sakernas_recons_2000_2024.dta"
use "`individualdata'", clear

keep if inrange(_year, 2004, 2024)
keep if inrange(_yobcohort, 1, 6)
keep if inrange(_age, 15, 64)
keep if !missing(_weight) & _weight > 0

*-------------------------------------------------------------*
* Harmonize the three secondary-sector subsectors
*-------------------------------------------------------------*

gen byte __secondary_subsector = .

* 2004-2006: detailed industry codes
replace __secondary_subsector = 1 if ///
    inrange(_year, 2004, 2006) & ///
    inrange(_kbli_default, 150, 372)

replace __secondary_subsector = 2 if ///
    inrange(_year, 2004, 2006) & ///
    inrange(_kbli_default, 400, 410)

replace __secondary_subsector = 3 if ///
    inrange(_year, 2004, 2006) & ///
    inrange(_kbli_default, 450, 499)

* 2007-2017: nine-sector classification
replace __secondary_subsector = 1 if ///
    inrange(_year, 2007, 2017) & _kbli_default == 3

replace __secondary_subsector = 2 if ///
    inrange(_year, 2007, 2017) & _kbli_default == 4

replace __secondary_subsector = 3 if ///
    inrange(_year, 2007, 2017) & _kbli_default == 5

* 2018-2024: seventeen-sector classification
replace __secondary_subsector = 1 if ///
    inrange(_year, 2018, 2024) & _kbli_default == 3

replace __secondary_subsector = 2 if ///
    inrange(_year, 2018, 2024) & ///
    inlist(_kbli_default, 4, 5)

replace __secondary_subsector = 3 if ///
    inrange(_year, 2018, 2024) & _kbli_default == 6

* Keep employed middle-skill workers in the secondary sector
keep if _employed == 1
keep if _kbji_harmonized == 2
keep if inrange(__secondary_subsector, 1, 3)

gen byte __share1 = (__secondary_subsector == 1)
gen byte __share2 = (__secondary_subsector == 2)
gen byte __share3 = (__secondary_subsector == 3)

collapse (mean) _age __share1 __share2 __share3 ///
    [pw=_weight], ///
    by(_year _yobcohort _is_rural)

isid _year _yobcohort _is_rural

reshape long __share, ///
    i(_year _yobcohort _is_rural) j(__subsector)

replace __share = 100 * __share

label define location_lbl 0 "Urban" 1 "Rural", replace
label values _is_rural location_lbl

local sectortitle1 "Manufacturing among middle-skill workers"
local sectortitle2 "Electricity, gas and water among middle-skill workers"
local sectortitle3 "Construction among middle-skill workers"

local sectorfile1 "cohort_middle_manufacturing"
local sectorfile2 "cohort_middle_utilities"
local sectorfile3 "cohort_middle_construction"

forvalues s = 1/3 {

    twoway ///
        (line __share _age if __subsector == `s' & _yobcohort == 1, ///
            sort cmissing(n) lcolor("$jpal_navy") lpattern(solid)) ///
        (line __share _age if __subsector == `s' & _yobcohort == 2, ///
            sort cmissing(n) lcolor("$jpal_teal") lpattern(dash)) ///
        (line __share _age if __subsector == `s' & _yobcohort == 3, ///
            sort cmissing(n) lcolor("$jpal_green") lpattern(shortdash)) ///
        (line __share _age if __subsector == `s' & _yobcohort == 4, ///
            sort cmissing(n) lcolor("$jpal_yellow") lpattern(longdash)) ///
        (line __share _age if __subsector == `s' & _yobcohort == 5, ///
            sort cmissing(n) lcolor("$jpal_orange") lpattern(dot)) ///
        (line __share _age if __subsector == `s' & _yobcohort == 6, ///
            sort cmissing(n) lcolor("$jpal_gray") lpattern(dash_dot)), ///
        by(_is_rural, cols(1) compact iscale(*0.85) ///
            title("`sectortitle`s''", size(medsmall)) ///
            subtitle("Employed middle-skill workers, 2004–2024", size(small))) ///
        xlabel(15 25 35 45 55 64, labsize(small)) ///
        ylabel(0(25)100, angle(horizontal) labsize(small)) ///
        yscale(range(0 100)) ///
        xtitle("Mean age") ///
        ytitle("Share (%)") ///
        legend(order(1 "1940–1949" 2 "1950–1959" 3 "1960–1969" ///
                     4 "1970–1979" 5 "1980–1989" 6 "1990–1999") ///
               cols(1) size(vsmall) position(6)) ///
        graphregion(color(white)) ///
        xsize(9) ysize(10) ///
        name(middle_subsector`s', replace)

    graph export "$cohort_exploration/`sectorfile`s''.png", ///
        replace width(2400)
}

restore

*=============================================================================*
* Middle-skill employment by broad sector, birth cohort, and location
*=============================================================================*

preserve

tempfile middle_sector_cells

* Joint skill × sector outcomes are absent from the existing cohort dataset
use "$output/sakernas_recons_2000_2024.dta", clear

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if inrange(_yobcohort, 1, 6)

keep if !missing(_yobcohort, _is_female, _educohort, _is_rural)

* Reproduce the existing cohort definition and thin-cell rule
egen long __cohort = group( ///
    _yobcohort _is_female _educohort _is_rural)

bysort _year __cohort: gen long __cell_n = _N
drop if __cell_n < 100

keep if !missing(_weight) & _weight > 0

* Same population denominator as cohort_middle_skill
gen byte __middle_total = ///
    (_employed == 1 & _kbji_harmonized == 2 & ///
     !missing(_kbli_broad))

gen byte __middle_primary = ///
    (_employed == 1 & _kbji_harmonized == 2 & ///
     _kbli_broad == 1)

gen byte __middle_secondary = ///
    (_employed == 1 & _kbji_harmonized == 2 & ///
     _kbli_broad == 2)

gen byte __middle_tertiary = ///
    (_employed == 1 & _kbji_harmonized == 2 & ///
     _kbli_broad == 3)

collapse (mean) ///
    __middle_total ///
    __middle_primary ///
    __middle_secondary ///
    __middle_tertiary ///
    [pw = _weight], ///
    by(_year _yobcohort _is_female _educohort _is_rural)

isid _year _yobcohort _is_female _educohort _is_rural

save `middle_sector_cells'

* Return to the existing cohort panel
use "`cohortdata'", clear

keep if inrange(_year, 2004, 2024)
keep if inrange(_yobcohort, 1, 6)
keep if _cell_n >= 100
keep if !missing(_cell_weight, _age, _yobcohort, _is_rural)

merge 1:1 ///
    _year _yobcohort _is_female _educohort _is_rural ///
    using `middle_sector_cells', ///
    assert(match) nogen

* Original middle-skill outcome used in cohort_middle_skill
gen double __original_middle = ///
    100 * _employed * _occ_middle

foreach v in __middle_primary __middle_secondary __middle_tertiary {
    replace `v' = 100 * `v'
}

* Combine sex and education cells exactly as in the previous cohort graph
collapse (mean) ///
    _age ///
    __original_middle ///
    __middle_primary ///
    __middle_secondary ///
    __middle_tertiary ///
    [aw = _cell_weight], ///
    by(_year _yobcohort _is_rural)

isid _year _yobcohort _is_rural

*-------------------------------------------------------------*
* Validate decomposition
*-------------------------------------------------------------*

gen double __decomp_gap = abs( ///
    __original_middle - ///
    (__middle_primary + __middle_secondary + __middle_tertiary))

quietly summarize __decomp_gap, meanonly
local maxgap = r(max)

display as result ///
    "Maximum decomposition discrepancy = " ///
    %9.6f `maxgap' " percentage points"

* Stop if discrepancy exceeds 0.05 percentage points
if `maxgap' > 0.05 {
    display as error ///
        "Decomposition does not adequately reconstruct cohort_middle_skill."
    restore
    error 459
}

*-------------------------------------------------------------*
* Three separate figures: Primary, Secondary, Tertiary
* Each PNG contains Urban and Rural panels
*-------------------------------------------------------------*

rename __middle_primary   employment_rate1
rename __middle_secondary employment_rate2
rename __middle_tertiary  employment_rate3

reshape long employment_rate, ///
    i(_year _yobcohort _is_rural) j(_sector)

label define location_lbl 0 "Urban" 1 "Rural", replace
label values _is_rural location_lbl

* Common y-axis across all three figures
quietly summarize employment_rate, meanonly

local ystep = ceil((r(max)/4)/5)*5
if `ystep' < 5 local ystep = 5

local ymax = 4 * `ystep'
if `ymax' > 100 local ymax = 100

local sectortitle1 "Middle-skill employment in primary sector"
local sectortitle2 "Middle-skill employment in secondary sector"
local sectortitle3 "Middle-skill employment in tertiary/services"

local sectorfile1 "cohort_middle_primary"
local sectorfile2 "cohort_middle_secondary"
local sectorfile3 "cohort_middle_tertiary"

forvalues s = 1/3 {

    twoway ///
        (line employment_rate _age ///
            if _sector == `s' & _yobcohort == 1, ///
            sort cmissing(n) lcolor("$jpal_navy") lpattern(solid)) ///
        (line employment_rate _age ///
            if _sector == `s' & _yobcohort == 2, ///
            sort cmissing(n) lcolor("$jpal_teal") lpattern(dash)) ///
        (line employment_rate _age ///
            if _sector == `s' & _yobcohort == 3, ///
            sort cmissing(n) lcolor("$jpal_green") lpattern(shortdash)) ///
        (line employment_rate _age ///
            if _sector == `s' & _yobcohort == 4, ///
            sort cmissing(n) lcolor("$jpal_yellow") lpattern(longdash)) ///
        (line employment_rate _age ///
            if _sector == `s' & _yobcohort == 5, ///
            sort cmissing(n) lcolor("$jpal_orange") lpattern(dot)) ///
        (line employment_rate _age ///
            if _sector == `s' & _yobcohort == 6, ///
            sort cmissing(n) lcolor("$jpal_gray") lpattern(dash_dot)), ///
        by(_is_rural, cols(1) compact iscale(*0.85) ///
            title("`sectortitle`s'' by birth cohort", size(medsmall)) ///
            subtitle("SAKERNAS cohort panel, 2004–2024", size(small)) ///
            note("X-axis uses weighted mean age.", size(vsmall))) ///
        xlabel(15 25 35 45 55 64, labsize(small)) ///
        ylabel(0(`ystep')`ymax', angle(horizontal) labsize(small)) ///
        yscale(range(0 `ymax')) ///
        xtitle("Mean age") ///
        ytitle("Employment rate (%)") ///
        legend(order( ///
            1 "1940–1949" ///
            2 "1950–1959" ///
            3 "1960–1969" ///
            4 "1970–1979" ///
            5 "1980–1989" ///
            6 "1990–1999") ///
            cols(1) size(vsmall)) ///
        graphregion(color(white)) ///
        xsize(9) ysize(10) ///
        name(cohort_middle_sector`s', replace)

    graph export "$cohort_exploration/`sectorfile`s''.png", ///
        replace width(2400)
}

restore
