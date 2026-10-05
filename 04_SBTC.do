version 16
clear all
set more off

*=============================================================================*
* SAKERNAS CAPSTONE LABOR_POLARIZATION
* (4) Data Analysis - SBTC
* Programmer: Tahtia Sazwara
*=============================================================================*

local individual "$output/sakernas_recons_2000_2024.dta"

use "`individual'", clear

*=============================================================================*
* Occupation x industry cohort profiles
* Urban above Rural; shared legend underneath
*=============================================================================*


use "$output/sakernas_recons_2000_2024.dta", clear

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if inrange(_yobcohort, 1, 6)
keep if !missing(_weight) & _weight > 0

* Apply the same thin-cell rule as the cohort dataset
egen long __cohort = group( ///
    _yobcohort _is_female _educohort _is_rural)

bysort _year __cohort: gen long __cell_n = _N
drop if __cell_n < 100

* Save value-label names for graph titles
local kblivl : value label _kbli_harmonized
local kbjivl : value label _kbji_group

* Requested comparable occupation groups
local kbji_primary   "3 4 5 6"
local kbji_secondary "1 2 3 4 5"
local kbji_services  "1 2 3 4 5"

*-------------------------------------------------------------*
* Create joint occupation-industry employment indicators
* Denominator remains the complete cohort population
*-------------------------------------------------------------*

local outcomes

foreach k in 1 2 {
    foreach j of local kbji_primary {

        gen byte __e`k'_`j' = ///
            (_employed == 1 & ///
             _kbli_harmonized == `k' & ///
             _kbji_group == `j')

        quietly count if __e`k'_`j' == 1
        local n_`k'_`j' = r(N)

        local outcomes `outcomes' __e`k'_`j'
    }
}

foreach k in 3 4 5 {
    foreach j of local kbji_secondary {

        gen byte __e`k'_`j' = ///
            (_employed == 1 & ///
             _kbli_harmonized == `k' & ///
             _kbji_group == `j')

        quietly count if __e`k'_`j' == 1
        local n_`k'_`j' = r(N)

        local outcomes `outcomes' __e`k'_`j'
    }
}

foreach k in 6 7 8 9 {
    foreach j of local kbji_services {

        gen byte __e`k'_`j' = ///
            (_employed == 1 & ///
             _kbli_harmonized == `k' & ///
             _kbji_group == `j')

        quietly count if __e`k'_`j' == 1
        local n_`k'_`j' = r(N)

        local outcomes `outcomes' __e`k'_`j'
    }
}

* Collapse directly into birth-cohort profiles
collapse (mean) _age `outcomes' [pw=_weight], ///
    by(_year _yobcohort _is_rural)

foreach v of local outcomes {
    replace `v' = 100 * `v'
}

save "$output/sbtc_cohort_graphing_data.dta", replace

*----------------------

preserve

use "$output/sbtc_cohort_graphing_data.dta", clear


label define location_lbl 0 "Urban" 1 "Rural", replace
label values _is_rural location_lbl

*-------------------------------------------------------------*
* Common y-axis across every exported figure
*-------------------------------------------------------------*

egen double __rowmax = rowmax(`outcomes')
quietly summarize __rowmax, meanonly
local global_max = r(max)
drop __rowmax

local rawstep = `global_max' / 4

if `rawstep' <= 0.25 {
    local ystep = 0.25
}
else if `rawstep' <= 0.5 {
    local ystep = 0.5
}
else if `rawstep' <= 1 {
    local ystep = 1
}
else if `rawstep' <= 2 {
    local ystep = 2
}
else if `rawstep' <= 5 {
    local ystep = 5
}
else {
    local ystep = 10
}

local ymax = ceil(`global_max' / `ystep') * `ystep'

display as result ///
    "Common y-axis: 0 to `ymax', interval `ystep'"

*-------------------------------------------------------------*
* Export one PNG for each non-empty KBLI x KBJI combination
*-------------------------------------------------------------*

foreach k of numlist 1/9 {

    if inlist(`k', 1, 2) {
        local occ_list "`kbji_primary'"
    }
    else if inlist(`k', 3, 4, 5) {
        local occ_list "`kbji_secondary'"
    }
    else {
        local occ_list "`kbji_services'"
    }

    foreach j of local occ_list {

        local outcome __e`k'_`j'

        quietly summarize `outcome', meanonly
        if r(N) == 0 | r(max) <= 0 continue

        local ilabel : label `kblivl' `k'
        local olabel : label `kbjivl' `j'
		
		local graphN = `n_`k'_`j''
		
		local graphN_text : display %12.0fc `graphN'

        twoway ///
            (line `outcome' _age if _yobcohort == 1, ///
                sort cmissing(n) ///
                lcolor("$jpal_navy") lpattern(solid) lwidth(medthin)) ///
            (line `outcome' _age if _yobcohort == 2, ///
                sort cmissing(n) ///
                lcolor("$jpal_teal") lpattern(dash) lwidth(medthin)) ///
            (line `outcome' _age if _yobcohort == 3, ///
                sort cmissing(n) ///
                lcolor("$jpal_green") lpattern(shortdash) lwidth(medthin)) ///
            (line `outcome' _age if _yobcohort == 4, ///
                sort cmissing(n) ///
                lcolor("$jpal_yellow") lpattern(longdash) lwidth(medthin)) ///
            (line `outcome' _age if _yobcohort == 5, ///
                sort cmissing(n) ///
                lcolor("$jpal_orange") lpattern(dot) lwidth(medthin)) ///
            (line `outcome' _age if _yobcohort == 6, ///
                sort cmissing(n) ///
                lcolor("$jpal_gray") lpattern(dash_dot) lwidth(medthin)), ///
            by(_is_rural, ///
				cols(1) compact iscale(*0.90) ///
				title("KBJI `j': `olabel'" ///
					  "KBLI `k': `ilabel'", size(small)) ///
				subtitle( ///
					"Employment by birth cohort, SAKERNAS 2004-2024" ///
					"Unweighted worker N = `graphN_text'", ///
					size(vsmall)) ///
				note("Population-denominator employment rate; common y-axis.", ///
					size(tiny)) ///
				graphregion(color(white))) ///
                graphregion(color(white)) ///
            xlabel(15 25 35 45 55 64, labsize(small)) ///
            ylabel(0(25)100, ///
			angle(horizontal) labsize(small)) ///
			legend (order( ///
            1 "1940–1949" ///
            2 "1950–1959" ///
            3 "1960–1969" ///
            4 "1970–1979" ///
            5 "1980–1989" ///
            6 "1990–1999") ///
            cols(1) size(vsmall)) ///
			yscale(range(0 100)) ///
            xtitle("Mean age", size(small)) ///
            ytitle("Employment rate (%)", size(small)) ///
            graphregion(color(white) margin(small)) ///
            plotregion(margin(small)) ///
            xsize(12) ysize(12) ///
            name(sbtc_`k'_`j', replace)

        graph export ///
            "$sbtc/sbtc_kbli`k'_kbji`j'.png", ///
            replace width(2400)
    }
}

restore


*=============================================================================*
* Occupation composition within selected economic sectors
*=============================================================================*

use "`individual'", clear

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if inlist(_kbli_harmonized, 1, 6, 7, 8, 9)
keep if inrange(_kbji_group, 1, 6)
keep if _weight > 0 & !missing(_weight)

* Occupation-group indicators
forvalues j = 1/6 {
    gen byte __occ`j' = (_kbji_group == `j')
}

* Weighted occupation shares within industry-year
collapse (mean) __occ1 __occ2 __occ3 __occ4 __occ5 __occ6 ///
    [pw=_weight], by(_year _kbli_harmonized)

foreach v in __occ1 __occ2 __occ3 __occ4 __occ5 __occ6 {
    replace `v' = 100 * `v'
}

* Cumulative boundaries: low/manual groups at the bottom
gen double __zero = 0
gen double __cum6 = __occ6
gen double __cum5 = __cum6 + __occ5
gen double __cum4 = __cum5 + __occ4
gen double __cum3 = __cum4 + __occ3
gen double __cum2 = __cum3 + __occ2
gen double __cum1 = __cum2 + __occ1

* Midpoints used for labels inside each area
gen double __mid6 = __occ6 / 2
gen double __mid5 = __cum6 + (__occ5 / 2)
gen double __mid4 = __cum5 + (__occ4 / 2)
gen double __mid3 = __cum4 + (__occ3 / 2)
gen double __mid2 = __cum3 + (__occ2 / 2)
gen double __mid1 = __cum2 + (__occ1 / 2)

* Sector titles and export names
local title1 "Agriculture, forestry and fishing"
local title6 "Trade, restaurants and accommodation"
local title7 "Transport, storage and communication"
local title8 "Finance, real estate and business services"
local title9 "Community, social and personal services"

local file1 "occupation_composition_kbli1"
local file6 "occupation_composition_kbli6"
local file7 "occupation_composition_kbli7"
local file8 "occupation_composition_kbli8"
local file9 "occupation_composition_kbli9"

* Save collapsed graph data
tempfile occupation_area_data
save `occupation_area_data'

foreach k in 1 6 7 8 9 {

    use `occupation_area_data', clear
    keep if _kbli_harmonized == `k'
    sort _year

    * Label positions
    quietly summarize __mid1 if _year == 2021, meanonly
    local y1 = r(mean)

    quietly summarize __mid2 if _year == 2021, meanonly
    local y2 = r(mean)

    quietly summarize __mid3 if _year == 2021, meanonly
    local y3 = r(mean)

    quietly summarize __mid4 if _year == 2021, meanonly
    local y4 = r(mean)

    quietly summarize __mid5 if _year == 2021, meanonly
    local y5 = r(mean)

    quietly summarize __mid6 if _year == 2021, meanonly
    local y6 = r(mean)
	
	twoway ///
		(rarea __cum6 __zero _year, ///
			sort fcolor("$jpal_gray%80") lcolor("$jpal_gray")) ///
		(rarea __cum5 __cum6 _year, ///
			sort fcolor("$jpal_orange%80") lcolor("$jpal_orange")) ///
		(rarea __cum4 __cum5 _year, ///
			sort fcolor("$jpal_yellow%80") lcolor("$jpal_yellow")) ///
		(rarea __cum3 __cum4 _year, ///
			sort fcolor("$jpal_green%75") lcolor("$jpal_green")) ///
		(rarea __cum2 __cum3 _year, ///
			sort fcolor("$jpal_teal%90") lcolor("$jpal_teal")) ///
		(rarea __cum1 __cum2 _year, ///
			sort fcolor("$jpal_navy%85") lcolor("$jpal_navy")), ///
        title("Occupational composition within `title`k''", ///
            size(medsmall)) ///
        subtitle("Employed persons ages 15–64; survey-weighted", ///
            size(small)) ///
        xtitle("Year") ///
        ytitle("Share of employment (%)") ///
        xlabel(2004(2)2024, angle(45)) ///
        ylabel(0(20)100, angle(horizontal)) ///
        yscale(range(0 100)) ///
        legend(off) ///
        text(`y1' 2021 "Managers", ///
            place(e) color(white) size(vsmall)) ///
        text(`y2' 2021 "Prof./tech.", ///
            place(e) color(black) size(vsmall)) ///
        text(`y3' 2021 "Clerical", ///
            place(e) color(white) size(vsmall)) ///
        text(`y4' 2021 "Service/sales", ///
            place(e) color(white) size(vsmall)) ///
        text(`y5' 2021 "Skilled agri.", ///
            place(e) color(black) size(vsmall)) ///
        text(`y6' 2021 "Manual/elementary", ///
            place(e) color(black) size(vsmall)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        name(occupation_kbli`k', replace)

    graph export "$sbtc/`file`k''.png", ///
        replace width(2400)
}


*=============================================================================*
* COHORT-BASED WITHIN/BETWEEN OCCUPATIONAL DECOMPOSITION
*=============================================================================*

tempfile sector_lookup occupation_lookup
tempfile cells1564 cells2554
tempfile main_results common_results prime_results
tempfile cohort_detail selected_occupations

local occ_codes 1 2 3 4 5 6


*=============================================================================*
* 0. RETAIN ACTUAL HARMONISED LABELS
*=============================================================================*

use "`individual'", clear

display as text "Occupational groups included: `occ_codes'"

preserve
    keep if inlist(_kbli_harmonized, 1, 6, 7, 8, 9)
    keep _kbli_harmonized
    duplicates drop

    decode _kbli_harmonized, gen(kbli_label)
    rename _kbli_harmonized kbli

    keep kbli kbli_label
    save "`sector_lookup'", replace
restore

preserve
    keep if _kbji_group > 0 & !missing(_kbji_group)
    keep _kbji_group
    duplicates drop

    decode _kbji_group, gen(occupation_label)
    rename _kbji_group occupation

    keep occupation occupation_label
    save "`occupation_lookup'", replace
restore


*=============================================================================*
* 1. PROGRAM: CONSTRUCT YEAR × INDUSTRY × COHORT CELLS
*=============================================================================*

capture program drop make_cohort_cells
program define make_cohort_cells
    version 16

    syntax, SOURCE(string) SAVING(string) ///
        AGEMIN(integer) AGEMAX(integer) OCCCodes(numlist)

    use "`source'", clear

    keep if inrange(_year, 2004, 2024)
    keep if inrange(_age, `agemin', `agemax')
    keep if _employed == 1

    keep if inlist(_kbli_harmonized, 1, 6, 7, 8, 9)
    keep if inrange(_yobcohort, 1, 6)
    keep if _kbji_group > 0 & !missing(_kbji_group)

    keep if _weight > 0 & !missing(_weight)

    gen double __empw = _weight
    gen long   __n    = 1

    local occvars

    foreach k of numlist `occcodes' {

        gen double __occw`k' = ///
            _weight * (_kbji_group == `k')

        local occvars `occvars' __occw`k'
    }

    collapse (sum) __empw __n `occvars', ///
        by(_year _kbli_harmonized _yobcohort)

    * Add structurally absent cohort-industry-year cells.
    fillin _year _kbli_harmonized _yobcohort

    replace __empw = 0 if missing(__empw)
    replace __n    = 0 if missing(__n)

    foreach k of numlist `occcodes' {
        replace __occw`k' = 0 if missing(__occw`k')
    }

    drop _fillin

    sort _year _kbli_harmonized _yobcohort
    save "`saving'", replace
end


make_cohort_cells, ///
    source("`individual'") ///
    saving("`cells1564'") ///
    agemin(15) agemax(64) ///
    occcodes(`occ_codes')

make_cohort_cells, ///
    source("`individual'") ///
    saving("`cells2554'") ///
    agemin(25) agemax(54) ///
    occcodes(`occ_codes')


*=============================================================================*
* 2. CELL-SIZE AND BASIC VALIDATION
*=============================================================================*

use "`cells1564'", clear

display as text "Cell sizes: year × KBLI × birth cohort"

quietly summarize __n, detail

display as result "Minimum N: " %12.0f r(min)
display as result "Median N:  " %12.0f r(p50)
display as result "Maximum N: " %12.0f r(max)

*=============================================================================*
* 3. PROGRAM: MIDPOINT COHORT DECOMPOSITION
*=============================================================================*

capture program drop make_cohort_decomposition
program define make_cohort_decomposition
    version 16

    syntax, CELLS(string) SAVING(string) ///
        OCCCodes(numlist) ///
        [COMMON THIN(integer 0)]

    tempname result_handle

    postfile `result_handle' ///
        byte kbli ///
        byte occupation ///
        str9 period ///
        int start_year ///
        int end_year ///
        double total_change_pp ///
        double between_cohort_pp ///
        double within_cohort_pp ///
        double reconstruction_error ///
        using "`saving'", replace

    local startyears "2004 2009 2014 2019 2004"
    local endyears   "2009 2014 2019 2024 2024"

    forvalues p = 1/5 {

        local t0 : word `p' of `startyears'
        local t1 : word `p' of `endyears'
        local period "`t0'-`t1'"

        foreach k of numlist `occcodes' {

            use "`cells'", clear

            keep if inlist(_year, `t0', `t1')

            reshape wide ///
                __empw __n ///
                __occw1 __occw2 __occw3 ///
                __occw4 __occw5 __occw6, ///
                i(_kbli_harmonized _yobcohort) ///
                j(_year)

            * Optional robustness: remove thin cells.
            if `thin' > 0 {

                foreach y in `t0' `t1' {

                    replace __empw`y' = 0 ///
                        if __n`y' < `thin'

                    foreach h of numlist `occcodes' {
                        replace __occw`h'`y' = 0 ///
                            if __n`y' < `thin'
                    }
                }
            }

            * Common support: retain cohorts with employment at both endpoints.
            if "`common'" != "" {
                keep if ///
                    __empw`t0' > 0 & ///
                    __empw`t1' > 0
            }

            bysort _kbli_harmonized: ///
                egen double __industry0 = ///
                total(__empw`t0')

            bysort _kbli_harmonized: ///
                egen double __industry1 = ///
                total(__empw`t1')

            gen double __s0 = ///
                __empw`t0' / __industry0

            gen double __s1 = ///
                __empw`t1' / __industry1

            gen double __q0 = ///
                __occw`k'`t0' / __empw`t0' ///
                if __empw`t0' > 0

            gen double __q1 = ///
                __occw`k'`t1' / __empw`t1' ///
                if __empw`t1' > 0

            *---------------------------------------------------------*
            * Zero-employment convention
            *
            * If the cohort-industry cell exists at only one endpoint,
            * copy the observed occupational share to the empty endpoint.
            *
            * Entry/exit is consequently assigned to the changing-cohort
            * composition component, not manufactured as a within-cohort
            * occupational change.
            *---------------------------------------------------------*

            replace __q0 = __q1 if ///
                __empw`t0' == 0 & ///
                __empw`t1' > 0

            replace __q1 = __q0 if ///
                __empw`t1' == 0 & ///
                __empw`t0' > 0

            replace __q0 = 0 if ///
                __empw`t0' == 0 & ///
                __empw`t1' == 0

            replace __q1 = 0 if ///
                __empw`t0' == 0 & ///
                __empw`t1' == 0

            gen double __between = ///
                0.5 * (__q0 + __q1) * ///
                (__s1 - __s0)

            gen double __within = ///
                0.5 * (__s0 + __s1) * ///
                (__q1 - __q0)

            collapse (sum) ///
                __between __within ///
                __occw`k'`t0' __occw`k'`t1' ///
                __empw`t0' __empw`t1', ///
                by(_kbli_harmonized)

            gen double __total = 100 * ( ///
                __occw`k'`t1' / __empw`t1' - ///
                __occw`k'`t0' / __empw`t0' )

            replace __between = 100 * __between
            replace __within  = 100 * __within

            gen double __error = ///
                __total - __between - __within

            local observations = _N

            forvalues row = 1/`observations' {

                post `result_handle' ///
                    (_kbli_harmonized[`row']) ///
                    (`k') ///
                    ("`period'") ///
                    (`t0') ///
                    (`t1') ///
                    (__total[`row']) ///
                    (__between[`row']) ///
                    (__within[`row']) ///
                    (__error[`row'])
            }
        }
    }

    postclose `result_handle'
end


*=============================================================================*
* 4. RUN MAIN AND ROBUSTNESS SPECIFICATIONS
*=============================================================================*

make_cohort_decomposition, ///
    cells("`cells1564'") ///
    saving("`main_results'") ///
    occcodes(`occ_codes') ///
    thin(100)

make_cohort_decomposition, ///
    cells("`cells1564'") ///
    saving("`common_results'") ///
    occcodes(`occ_codes') ///
    common

make_cohort_decomposition, ///
    cells("`cells2554'") ///
    saving("`prime_results'") ///
    occcodes(`occ_codes')

*=============================================================================*
* 5. ATTACH LABELS AND SAVE RESULTS
*=============================================================================*

foreach result in ///
    main_results common_results prime_results {

    use "``result''", clear

    merge m:1 kbli using "`sector_lookup'", ///
        keep(match) nogen

    merge m:1 occupation using "`occupation_lookup'", ///
        keep(match) nogen

    order ///
        kbli kbli_label ///
        occupation occupation_label ///
        period start_year end_year ///
        total_change_pp ///
        between_cohort_pp ///
        within_cohort_pp ///
        reconstruction_error

    sort kbli occupation start_year end_year

    save "``result''", replace
}


use "`main_results'", clear

quietly summarize ///
    reconstruction_error, meanonly

display as result ///
    "Maximum |Total - Between - Within|: " ///
    %16.12f max(abs(r(min)), abs(r(max)))

save "$output/cohort_within_between_results.dta", replace


list ///
    kbli_label occupation_label ///
    total_change_pp between_cohort_pp within_cohort_pp ///
    if period == "2004-2024", ///
    sepby(kbli) noobs abbreviate(30)


*=============================================================================*
* 6. LABELS USED BY THE FIGURES
*=============================================================================*

capture label drop occupation6_lbl
label define occupation6_lbl ///
    1 "Managers" ///
    2 "Professional/technical" ///
    3 "Clerical" ///
    4 "Service and sales" ///
    5 "Skilled agriculture" ///
    6 "Manual/elementary"

capture label drop cohort6_lbl
label define cohort6_lbl ///
    1 "1940-1949" ///
    2 "1950-1959" ///
    3 "1960-1969" ///
    4 "1970-1979" ///
    5 "1980-1989" ///
    6 "1990-1999"

local selected_sectors 1 6 7 8 9
local sectortitle1 "Agriculture"
local sectortitle6 "Trade, Restaurants & Accommodation"
local sectortitle7 "Transport & Communication"
local sectortitle8 "Finance & Business Services"
local sectortitle9 "Community & Personal Services"
local sectorfile1 "agriculture"
local sectorfile6 "trade_hospitality"
local sectorfile7 "transport_communication"
local sectorfile8 "finance_business"
local sectorfile9 "community_personal"


*=============================================================================*
* 7. MAIN FIGURE 1: LONG-RUN DECOMPOSITION
*=============================================================================*

use "`main_results'", clear
keep if period == "2004-2024"

label values occupation occupation6_lbl

foreach j of local selected_sectors {

    preserve
        keep if kbli == `j'
        sort occupation

        local sectortitle "``sectortitle`j'''"
        local sectorfile  "``sectorfile`j'''"

        gen double __between_y = occupation - 0.18
        gen double __within_y  = occupation + 0.18

        twoway ///
            (bar between_cohort_pp __between_y, ///
                horizontal barwidth(0.30) ///
                fcolor("$jpal_navy%75") lcolor("$jpal_navy")) ///
            (bar within_cohort_pp __within_y, ///
                horizontal barwidth(0.30) ///
                fcolor("$jpal_orange%75") lcolor("$jpal_orange")) ///
            (scatter occupation total_change_pp, ///
                msymbol(D) msize(medsmall) ///
                mcolor("$jpal_gray")), ///
            xline(0, lcolor("$jpal_gray") lpattern(dash)) ///
            ylabel(1(1)6, ///
                valuelabel angle(horizontal)) ///
            yscale(reverse range(0.5 6.5)) ///
            xtitle("Contribution to change (percentage points)") ///
            ytitle("") ///
            title( ///
                "Cohort Sources of Occupational Change" ///
                "within `sectortitle'", ///
                size(medsmall)) ///
            subtitle( ///
                "Decomposition of change in occupational shares, 2004-2024", ///
                size(small)) ///
            legend( ///
                order( ///
                    1 "Changing cohort composition" ///
                    2 "Within-cohort change" ///
                    3 "Total change") ///
                position(6) rows(1) size(small)) ///
            note( ///
                "Within-cohort change refers to repeated cross-sectional changes within birth-cohort groups," ///
                "not individual worker transitions.", ///
                size(vsmall)) ///
            graphregion(color(white)) ///
            name(longrun_`j', replace)

        graph export ///
            "$sbtc/cohort_decomposition_`sectorfile'.png", ///
            replace width(2400)

    restore
}


*=============================================================================*
* 8. SELECT THREE LARGEST LONG-RUN CHANGES
*=============================================================================*

use "`main_results'", clear
keep if period == "2004-2024"

gen double absolute_change = ///
    abs(total_change_pp)

gsort kbli -absolute_change
by kbli: gen byte occupation_rank = _n

keep if occupation_rank <= 3

list ///
    kbli_label occupation_label ///
    occupation_rank total_change_pp, ///
    sepby(kbli) noobs abbreviate(32)

keep kbli occupation occupation_rank
save "`selected_occupations'", replace


*=============================================================================*
* 9. MAIN FIGURE 2: WHEN DID CHANGE OCCUR?
*=============================================================================*

use "`main_results'", clear

merge m:1 kbli occupation ///
    using "`selected_occupations'", ///
    keep(match) nogen

keep if period != "2004-2024"

gen byte __period = .
replace __period = 1 if period == "2004-2009"
replace __period = 2 if period == "2009-2014"
replace __period = 3 if period == "2014-2019"
replace __period = 4 if period == "2019-2024"

label define period4_lbl ///
    1 "2004-09" ///
    2 "2009-14" ///
    3 "2014-19" ///
    4 "2019-24", replace

label values __period period4_lbl
label values occupation occupation6_lbl

gen double __between_y = __period - 0.17
gen double __within_y  = __period + 0.17

foreach j of local selected_sectors {

    preserve
        keep if kbli == `j'

        local sectortitle "``sectortitle`j'''"
        local sectorfile  "``sectorfile`j'''"

        twoway ///
            (bar between_cohort_pp __between_y, ///
                horizontal barwidth(0.28) ///
                fcolor("$jpal_navy%75") lcolor("$jpal_navy")) ///
            (bar within_cohort_pp __within_y, ///
                horizontal barwidth(0.28) ///
                fcolor("$jpal_orange%75") lcolor("$jpal_orange")) ///
            (scatter __period total_change_pp, ///
                msymbol(D) mcolor("$jpal_gray") ///
                msize(small)), ///
            by(occupation, ///
                cols(1) compact ///
                title( ///
                    "Timing of Occupational Change within `sectortitle'", ///
                    size(medsmall)) ///
                subtitle( ///
                    "Three largest absolute changes over 2004-2024", ///
                    size(small)) ///
                note( ///
                    "Within-cohort changes refer to repeated cross-sectional birth-cohort groups.", ///
                    size(vsmall))) ///
            xline(0, lcolor("$jpal_gray") lpattern(dash)) ///
            ylabel(1(1)4, ///
                valuelabel angle(horizontal)) ///
            yscale(reverse range(0.5 4.5)) ///
            xtitle("Contribution to change (percentage points)") ///
            ytitle("") ///
            legend( ///
                order( ///
                    1 "Changing cohort composition" ///
                    2 "Within-cohort change" ///
                    3 "Total change") ///
                position(6) cols(1) size(vsmall)) ///
            graphregion(color(white)) ///
            xsize(9) ysize(11) ///
            name(timing_`j', replace)

        graph export ///
            "$sbtc/cohort_timing_`sectorfile'.png", ///
            replace width(2400)

    restore
}


*=============================================================================*
* 10. COHORT-LEVEL CONTRIBUTIONS, 2004-2024
*=============================================================================*

use "`cells1564'", clear
keep if inlist(_year, 2004, 2024)

reshape wide ///
    __empw __n ///
    __occw1 __occw2 __occw3 ///
    __occw4 __occw5 __occw6, ///
    i(_kbli_harmonized _yobcohort) ///
    j(_year)

tempname cohort_handle

postfile `cohort_handle' ///
    byte kbli ///
    byte occupation ///
    byte cohort ///
    double between_contribution_pp ///
    double within_contribution_pp ///
    using "`cohort_detail'", replace

foreach k of local occ_codes {

    preserve

        bysort _kbli_harmonized: ///
            egen double __industry0 = total(__empw2004)

        bysort _kbli_harmonized: ///
            egen double __industry1 = total(__empw2024)

        gen double __s0 = __empw2004 / __industry0
        gen double __s1 = __empw2024 / __industry1

        gen double __q0 = ///
            __occw`k'2004 / __empw2004 ///
            if __empw2004 > 0

        gen double __q1 = ///
            __occw`k'2024 / __empw2024 ///
            if __empw2024 > 0

        replace __q0 = __q1 if ///
            __empw2004 == 0 & __empw2024 > 0

        replace __q1 = __q0 if ///
            __empw2024 == 0 & __empw2004 > 0

        replace __q0 = 0 if ///
            __empw2004 == 0 & __empw2024 == 0

        replace __q1 = 0 if ///
            __empw2004 == 0 & __empw2024 == 0

        gen double __between_pp = ///
            100 * 0.5 * (__q0 + __q1) * ///
            (__s1 - __s0)

        gen double __within_pp = ///
            100 * 0.5 * (__s0 + __s1) * ///
            (__q1 - __q0)

        local observations = _N

        forvalues row = 1/`observations' {

            post `cohort_handle' ///
                (_kbli_harmonized[`row']) ///
                (`k') ///
                (_yobcohort[`row']) ///
                (__between_pp[`row']) ///
                (__within_pp[`row'])
        }

    restore
}

postclose `cohort_handle'


use "`cohort_detail'", clear

merge m:1 kbli using "`sector_lookup'", ///
    keep(match) nogen

merge m:1 occupation using "`occupation_lookup'", ///
    keep(match) nogen

order ///
    kbli kbli_label ///
    occupation occupation_label ///
    cohort ///
    between_contribution_pp ///
    within_contribution_pp

save "$output/cohort_level_contributions.dta", replace


*=============================================================================*
* 11. COHORT-CONTRIBUTION GRAPH: LARGEST OCCUPATION PER INDUSTRY
*=============================================================================*

merge m:1 kbli occupation ///
    using "`selected_occupations'", ///
    keep(match) nogen

keep if occupation_rank == 1

label values occupation occupation6_lbl
label values cohort cohort6_lbl

gen double total_contribution_pp = ///
    between_contribution_pp + ///
    within_contribution_pp

gen double __between_y = cohort - 0.18
gen double __within_y  = cohort + 0.18

foreach j of local selected_sectors {

    preserve
        keep if kbli == `j'
        sort cohort

        local sectortitle = kbli_label[1]
        local occtitle    = occupation_label[1]

        twoway ///
            (bar between_contribution_pp __between_y, ///
                horizontal barwidth(0.30) ///
                fcolor("$jpal_navy%75") lcolor("$jpal_navy")) ///
            (bar within_contribution_pp __within_y, ///
                horizontal barwidth(0.30) ///
                fcolor("$jpal_orange%75") lcolor("$jpal_orange")) ///
            (scatter cohort total_contribution_pp, ///
                msymbol(D) mcolor("$jpal_gray") ///
                msize(small)), ///
            xline(0, lcolor("$jpal_gray") lpattern(dash)) ///
            ylabel(1(1)6, ///
                valuelabel angle(horizontal)) ///
            yscale(reverse range(0.5 6.5)) ///
            xtitle("Cohort contribution (percentage points)") ///
            ytitle("") ///
            title( ///
                "Cohort Contributions within `sectortitle'", ///
                size(medsmall)) ///
            subtitle( ///
                "`occtitle', 2004-2024", ///
                size(small)) ///
            legend( ///
                order( ///
                    1 "Changing cohort composition" ///
                    2 "Within-cohort change" ///
                    3 "Total cohort contribution") ///
                position(6) rows(1) size(vsmall)) ///
            note( ///
                "Contributions sum to the industry's total occupational-share change.", ///
                size(vsmall)) ///
            graphregion(color(white)) ///
            name(cohort_contribution_`j', replace)

        graph export ///
            "$sbtc/cohort_contribution_kbli`j'.png", ///
            replace width(2400)

    restore
}

version 16
clear all
set more off

*=============================================================================*
* Targeted cohort graphs with adaptive y-axis scales
* SAKERNAS 2004-2024
*
* Run after 00_Directory.do has defined the project globals.
*=============================================================================*

local individual "$output/sakernas_recons_2000_2024.dta"

use "`individual'", clear

*=============================================================================*
* Validate existing variables and labels
*=============================================================================*

local required ///
    _year _age _weight _yobcohort _is_female _educohort _is_rural ///
    _employed _kbli_harmonized _kbji_group

local yobl   : value label _yobcohort
local locvl  : value label _is_rural
local kblivl : value label _kbli_harmonized
local kbjivl : value label _kbji_group

display as text "Existing cohort labels:"
label list `yobl'

display as text "Existing Urban/Rural coding:"
label list `locvl'

display as text "Existing harmonised KBLI labels:"
label list `kblivl'

display as text "Existing harmonised KBJI-group labels:"
label list `kbjivl'

*=============================================================================*
* Seven requested KBLI x harmonised KBJI-group cells
*
* Existing _kbji_group coding:
* 2 Professionals and technicians
* 3 Clerical and administrative
* 4 Service and sales
* 5 Skilled agricultural
* 6 Production, operators and elementary
*=============================================================================*

local kbli1 1
local kbji1 5
local file1 "01_agriculture_skilled_agricultural"

local kbli2 6
local kbji2 4
local file2 "02_trade_service_sales"

local kbli3 6
local kbji3 6
local file3 "03_trade_production_operators_elementary"

local kbli4 8
local kbji4 3
local file4 "04_finance_clerical_administrative"

local kbli5 8
local kbji5 2
local file5 "05_finance_professionals_technicians"

local kbli6 9
local kbji6 2
local file6 "06_community_professionals_technicians"

local kbli7 9
local kbji7 4
local file7 "07_community_service_sales"

forvalues t = 1/7 {
    local k = `kbli`t''
    local j = `kbji`t''

    local kblilabel`t' : label `kblivl' `k'
    local kbjilabel`t' : label `kbjivl' `j'

    if "`kblilabel`t''" == "" | "`kbjilabel`t''" == "" {
        display as error ///
            "A requested KBLI or KBJI code has no existing value label."
        exit 198
    }
}

*=============================================================================*
* Reproduce the existing cohort sample and population denominator
*=============================================================================*

keep if inrange(_year, 2004, 2024)
keep if inrange(_age, 15, 64)
keep if inrange(_yobcohort, 1, 6)
keep if !missing(_weight) & _weight > 0

egen long __cohort = group( ///
    _yobcohort _is_female _educohort _is_rural)

bysort _year __cohort: gen long __cell_n = _N
drop if __cell_n < 100

quietly count
local denominator_n = r(N)

display as text ///
    "Population denominator: retained persons ages 15-64 in 2004-2024 " ///
    "after the existing cohort-year N>=100 rule."

display as result ///
    "Unweighted denominator N = " %12.0fc `denominator_n'

* Each indicator is one for workers in the requested joint cell.
* Everyone else remains zero, preserving the population denominator.

local outcomes

forvalues t = 1/7 {
    local k = `kbli`t''
    local j = `kbji`t''

    gen byte __rate`t' = ///
        (_employed == 1 & ///
         _kbli_harmonized == `k' & ///
         _kbji_group == `j')

    assert inlist(__rate`t', 0, 1)
    assert !missing(__rate`t')

    quietly count if __rate`t' == 1
    local workerN`t' = r(N)

    if `workerN`t'' == 0 {
        display as error ///
            "No workers found for KBLI `k' x KBJI group `j'."
        exit 2000
    }

    local outcomes `outcomes' __rate`t'
}

*=============================================================================*
* Weighted age-band diagnostic table
*=============================================================================*

gen byte __ageband = .
replace __ageband = 1 if inrange(_age, 25, 29)
replace __ageband = 2 if inrange(_age, 30, 34)

label define ageband_lbl ///
    1 "Age 25-29" ///
    2 "Age 30-34", replace

label values __ageband ageband_lbl

tempfile diagnostic_counts

preserve

    keep if !missing(__ageband)

    collapse ///
        (count) __population_n = _year ///
        (sum)   __worker_n1 = __rate1 ///
                __worker_n2 = __rate2 ///
                __worker_n3 = __rate3 ///
                __worker_n4 = __rate4 ///
                __worker_n5 = __rate5 ///
                __worker_n6 = __rate6 ///
                __worker_n7 = __rate7, ///
        by(_yobcohort _is_rural __ageband)

    save `diagnostic_counts', replace

restore

preserve

    keep if !missing(__ageband)

    collapse (mean) `outcomes' [pw=_weight], ///
        by(_yobcohort _is_rural __ageband)

    merge 1:1 _yobcohort _is_rural __ageband ///
        using `diagnostic_counts', nogen assert(3)

    reshape long __rate __worker_n, ///
        i(_yobcohort _is_rural __ageband) ///
        j(__target)

    replace __rate = 100 * __rate

    * Unsupported cohort-age combinations remain missing.
    fillin _yobcohort _is_rural __ageband __target

    gen str24 __sample_flag = ""

    replace __sample_flag = "unsupported" ///
        if _fillin == 1

    replace __sample_flag = "very small: N<30" ///
        if _fillin == 0 & __worker_n < 30

    replace __sample_flag = "potentially noisy: N<100" ///
        if _fillin == 0 & inrange(__worker_n, 30, 99)

    label define target_lbl ///
        1 "KBLI 1 x skilled agricultural" ///
        2 "KBLI 6 x service and sales" ///
        3 "KBLI 6 x production/operators/elementary" ///
        4 "KBLI 8 x clerical/administrative" ///
        5 "KBLI 8 x professionals/technicians" ///
        6 "KBLI 9 x professionals/technicians" ///
        7 "KBLI 9 x service and sales", replace

    label values __target target_lbl

    format __rate %9.3f

    sort __target _yobcohort _is_rural __ageband

    display as text ///
        "Weighted population-denominator rates and unweighted worker N"

    list __target _yobcohort _is_rural __ageband ///
        __rate __worker_n __population_n __sample_flag, ///
        noobs sepby(__target) abbreviate(24)

restore

*=============================================================================*
* Collapse to the graph level
*=============================================================================*

collapse (mean) _age `outcomes' [pw=_weight], ///
    by(_year _yobcohort _is_rural)

foreach v of local outcomes {
    replace `v' = 100 * `v'
}

label values _yobcohort `yobl'
label define location_lbl 0 "Urban" 1 "Rural", replace
label values _is_rural location_lbl

* Store final graph validation summary.

tempfile graph_summary
tempname summary_post

postfile `summary_post' ///
    byte target byte kbli byte kbji ///
    str60 kbli_label str60 kbji_label ///
    long unweighted_N ///
    double max_rate y_ceiling ///
    using `graph_summary', replace

*=============================================================================*
* Seven targeted graphs with adaptive y-axes
*=============================================================================*

forvalues t = 1/7 {

    local k = `kbli`t''
    local j = `kbji`t''

    quietly summarize __rate`t', meanonly
    local plotted_max = r(max)

    if r(N) == 0 | missing(`plotted_max') {
        display as error ///
            "No plotted observations for KBLI `k' x KBJI `j'."
        postclose `summary_post'
        exit 2000
    }

    * Adaptive ceiling and tick labels shared by Urban and Rural.

    if `plotted_max' <= 2 {
        local ymax = 2.5
        local ylabels "0(.5)2.5"
    }
    else if `plotted_max' <= 5 {
        local ymax = 6
        local ylabels "0(1)6"
    }
    else if `plotted_max' <= 10 {
        local ymax = 12
        local ylabels "0(2)12"
    }
    else if `plotted_max' <= 20 {
        local ymax = 25
        local ylabels "0(5)25"
    }
    else if `plotted_max' <= 30 {
        local ymax = 35
        local ylabels "0(5)35"
    }
    else if `plotted_max' <= 60 {
        local ymax = 65
        local ylabels "0(10)60 65"
    }
    else {
        local ymax = ceil(`plotted_max' / 10) * 10

        if `ymax' <= `plotted_max' {
            local ymax = `ymax' + 10
        }

        if `ymax' > 100 {
            local ymax = 100
        }

        local ylabels "0(10)`ymax'"
    }

    local Ntxt : display %12.0fc `workerN`t''

    display as text ///
        "KBLI `k' (`kblilabel`t'') x KBJI `j' (`kbjilabel`t'')"

    display as result ///
        "N = " %12.0fc `workerN`t'' ///
        "; maximum plotted rate = " %9.3f `plotted_max' ///
        "; y-axis ceiling = " %9.2f `ymax'

    twoway ///
        (line __rate`t' _age if _yobcohort == 1, ///
            sort cmissing(n) ///
            lcolor("$jpal_navy") ///
            lpattern(solid) ///
            lwidth(medthin)) ///
        (line __rate`t' _age if _yobcohort == 2, ///
            sort cmissing(n) ///
            lcolor("$jpal_teal") ///
            lpattern(dash) ///
            lwidth(medthin)) ///
        (line __rate`t' _age if _yobcohort == 3, ///
            sort cmissing(n) ///
            lcolor("$jpal_green") ///
            lpattern(shortdash) ///
            lwidth(medthin)) ///
        (line __rate`t' _age if _yobcohort == 4, ///
            sort cmissing(n) ///
            lcolor("$jpal_yellow") ///
            lpattern(longdash) ///
            lwidth(medthin)) ///
        (line __rate`t' _age if _yobcohort == 5, ///
            sort cmissing(n) ///
            lcolor("$jpal_orange") ///
            lpattern(dot) ///
            lwidth(medthin)) ///
        (line __rate`t' _age if _yobcohort == 6, ///
            sort cmissing(n) ///
            lcolor("$jpal_gray") ///
            lpattern(dash_dot) ///
            lwidth(medthin)), ///
        by(_is_rural, ///
            cols(1) ///
            compact ///
            iscale(*0.90) ///
            title( ///
                "KBJI `j': `kbjilabel`t''" ///
                "KBLI `k': `kblilabel`t''", ///
                size(medsmall)) ///
            subtitle( ///
                "Employment by birth cohort, SAKERNAS 2004-2024" ///
                "Unweighted worker N = `Ntxt'", ///
                size(small)) ///
            note( ///
                "Population-denominator employment rate; y-axis adapted to occupation-industry cell.", ///
                size(vsmall)) ///
            graphregion(color(white))) ///
        xlabel(15 25 35 45 55 64, ///
            labsize(small)) ///
        ylabel(`ylabels', ///
            angle(horizontal) ///
            labsize(small)) ///
        yscale(range(0 `ymax')) ///
        xtitle("Mean age") ///
        ytitle("Employment rate (%)") ///
        legend( ///
            order( ///
                1 "1940-1949" ///
                2 "1950-1959" ///
                3 "1960-1969" ///
                4 "1970-1979" ///
                5 "1980-1989" ///
                6 "1990-1999") ///
            cols(1) ///
            size(vsmall) ///
            position(6)) ///
        graphregion(color(white) margin(small)) ///
        plotregion(margin(small)) ///
        xsize(12) ///
        ysize(12) ///
        name(cohort_rescaled_`t', replace)

    graph export ///
        "$sbtc/cohort_rescaled_`file`t''.png", ///
        replace width(2400)

    post `summary_post' ///
        (`t') ///
        (`k') ///
        (`j') ///
        ("`kblilabel`t''") ///
        ("`kbjilabel`t''") ///
        (`workerN`t'') ///
        (`plotted_max') ///
        (`ymax')
}

postclose `summary_post'

*=============================================================================*
* Compact final validation summary
*=============================================================================*

use `graph_summary', clear

format unweighted_N %12.0fc
format max_rate y_ceiling %9.3f

sort target

display as text ///
    "Targeted graph summary: codes, labels, N, plotted maximum, and y ceiling"

list kbli kbli_label kbji kbji_label ///
    unweighted_N max_rate y_ceiling, ///
    noobs abbreviate(28)

*=============================================================================*
* End
*=============================================================================*
