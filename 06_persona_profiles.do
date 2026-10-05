version 16
clear all
set more off
set linesize 130

*=============================================================================*
* SAKERNAS CAPSTONE LABOR_POLARIZATION
* (6) Synthesis - Persona creation
* Programmer: Tahtia Sazwara
*=============================================================================*

log using "$code/persona.smcl", replace

*=============================================================================*
* PERSONA PROFILES: DATA, PEERS, COHORTS, AND CONTEXT
*
* PURPOSE
*   1. THE PERSON: weighted characteristics in 2019-24.
*   2. THEIR PEERS: broad demographic comparisons and 2024 cell size.
*   3. THEIR GENERATION: rates across 1970s/1980s/1990s birth cohorts.
*   4. THE ECONOMY: 2004 vs 2024 sector/occupation changes.
*   5. DIAGNOSTICS: descriptive patterns that can inform case discussion.
*   The final table collects the main results from these sections.
*
* The personas are survey-cell composites, not individual histories.
* Adri = rural 25-34 middle-skill agriculture
* Urang = urban 25-34 KBLI 6, KBJI group 6
* Tirta = urban tertiary women 25-34 in high-skill occupations
*
* The final persona-specific earnings row follows each cell's modal
* employment type: Adri self-employed/employer; Urang and Tirta employees.
* The employee-only row is retained as a common wage benchmark.
* All earnings medians require positive observed real hourly earnings.
*=============================================================================*

local dataset "$output/sakernas_recons_2000_2024.dta"
* Load the 2004-24 working-age sample and only variables used below.
use _year _weight _age _is_female _is_rural _is_married ///
    _employed _unemployed _laborforce _educohort ///
    _kbji_harmonized _kbji_group _kbli_harmonized _kbli_broad ///
    _empltype _formal _hoursworked _real_hourly_earnings _yobcohort ///
    using "`dataset'", clear
keep if inrange(_year, 2004, 2024) & inrange(_age, 15, 64)

* Give binary characteristics readable category names in the Results window.
label define __persona_sex 0 "Male" 1 "Female", replace
label define __persona_married 0 "Not married" 1 "Married", replace
label define __persona_formal 0 "Informal" 1 "Formal", replace
label values _is_female __persona_sex
label values _is_married __persona_married
label values _formal __persona_formal

*=============================================================================*
* 0. REQUIRED VARIABLES, LABELS, AND COMMON SAMPLE MARKERS
*=============================================================================*

foreach v in _year _weight _age _is_female _is_rural _is_married ///
    _employed _unemployed _laborforce _educohort ///
    _kbji_harmonized _kbji_group _kbli_harmonized _kbli_broad ///
    _empltype _formal _hoursworked _real_hourly_earnings _yobcohort {
    confirm numeric variable `v'
}

quietly count if inrange(_year, 2004, 2024) & ///
    (missing(_weight) | _weight <= 0)
display as text "Missing/nonpositive weights, ages 15-64, 2004-24: " ///
    as result %12.0fc r(N)

quietly count if !missing(_kbli_harmonized) & ///
    !inrange(_kbli_harmonized, 1, 9)
display as text "Nonmissing KBLI values outside 1-9: " ///
    as result %12.0fc r(N)

quietly count if !missing(_kbji_harmonized) & ///
    !inrange(_kbji_harmonized, 1, 3)
display as text "Nonmissing skill-tier values outside 1-3: " ///
    as result %12.0fc r(N)

gen byte __recent = inrange(_year, 2019, 2024)
gen byte __longrun = inrange(_year, 2004, 2024)
gen byte __age2534 = inrange(_age, 25, 34)
gen byte __age1564 = inrange(_age, 15, 64)
gen byte __valid_weight = !missing(_weight) & _weight > 0

* Hard persona cells. Missing KBLI/KBJI values cannot satisfy these filters.
gen byte __p1 = __age2534 & _is_rural == 1 & _employed == 1 & ///
    _kbli_harmonized == 1 & _kbji_harmonized == 2

gen byte __p2 = __age2534 & _is_rural == 0 & _employed == 1 & ///
    _kbli_harmonized == 6 & _kbji_group == 6

gen byte __p3 = __age2534 & _is_rural == 0 & _is_female == 1 & ///
    _educohort == 4 & _employed == 1 & _kbji_harmonized == 1

* Broad demographic peer universes.
gen byte __peer1 = __age2534 & _is_rural == 1
gen byte __peer2 = __age2534 & _is_rural == 0
gen byte __peer3 = __age2534 & _is_rural == 0 & ///
    _is_female == 1 & _educohort == 4

* Valid comparable wage denominator used throughout:
* wage/salaried employees with positive observed real hourly earnings.
gen byte __valid_wage = _employed == 1 & _empltype == 2 & ///
    _real_hourly_earnings > 0 & !missing(_real_hourly_earnings)
gen byte __valid_earnings = _employed == 1 & ///
    _real_hourly_earnings > 0 & !missing(_real_hourly_earnings)

*=============================================================================*
* HELPER 1: WEIGHTED CONTINUOUS SUMMARY
*=============================================================================*

capture program drop __persona_cont
program define __persona_cont, rclass
    version 16
    syntax varname(numeric) [if], Title(string asis)
    marksample touse
    quietly replace `touse' = 0 if missing(_weight) | _weight <= 0 | ///
        missing(`varlist')
    quietly count if `touse'
    local N = r(N)

    display as text _newline `"`title'"'
    if `N' == 0 {
        display as text "  No valid observations"
        return scalar N = 0
        return scalar mean = .
        return scalar p25 = .
        return scalar p50 = .
        return scalar p75 = .
        exit
    }

    quietly summarize `varlist' if `touse' [aw=_weight], meanonly
    local mean = r(mean)
    quietly _pctile `varlist' if `touse' [aw=_weight], p(25 50 75)
    local p25 = r(r1)
    local p50 = r(r2)
    local p75 = r(r3)

    display as text "  Mean=" as result %12.2fc `mean' ///
        as text "  P25=" as result %12.2fc `p25' ///
        as text "  Median=" as result %12.2fc `p50' ///
        as text "  P75=" as result %12.2fc `p75' ///
        as text "  N=" as result %12.0fc `N'

    return scalar N = `N'
    return scalar mean = `mean'
    return scalar p25 = `p25'
    return scalar p50 = `p50'
    return scalar p75 = `p75'
end

*=============================================================================*
* HELPER 2: WEIGHTED CATEGORICAL DISTRIBUTION AND MODE
* Population is shown as an average annual population across represented years.
*=============================================================================*

capture program drop __persona_dist
program define __persona_dist, rclass
    version 16
    syntax varname(numeric) [if], Title(string asis)
    marksample touse
    quietly replace `touse' = 0 if missing(_weight) | _weight <= 0 | ///
        missing(`varlist')
    quietly count if `touse'
    local totalN = r(N)

    display as text _newline `"`title'"'
    if `totalN' == 0 {
        display as text "  No valid observations"
        return scalar N = 0
        return local mode_label "n/a"
        return scalar mode_share = .
        exit
    }

    preserve
        keep if `touse'
        egen byte __yrtag = tag(_year)
        quietly count if __yrtag == 1
        local nyears = r(N)
        gen double __one = 1
        collapse (sum) __population=_weight __n=__one, by(`varlist')
        replace __population = __population / `nyears'
        egen double __total = total(__population)
        gen double __share = 100 * __population / __total
        gsort -__share

        capture decode `varlist', gen(__category)
        if _rc tostring `varlist', gen(__category) usedisplayformat

        local mode_value = `varlist'[1]
        local mode_label `"`=__category[1]'"'
        local mode_share = __share[1]

        format __share %9.1f
        format __population %15.0fc
        format __n %12.0fc
        list __category __share __population __n, noobs abbreviate(32)
        display as text "  Modal category: " as result "`mode_label'" ///
            as text " (" as result %5.1f `mode_share' as text "%)"
    restore

    return scalar N = `totalN'
    return scalar mode_value = `mode_value'
    return scalar mode_share = `mode_share'
    return local mode_label `"`mode_label'"'
end

*=============================================================================*
* HELPER 3: DOMINANT JOINT KBLI x KBJI CELL
*=============================================================================*

capture program drop __persona_joint
program define __persona_joint, rclass
    version 16
    syntax [if], Title(string asis)
    marksample touse
    quietly replace `touse' = 0 if missing(_weight) | _weight <= 0 | ///
        missing(_kbli_harmonized, _kbji_group)

    display as text _newline `"`title'"'
    quietly count if `touse'
    if r(N) == 0 {
        display as text "  No valid observations"
        return local mode_label "n/a"
        return scalar mode_share = .
        exit
    }

    preserve
        keep if `touse'
        egen byte __yrtag = tag(_year)
        quietly count if __yrtag == 1
        local nyears = r(N)
        gen double __one = 1
        collapse (sum) __population=_weight __n=__one, ///
            by(_kbli_harmonized _kbji_group)
        replace __population = __population / `nyears'
        egen double __total = total(__population)
        gen double __share = 100 * __population / __total
        gsort -__share

        capture decode _kbli_harmonized, gen(__sector)
        if _rc tostring _kbli_harmonized, gen(__sector) usedisplayformat
        capture decode _kbji_group, gen(__occupation)
        if _rc tostring _kbji_group, gen(__occupation) usedisplayformat
        gen str160 __cell = __sector + " x " + __occupation

        local mode_kbli = _kbli_harmonized[1]
        local mode_kbji = _kbji_group[1]
        local mode_label `"`=__cell[1]'"'
        local mode_share = __share[1]

        format __share %9.1f
        format __population %15.0fc
        local last = min(5, _N)
        list __cell __share __population __n in 1/`last', noobs abbreviate(60)
    restore

    return scalar mode_kbli = `mode_kbli'
    return scalar mode_kbji = `mode_kbji'
    return scalar mode_share = `mode_share'
    return local mode_label `"`mode_label'"'
end

*=============================================================================*
* HELPER 4: TOP FIVE EMPLOYED KBLI x KBJI CELLS AMONG 2024 PEERS
*=============================================================================*

capture program drop __persona_topcells
program define __persona_topcells, rclass
    version 16
    syntax, Peer(varname numeric) KBLI(integer) KBJI(integer) ///
        Title(string asis)

    quietly summarize _weight if _year == 2024 & `peer' == 1 & ///
        !missing(_weight) & _weight > 0, meanonly
    local peerpop = r(sum)

    quietly summarize _weight if _year == 2024 & `peer' == 1 & ///
        _employed == 1 & !missing(_weight) & _weight > 0, meanonly
    local emppop = r(sum)

    display as text _newline `"`title'"'
    preserve
        keep if _year == 2024 & `peer' == 1 & _employed == 1 & ///
            !missing(_kbli_harmonized, _kbji_group, _weight) & _weight > 0
        gen double __one = 1
        collapse (sum) __population=_weight __n=__one, ///
            by(_kbli_harmonized _kbji_group)
        gen double __share_all = 100 * __population / `peerpop'
        gen double __share_emp = 100 * __population / `emppop'
        gsort -__population
        gen long __rank = _n

        capture decode _kbli_harmonized, gen(__sector)
        if _rc tostring _kbli_harmonized, gen(__sector) usedisplayformat
        capture decode _kbji_group, gen(__occupation)
        if _rc tostring _kbji_group, gen(__occupation) usedisplayformat
        gen str160 __cell = __sector + " x " + __occupation

        format __share_all __share_emp %9.1f
        format __population %15.0fc
        format __n %12.0fc
        local last = min(5, _N)
        list __rank __cell __share_all __share_emp __population __n ///
            in 1/`last', noobs abbreviate(60)

        quietly count if _kbli_harmonized == `kbli' & ///
            _kbji_group == `kbji'
        if r(N) > 0 {
            quietly summarize __rank if _kbli_harmonized == `kbli' & ///
                _kbji_group == `kbji', meanonly
            local target_rank = r(mean)
        }
        else local target_rank = .

        quietly count if !(_kbli_harmonized == `kbli' & ///
            _kbji_group == `kbji')
        if r(N) > 0 {
            local altobs = 1
            if _kbli_harmonized[1] == `kbli' & ///
                _kbji_group[1] == `kbji' local altobs = 2
            local alt_label `"`=__cell[`altobs']'"'
            local alt_share = __share_all[`altobs']
        }
        else {
            local alt_label "n/a"
            local alt_share = .
        }
    restore

    display as text "  Persona-cell rank: " as result %6.0f `target_rank'
    display as text "  Closest alternative: " as result "`alt_label'" ///
        as text " (" as result %5.1f `alt_share' as text "% of peers)"

    return scalar target_rank = `target_rank'
    return scalar alt_share = `alt_share'
    return local alt_label `"`alt_label'"'
end

*=============================================================================*
* HELPER 5: POPULATION-DENOMINATOR RATE BY 10-YEAR BIRTH COHORT
*=============================================================================*

capture program drop __persona_cohort
program define __persona_cohort, rclass
    version 16
    syntax, Denom(varname numeric) Outcome(varname numeric) Title(string asis)

    display as text _newline `"`title'"'
    display as text "  Denominator: indicated population, age 25-34, 2004-2024"

    forvalues c = 4/6 {
        quietly summarize _weight if __longrun == 1 & __age2534 == 1 & ///
            `denom' == 1 & _yobcohort == `c' & __valid_weight == 1, meanonly
        local den = r(sum)

        quietly summarize _weight if __longrun == 1 & __age2534 == 1 & ///
            `denom' == 1 & `outcome' == 1 & _yobcohort == `c' & ///
            __valid_weight == 1, meanonly
        local num = r(sum)

        quietly count if __longrun == 1 & __age2534 == 1 & ///
            `denom' == 1 & `outcome' == 1 & _yobcohort == `c' & ///
            __valid_weight == 1
        local N = r(N)

        quietly levelsof _year if __longrun == 1 & __age2534 == 1 & ///
            `denom' == 1 & _yobcohort == `c' & __valid_weight == 1, ///
            local(years)
        local ny : word count `years'

        local rate = cond(`den' > 0, 100 * `num' / `den', .)
        local avgpop = cond(`ny' > 0, `num' / `ny', .)
        local support = cond(`N' < 30, "VERY SMALL", ///
            cond(`N' < 100, "NOISY", "SUPPORTED"))

        local cohort_label = cond(`c' == 4, "1970s", ///
            cond(`c' == 5, "1980s", "1990s"))
        display as text "  `cohort_label': rate=" as result %6.2f `rate' ///
            as text "%  avg annual population=" as result %14.0fc `avgpop' ///
            as text "  N=" as result %10.0fc `N' ///
            as text "  [" as result "`support'" as text "]"

        return scalar rate`c' = `rate'
        return scalar pop`c' = `avgpop'
        return scalar N`c' = `N'
        local rate`c' = `rate'
    }

    local d54 = `rate5' - `rate4'
    local d65 = `rate6' - `rate5'
    local d64 = `rate6' - `rate4'

    return scalar d54 = `d54'
    return scalar d65 = `d65'
    return scalar d64 = `d64'

    display as text "  1980s - 1970s=" as result %7.2f `d54' ///
        as text " pp; 1990s - 1980s=" as result %7.2f `d65' ///
        as text " pp; 1990s - 1970s=" as result %7.2f `d64' as text " pp"
end

*=============================================================================*
* HELPER 6: RATE/SHARE IN ONE SURVEY YEAR
*=============================================================================*

capture program drop __persona_yearrate
program define __persona_yearrate, rclass
    version 16
    syntax, Denom(varname numeric) Outcome(varname numeric) ///
        Year(integer) Title(string asis)

    quietly summarize _weight if _year == `year' & `denom' == 1 & ///
        __valid_weight == 1, meanonly
    local den = r(sum)
    quietly summarize _weight if _year == `year' & `denom' == 1 & ///
        `outcome' == 1 & __valid_weight == 1, meanonly
    local num = r(sum)
    quietly count if _year == `year' & `denom' == 1 & `outcome' == 1 & ///
        __valid_weight == 1
    local N = r(N)
    local rate = cond(`den' > 0, 100 * `num' / `den', .)

    display as text `"  `title', `year': "' as result %7.2f `rate' ///
        as text "%  population=" as result %15.0fc `num' ///
        as text "  N=" as result %10.0fc `N'

    return scalar rate = `rate'
    return scalar population = `num'
    return scalar N = `N'
end

*=============================================================================*
* COMMON OUTCOME MARKERS USED BY COHORT AND ECONOMY SECTIONS
*=============================================================================*

gen byte __p1_gen = _employed == 1 & _kbli_harmonized == 1 & ///
    _kbji_harmonized == 2
gen byte __p2_gen = _employed == 1 & _kbli_harmonized == 6 & ///
    _kbji_group == 6
gen byte __p3_gen = _employed == 1 & _kbji_harmonized == 1

gen byte __ag_emp = _employed == 1 & _kbli_harmonized == 1
gen byte __kbli6_emp = _employed == 1 & _kbli_harmonized == 6
gen byte __group6_emp = _employed == 1 & _kbji_group == 6
gen byte __high_emp = _employed == 1 & _kbji_harmonized == 1
gen byte __middle_emp = _employed == 1 & _kbji_harmonized == 2

gen byte __ruralpop = _is_rural == 1
gen byte __urbanpop = _is_rural == 0
gen byte __urbanwomen = _is_rural == 0 & _is_female == 1
gen byte __urbanwomen1564 = _is_rural == 0 & _is_female == 1 & __age1564 == 1
gen byte __urbanwomen_tertiary = _is_rural == 0 & _is_female == 1 & ///
    _educohort == 4
gen byte __allemployed = _employed == 1 & __age1564 == 1
gen byte __ruralemployed = _employed == 1 & __age1564 == 1 & _is_rural == 1
gen byte __urbanemployed = _employed == 1 & __age1564 == 1 & _is_rural == 0
gen byte __kbli6den = _employed == 1 & __age1564 == 1 & ///
    _kbli_harmonized == 6
gen byte __tertiary_urbanwomen_emp = _employed == 1 & __age1564 == 1 & ///
    _is_rural == 0 & _is_female == 1 & _educohort == 4

*=============================================================================*
* ADRI (PERSONA 1) - RURAL AGRICULTURAL MIDDLE
*=============================================================================*

display as text _newline(2) "===================================================================="
display as text "ADRI (PERSONA 1) - RURAL AGRICULTURAL MIDDLE"
display as text "===================================================================="

display as text _newline "1. THE PERSON"
display as text "Hard filter: rural, age 25-34, employed, KBLI 1, middle skill; 2019-2024"

__persona_cont _age if __recent == 1 & __p1 == 1, title("Representative age")
local p1_age_mean = r(mean)

__persona_dist _is_female if __recent == 1 & __p1 == 1, ///
    title("Sex distribution")
local p1_sex `"`r(mode_label)'"'

__persona_dist _educohort if __recent == 1 & __p1 == 1, ///
    title("Education distribution")
local p1_edu `"`r(mode_label)'"'

__persona_dist _is_married if __recent == 1 & __p1 == 1, ///
    title("Marital status: 1=married, 0=not married")
quietly summarize _is_married if __recent == 1 & __p1 == 1 ///
    [aw=_weight], meanonly
local p1_married = 100 * r(mean)

display as text _newline "Sector: fixed by hard filter - KBLI 1"
__persona_dist _kbji_group if __recent == 1 & __p1 == 1, ///
    title("Exact occupation-group distribution")
local p1_occ `"`r(mode_label)'"'
local p1_occ_value = r(mode_value)

__persona_dist _empltype if __recent == 1 & __p1 == 1, ///
    title("Employment-type distribution")
local p1_empltype `"`r(mode_label)'"'
local p1_type_share = r(mode_share)

__persona_dist _formal if __recent == 1 & __p1 == 1, ///
    title("Formality code: wage employees=1, other types=0 in these waves")
quietly summarize _formal if __recent == 1 & __p1 == 1 ///
    [aw=_weight], meanonly
local p1_formal = 100 * r(mean)

__persona_cont _hoursworked if __recent == 1 & __p1 == 1 & ///
    !missing(_hoursworked), title("Weekly hours")
local p1_hours = r(p50)

__persona_cont _real_hourly_earnings if __recent == 1 & __p1 == 1 & ///
    __valid_wage == 1, ///
    title("Real hourly earnings - wage/salaried employees with positive earnings")
local p1_wage = r(p50)
__persona_cont _real_hourly_earnings if __recent == 1 & __p1 == 1 & ///
    _empltype == 1 & __valid_earnings == 1, ///
    title("Real hourly earnings - self-employed/employers with positive earnings")
local p1_type_earnings = r(p50)
__persona_cont _real_hourly_earnings if __recent == 1 & __p1 == 1 & ///
    __valid_earnings == 1, ///
    title("Real hourly earnings - all employed with positive observed earnings")
local p1_earnings = r(p50)

quietly summarize _weight if __recent == 1 & __p1 == 1 & ///
    _empltype == 2 & __valid_weight == 1, meanonly
local p1_wageemp_pop = r(sum)
quietly summarize _weight if __recent == 1 & __p1 == 1 & ///
    __valid_weight == 1, meanonly
local p1_cell_pop_pool = r(sum)
local p1_wage_coverage = 100 * `p1_wageemp_pop' / `p1_cell_pop_pool'
display as text "  Wage-employee share of exact cell: " ///
    as result %6.1f `p1_wage_coverage' as text "%"
quietly summarize _weight if __recent == 1 & __p1 == 1 & ///
    _empltype == 1 & __valid_weight == 1, meanonly
local p1_type_pop = r(sum)
quietly summarize _weight if __recent == 1 & __p1 == 1 & ///
    _empltype == 1 & __valid_earnings == 1 & __valid_weight == 1, ///
    meanonly
local p1_type_earnings_coverage = 100 * r(sum) / `p1_type_pop'
display as text "  Positive-earnings coverage among self-employed/employers: " ///
    as result %6.1f `p1_type_earnings_coverage' as text "%"
quietly summarize _weight if __recent == 1 & __p1 == 1 & ///
    __valid_earnings == 1 & __valid_weight == 1, meanonly
local p1_earner_coverage = 100 * r(sum) / `p1_cell_pop_pool'
display as text "  Positive-earnings coverage of exact cell: " ///
    as result %6.1f `p1_earner_coverage' as text "%"

display as text _newline "2. THEIR PEERS"
display as text "Peer universe: all rural people age 25-34"

quietly summarize _employed if __recent == 1 & __peer1 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p1_peer_emp = 100 * r(mean)
quietly summarize _unemployed if __recent == 1 & __peer1 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p1_peer_unemp_pop = 100 * r(mean)
quietly summarize _laborforce if __recent == 1 & __peer1 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p1_peer_olf = 100 * (1 - r(mean))
quietly summarize _unemployed if __recent == 1 & __peer1 == 1 & ///
    _laborforce == 1 & __valid_weight == 1 [aw=_weight], meanonly
local p1_peer_urate = 100 * r(mean)

display as text "  Employed/population=" as result %6.1f `p1_peer_emp' ///
    as text "%  Unemployed/population=" as result %6.1f `p1_peer_unemp_pop' ///
    as text "%  Outside LF=" as result %6.1f `p1_peer_olf' as text "%"
display as text "  Conventional unemployment rate among labour force=" ///
    as result %6.1f `p1_peer_urate' as text "%"

quietly summarize _weight if _year == 2024 & __peer1 == 1 & ///
    __valid_weight == 1, meanonly
local p1_peerpop24 = r(sum)
quietly summarize _weight if _year == 2024 & __p1 == 1 & ///
    __valid_weight == 1, meanonly
local p1_exactpop24 = r(sum)
quietly summarize _weight if _year == 2024 & __peer1 == 1 & ///
    _employed == 1 & __valid_weight == 1, meanonly
local p1_peeremppop24 = r(sum)
local p1_prev_all = 100 * `p1_exactpop24' / `p1_peerpop24'
local p1_prev_emp = 100 * `p1_exactpop24' / `p1_peeremppop24'

display as text "  2024 peer population=" as result %15.0fc `p1_peerpop24'
display as text "  2024 exact-cell population=" as result %15.0fc `p1_exactpop24'
display as text "  Exact cell / all peers=" as result %6.1f `p1_prev_all' ///
    as text "%  Exact cell / employed peers=" as result %6.1f `p1_prev_emp' as text "%"

__persona_topcells, peer(__peer1) kbli(1) kbji(`p1_occ_value') ///
    title("Top five employed KBLI x KBJI cells among 2024 peers")

__persona_dist _kbji_harmonized if __recent == 1 & __peer1 == 1 & ///
    _employed == 1, title("Skill distribution of classified employed peers")
__persona_dist _kbli_broad if __recent == 1 & __peer1 == 1 & ///
    _employed == 1, title("Broad-sector distribution of classified employed peers")

__persona_cont _hoursworked if __recent == 1 & __peer1 == 1 & ///
    _employed == 1 & !missing(_hoursworked), title("Peer weekly hours")
local p1_peer_hours = r(p50)
display as text "  Persona - peer median-hours difference=" ///
    as result %7.1f (`p1_hours' - `p1_peer_hours')

__persona_cont _real_hourly_earnings if __recent == 1 & __peer1 == 1 & ///
    __valid_wage == 1, title("Comparable peer real hourly earnings")
local p1_peer_wage = r(p50)
local p1_wage_ratio = `p1_wage' / `p1_peer_wage'
display as text "  Persona / peer median-real-wage ratio=" ///
    as result %7.2f `p1_wage_ratio'

display as text _newline "3. THEIR GENERATION"
__persona_cohort, denom(__ruralpop) outcome(__p1_gen) ///
    title("Middle-skill agricultural employment among rural people")
local p1_rate70 = r(rate4)
local p1_rate80 = r(rate5)
local p1_rate90 = r(rate6)
local p1_change = r(d64)

__persona_cohort, denom(__ruralpop) outcome(__ag_emp) ///
    title("Supporting rate: agricultural employment among rural people")
__persona_cohort, denom(__ruralpop) outcome(__middle_emp) ///
    title("Supporting rate: middle-skill employment among rural people")

display as text _newline "4. THE ECONOMY AROUND THEM"
foreach y in 2004 2024 {
    __persona_yearrate, denom(__allemployed) outcome(__ag_emp) year(`y') ///
        title("Agriculture share of national employment")
    if `y' == 2004 local p1_ag04 = r(rate)
    if `y' == 2024 local p1_ag24 = r(rate)
    __persona_yearrate, denom(__ruralemployed) outcome(__ag_emp) year(`y') ///
        title("Agriculture share of rural employment")
    __persona_yearrate, denom(__allemployed) outcome(__middle_emp) year(`y') ///
        title("Middle-skill share of national employment")
    __persona_yearrate, denom(__ruralemployed) outcome(__middle_emp) year(`y') ///
        title("Middle-skill share of rural employment")
    __persona_yearrate, denom(__allemployed) outcome(__p1_gen) year(`y') ///
        title("Middle-skill agricultural share of national employment")
    if `y' == 2004 local p1_joint04 = r(rate)
    if `y' == 2024 local p1_joint24 = r(rate)
}
display as text "  Existing reliable between/within decomposition not invoked here."

display as text _newline "5. POSSIBLE EXPLANATION - EMPIRICAL DIAGNOSTICS"
display as text "All statements below are descriptive and only consistent with possible mechanisms."
display as text "  Agriculture employment change, 2024-2004=" ///
    as result %7.2f (`p1_ag24' - `p1_ag04') as text " pp"
display as text "  Agricultural middle-skill change, 2024-2004=" ///
    as result %7.2f (`p1_joint24' - `p1_joint04') as text " pp"

foreach c in 4 5 6 {
    __persona_dist _educohort if __longrun == 1 & __age2534 == 1 & ///
        _is_rural == 1 & _yobcohort == `c', ///
        title("Rural education distribution, cohort `c'")
}
foreach y in 2004 2024 {
    __persona_dist _kbji_group if _year == `y' & __age1564 == 1 & ///
        _employed == 1 & _kbli_harmonized == 1, ///
        title("Within-agriculture occupation distribution, `y'")
    __persona_cont _real_hourly_earnings if _year == `y' & ///
        __age1564 == 1 & _kbli_harmonized == 1 & ///
        _kbji_harmonized == 2 & __valid_wage == 1, ///
        title("Agricultural middle-skill real hourly earnings, `y'; wage employees only")
}
display as text "  Wage-employee coverage=" as result %6.1f `p1_wage_coverage' ///
    as text "%: wage results do not represent all self-employed/unpaid agricultural labour."

*=============================================================================*
* URANG (PERSONA 2) - URBAN SERVICE ECONOMY
*=============================================================================*

display as text _newline(2) "===================================================================="
display as text "URANG (PERSONA 2) - URBAN SERVICE ECONOMY"
display as text "===================================================================="

display as text _newline "1. THE PERSON"
display as text "Hard filter: urban, age 25-34, employed, KBLI 6, KBJI group 6; 2019-2024"

__persona_cont _age if __recent == 1 & __p2 == 1, title("Representative age")
local p2_age_mean = r(mean)
__persona_dist _is_female if __recent == 1 & __p2 == 1, title("Sex distribution")
local p2_sex `"`r(mode_label)'"'
__persona_dist _educohort if __recent == 1 & __p2 == 1, title("Education distribution")
local p2_edu `"`r(mode_label)'"'
__persona_dist _is_married if __recent == 1 & __p2 == 1, ///
    title("Marital status: 1=married, 0=not married")
quietly summarize _is_married if __recent == 1 & __p2 == 1 ///
    [aw=_weight], meanonly
local p2_married = 100 * r(mean)
display as text "  Sector: fixed - KBLI 6"
display as text "  Occupation: fixed - KBJI group 6"
__persona_dist _empltype if __recent == 1 & __p2 == 1, title("Employment type")
local p2_empltype `"`r(mode_label)'"'
local p2_type_share = r(mode_share)
__persona_dist _formal if __recent == 1 & __p2 == 1, ///
    title("Formality code: wage employees=1, other types=0 in these waves")
quietly summarize _formal if __recent == 1 & __p2 == 1 ///
    [aw=_weight], meanonly
local p2_formal = 100 * r(mean)
__persona_cont _hoursworked if __recent == 1 & __p2 == 1 & ///
    !missing(_hoursworked), title("Weekly hours")
local p2_hours = r(p50)
__persona_cont _real_hourly_earnings if __recent == 1 & __p2 == 1 & ///
    __valid_wage == 1, ///
    title("Real hourly earnings - wage/salaried employees with positive earnings")
local p2_wage = r(p50)
__persona_cont _real_hourly_earnings if __recent == 1 & __p2 == 1 & ///
    __valid_earnings == 1, ///
    title("Real hourly earnings - all employed with positive observed earnings")
local p2_earnings = r(p50)

display as text _newline "2. THEIR PEERS"
display as text "Peer universe: all urban people age 25-34"

quietly summarize _employed if __recent == 1 & __peer2 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p2_peer_emp = 100 * r(mean)
quietly summarize _unemployed if __recent == 1 & __peer2 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p2_peer_unemp_pop = 100 * r(mean)
quietly summarize _laborforce if __recent == 1 & __peer2 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p2_peer_olf = 100 * (1 - r(mean))
quietly summarize _unemployed if __recent == 1 & __peer2 == 1 & ///
    _laborforce == 1 & __valid_weight == 1 [aw=_weight], meanonly
local p2_peer_urate = 100 * r(mean)

display as text "  Employed/population=" as result %6.1f `p2_peer_emp' ///
    as text "%  Unemployed/population=" as result %6.1f `p2_peer_unemp_pop' ///
    as text "%  Outside LF=" as result %6.1f `p2_peer_olf' as text "%"
display as text "  Conventional unemployment rate=" ///
    as result %6.1f `p2_peer_urate' as text "%"

quietly summarize _weight if _year == 2024 & __peer2 == 1 & ///
    __valid_weight == 1, meanonly
local p2_peerpop24 = r(sum)
quietly summarize _weight if _year == 2024 & __p2 == 1 & ///
    __valid_weight == 1, meanonly
local p2_exactpop24 = r(sum)
quietly summarize _weight if _year == 2024 & __peer2 == 1 & ///
    _employed == 1 & __valid_weight == 1, meanonly
local p2_peeremppop24 = r(sum)
local p2_prev_all = 100 * `p2_exactpop24' / `p2_peerpop24'
local p2_prev_emp = 100 * `p2_exactpop24' / `p2_peeremppop24'

display as text "  2024 peer population=" as result %15.0fc `p2_peerpop24'
display as text "  2024 exact-cell population=" as result %15.0fc `p2_exactpop24'
display as text "  Exact cell / all peers=" as result %6.1f `p2_prev_all' ///
    as text "%  Exact cell / employed peers=" as result %6.1f `p2_prev_emp' as text "%"

__persona_topcells, peer(__peer2) kbli(6) kbji(6) ///
    title("Top five employed KBLI x KBJI cells among 2024 peers")

__persona_dist _kbji_harmonized if __recent == 1 & __peer2 == 1 & ///
    _employed == 1, title("Skill distribution of classified employed peers")
__persona_dist _kbli_broad if __recent == 1 & __peer2 == 1 & ///
    _employed == 1, title("Broad-sector distribution of classified employed peers")

__persona_cont _hoursworked if __recent == 1 & __peer2 == 1 & ///
    _employed == 1 & !missing(_hoursworked), title("Peer weekly hours")
local p2_peer_hours = r(p50)
display as text "  Persona - peer median-hours difference=" ///
    as result %7.1f (`p2_hours' - `p2_peer_hours')
__persona_cont _real_hourly_earnings if __recent == 1 & __peer2 == 1 & ///
    __valid_wage == 1, title("Comparable peer real hourly earnings")
local p2_peer_wage = r(p50)
local p2_wage_ratio = `p2_wage' / `p2_peer_wage'
display as text "  Persona / peer median-real-wage ratio=" ///
    as result %7.2f `p2_wage_ratio'

display as text _newline "3. THEIR GENERATION"
__persona_cohort, denom(__urbanpop) outcome(__p2_gen) ///
    title("KBLI 6 x KBJI group 6 employment among urban people")
local p2_rate70 = r(rate4)
local p2_rate80 = r(rate5)
local p2_rate90 = r(rate6)
local p2_change = r(d64)
__persona_cohort, denom(__urbanpop) outcome(__kbli6_emp) ///
    title("Supporting rate: KBLI 6 employment among urban people")
__persona_cohort, denom(__urbanpop) outcome(__group6_emp) ///
    title("Supporting rate: KBJI group 6 employment among urban people")

display as text _newline "4. THE ECONOMY AROUND THEM"
foreach y in 2004 2024 {
    __persona_yearrate, denom(__allemployed) outcome(__kbli6_emp) year(`y') ///
        title("KBLI 6 share of total employment")
    if `y' == 2004 local p2_kbli604 = r(rate)
    if `y' == 2024 local p2_kbli624 = r(rate)
    __persona_yearrate, denom(__urbanemployed) outcome(__kbli6_emp) year(`y') ///
        title("KBLI 6 share of urban employment")
    foreach j in 4 6 3 2 {
        gen byte __temp_occ = _employed == 1 & __age1564 == 1 & ///
            _kbli_harmonized == 6 & _kbji_group == `j'
        __persona_yearrate, denom(__kbli6den) outcome(__temp_occ) year(`y') ///
            title("KBJI group `j' share inside KBLI 6")
        if `j' == 6 & `y' == 2004 local p2_group604 = r(rate)
        if `j' == 6 & `y' == 2024 local p2_group624 = r(rate)
        drop __temp_occ
    }
}
display as text "  Existing reliable between/within decomposition not invoked here."

display as text _newline "5. POSSIBLE EXPLANATION - EMPIRICAL DIAGNOSTICS"
display as text "All statements below are descriptive and only consistent with possible mechanisms."
display as text "  KBLI 6 employment-share change=" ///
    as result %7.2f (`p2_kbli624' - `p2_kbli604') as text " pp"
display as text "  KBJI group 6 share change inside KBLI 6=" ///
    as result %7.2f (`p2_group624' - `p2_group604') as text " pp"
foreach c in 4 5 6 {
    __persona_dist _educohort if __longrun == 1 & __age2534 == 1 & ///
        _yobcohort == `c' & _employed == 1 & _kbli_harmonized == 6 & ///
        _kbji_group == 6, title("Education of KBLI 6 x KBJI 6 workers, cohort `c'")
}
display as text "  Current modal employment type: " as result "`p2_empltype'"
display as text "  Current formal share=" as result %6.1f `p2_formal' as text "%"
display as text "  Current median hours=" as result %7.1f `p2_hours'
display as text "  Current median real hourly wage=" as result %12.0fc `p2_wage'

*=============================================================================*
* TIRTA (PERSONA 3) - EDUCATED UPPER END
*=============================================================================*

display as text _newline(2) "===================================================================="
display as text "TIRTA (PERSONA 3) - EDUCATED UPPER END"
display as text "===================================================================="

display as text _newline "1. THE PERSON"
display as text "Hard filter: urban, female, tertiary, age 25-34, employed, high skill; 2019-2024"

__persona_cont _age if __recent == 1 & __p3 == 1, title("Representative age")
local p3_age_mean = r(mean)
display as text "  Sex: Female (fixed)"
display as text "  Education: Tertiary (fixed)"
__persona_dist _is_married if __recent == 1 & __p3 == 1, ///
    title("Marital status: 1=married, 0=not married")
quietly summarize _is_married if __recent == 1 & __p3 == 1 ///
    [aw=_weight], meanonly
local p3_married = 100 * r(mean)
__persona_dist _kbli_harmonized if __recent == 1 & __p3 == 1, ///
    title("Exact-sector distribution")
local p3_sector `"`r(mode_label)'"'
__persona_dist _kbji_group if __recent == 1 & __p3 == 1, ///
    title("Exact occupation-group distribution")
local p3_occ `"`r(mode_label)'"'
__persona_joint if __recent == 1 & __p3 == 1, ///
    title("Dominant exact KBLI x KBJI group")
local p3_joint_k = r(mode_kbli)
local p3_joint_j = r(mode_kbji)
__persona_dist _empltype if __recent == 1 & __p3 == 1, title("Employment type")
local p3_empltype `"`r(mode_label)'"'
local p3_type_share = r(mode_share)
__persona_dist _formal if __recent == 1 & __p3 == 1, ///
    title("Formality code: wage employees=1, other types=0 in these waves")
quietly summarize _formal if __recent == 1 & __p3 == 1 ///
    [aw=_weight], meanonly
local p3_formal = 100 * r(mean)
__persona_cont _hoursworked if __recent == 1 & __p3 == 1 & ///
    !missing(_hoursworked), title("Weekly hours")
local p3_hours = r(p50)
__persona_cont _real_hourly_earnings if __recent == 1 & __p3 == 1 & ///
    __valid_wage == 1, ///
    title("Real hourly earnings - wage/salaried employees with positive earnings")
local p3_wage = r(p50)
__persona_cont _real_hourly_earnings if __recent == 1 & __p3 == 1 & ///
    __valid_earnings == 1, ///
    title("Real hourly earnings - all employed with positive observed earnings")
local p3_earnings = r(p50)

display as text _newline "2. THEIR PEERS"
display as text "Peer universe: urban tertiary-educated women age 25-34"

quietly summarize _employed if __recent == 1 & __peer3 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p3_peer_emp = 100 * r(mean)
quietly summarize _unemployed if __recent == 1 & __peer3 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p3_peer_unemp_pop = 100 * r(mean)
quietly summarize _laborforce if __recent == 1 & __peer3 == 1 & ///
    __valid_weight == 1 [aw=_weight], meanonly
local p3_peer_olf = 100 * (1 - r(mean))
quietly summarize _unemployed if __recent == 1 & __peer3 == 1 & ///
    _laborforce == 1 & __valid_weight == 1 [aw=_weight], meanonly
local p3_peer_urate = 100 * r(mean)

display as text "  Employed/population=" as result %6.1f `p3_peer_emp' ///
    as text "%  Unemployed/population=" as result %6.1f `p3_peer_unemp_pop' ///
    as text "%  Outside LF=" as result %6.1f `p3_peer_olf' as text "%"
display as text "  Conventional unemployment rate=" ///
    as result %6.1f `p3_peer_urate' as text "%"

quietly summarize _weight if _year == 2024 & __peer3 == 1 & ///
    __valid_weight == 1, meanonly
local p3_peerpop24 = r(sum)
quietly summarize _weight if _year == 2024 & __p3 == 1 & ///
    __valid_weight == 1, meanonly
local p3_exactpop24 = r(sum)
quietly summarize _weight if _year == 2024 & __peer3 == 1 & ///
    _employed == 1 & __valid_weight == 1, meanonly
local p3_peeremppop24 = r(sum)
local p3_prev_all = 100 * `p3_exactpop24' / `p3_peerpop24'
local p3_prev_emp = 100 * `p3_exactpop24' / `p3_peeremppop24'

display as text "  2024 peer population=" as result %15.0fc `p3_peerpop24'
display as text "  2024 exact-cell population=" as result %15.0fc `p3_exactpop24'
display as text "  Exact cell / all peers=" as result %6.1f `p3_prev_all' ///
    as text "%  Exact cell / employed peers=" as result %6.1f `p3_prev_emp' as text "%"

__persona_topcells, peer(__peer3) kbli(`p3_joint_k') kbji(`p3_joint_j') ///
    title("Top five employed KBLI x KBJI cells among 2024 peers")

__persona_dist _kbji_harmonized if __recent == 1 & __peer3 == 1 & ///
    _employed == 1, title("Skill distribution of classified employed peers")
__persona_dist _kbli_broad if __recent == 1 & __peer3 == 1 & ///
    _employed == 1, title("Broad-sector distribution of classified employed peers")
__persona_cont _hoursworked if __recent == 1 & __peer3 == 1 & ///
    _employed == 1 & !missing(_hoursworked), title("Peer weekly hours")
local p3_peer_hours = r(p50)
display as text "  Persona - peer median-hours difference=" ///
    as result %7.1f (`p3_hours' - `p3_peer_hours')
__persona_cont _real_hourly_earnings if __recent == 1 & __peer3 == 1 & ///
    __valid_wage == 1, title("Comparable peer real hourly earnings")
local p3_peer_wage = r(p50)
local p3_wage_ratio = `p3_wage' / `p3_peer_wage'
display as text "  Persona / peer median-real-wage ratio=" ///
    as result %7.2f `p3_wage_ratio'

display as text _newline "3. THEIR GENERATION"
__persona_cohort, denom(__urbanwomen_tertiary) outcome(__p3_gen) ///
    title("High-skill employment among tertiary-educated urban women")
local p3_rate70 = r(rate4)
local p3_rate80 = r(rate5)
local p3_rate90 = r(rate6)
local p3_change = r(d64)

gen byte __tertiary_population = _educohort == 4
__persona_cohort, denom(__urbanwomen) outcome(__tertiary_population) ///
    title("Supporting rate: tertiary education among urban women")
__persona_cohort, denom(__urbanwomen) outcome(__high_emp) ///
    title("Supporting rate: high-skill employment among all urban women")

display as text _newline "4. THE ECONOMY AROUND THEM"
foreach y in 2004 2024 {
    __persona_yearrate, denom(__urbanwomen1564) outcome(__tertiary_population) ///
        year(`y') title("Tertiary education share among urban women")
    if `y' == 2004 local p3_tertiary04 = r(rate)
    if `y' == 2024 local p3_tertiary24 = r(rate)
    foreach s in 1 2 3 {
        gen byte __temp_skill = _employed == 1 & __age1564 == 1 & ///
            _is_rural == 0 & _is_female == 1 & _kbji_harmonized == `s'
        __persona_yearrate, denom(__urbanwomen1564) outcome(__temp_skill) ///
            year(`y') title("Skill tier `s' employment rate among urban women")
        if `s' == 1 & `y' == 2004 local p3_high04 = r(rate)
        if `s' == 1 & `y' == 2024 local p3_high24 = r(rate)
        drop __temp_skill

        gen byte __temp_skill_ter = _employed == 1 & __age1564 == 1 & ///
            _is_rural == 0 & _is_female == 1 & _educohort == 4 & ///
            _kbji_harmonized == `s'
        __persona_yearrate, denom(__tertiary_urbanwomen_emp) ///
            outcome(__temp_skill_ter) year(`y') ///
            title("Skill tier `s' share among employed tertiary urban women")
        drop __temp_skill_ter
    }
}

display as text _newline "Education composition of high-skill urban-women employment"
forvalues c = 4/6 {
    __persona_dist _educohort if __longrun == 1 & __age2534 == 1 & ///
        _yobcohort == `c' & _is_rural == 0 & _is_female == 1 & ///
        _employed == 1 & _kbji_harmonized == 1, title("Cohort `c'")
}

display as text _newline "5. POSSIBLE EXPLANATION - EMPIRICAL DIAGNOSTICS"
display as text "All statements below are descriptive and only consistent with possible mechanisms."
display as text "  Urban-women tertiary-share change=" ///
    as result %7.2f (`p3_tertiary24' - `p3_tertiary04') as text " pp"
display as text "  Urban-women high-skill employment change=" ///
    as result %7.2f (`p3_high24' - `p3_high04') as text " pp"
display as text "  Current labour-force participation=" ///
    as result %6.1f (100 - `p3_peer_olf') as text "%"
display as text "  Current employment=" as result %6.1f `p3_peer_emp' as text "%"
display as text "  Current unemployment/population=" ///
    as result %6.1f `p3_peer_unemp_pop' as text "%"
display as text "  Current outside labour force=" ///
    as result %6.1f `p3_peer_olf' as text "%"
display as text "  Current married share=" ///
    as result %6.1f `p3_married' as text "%"

local childvar ""
foreach candidate in _child_under5 _has_child_under5 _own_child_under5 {
    capture confirm numeric variable `candidate'
    if !_rc & "`childvar'" == "" local childvar "`candidate'"
}
if "`childvar'" != "" {
    __persona_dist `childvar' if __recent == 1 & __peer3 == 1, ///
        title("Documented child-under-5 indicator")
    quietly summarize _employed if __recent == 1 & __peer3 == 1 & ///
        `childvar' == 0 [aw=_weight], meanonly
    display as text "  Employment without child under 5=" ///
        as result %6.1f (100 * r(mean)) as text "%"
    quietly summarize _employed if __recent == 1 & __peer3 == 1 & ///
        `childvar' == 1 [aw=_weight], meanonly
    display as text "  Employment with child under 5=" ///
        as result %6.1f (100 * r(mean)) as text "%"
}
else display as text "  Child-under-5 statistics omitted: no documented existing variable found."

*=============================================================================*
* VALIDATION SUMMARY
*=============================================================================*

display as text _newline(2) "===================================================================="
display as text "VALIDATION SUMMARY"
display as text "===================================================================="

foreach p in 1 2 3 {
    if `p' == 1 local peer __peer1
    if `p' == 2 local peer __peer2
    if `p' == 3 local peer __peer3
    if `p' == 1 local cell __p1
    if `p' == 2 local cell __p2
    if `p' == 3 local cell __p3

    quietly count if _year == 2024 & `cell' == 1
    local N = r(N)
    local support = cond(`N' < 30, "VERY SMALL", ///
        cond(`N' < 100, "NOISY", "SUPPORTED"))
    display as text "Persona `p': 2024 N=" as result %10.0fc `N' ///
        as text "  [" as result "`support'" as text "]"

    quietly summarize _weight if _year == 2024 & `cell' == 1 & ///
        __valid_weight == 1, meanonly
    local cellpop = r(sum)
    quietly summarize _weight if _year == 2024 & `peer' == 1 & ///
        __valid_weight == 1, meanonly
    local peerpop = r(sum)
    if `cellpop' > `peerpop' {
        display as error "WARNING: persona population exceeds peer population."
    }
}

quietly summarize _employed if __recent == 1 & __peer1 == 1 ///
    [aw=_weight], meanonly
local chk_emp = r(mean)
quietly summarize _unemployed if __recent == 1 & __peer1 == 1 ///
    [aw=_weight], meanonly
local chk_unemp = r(mean)
quietly summarize _laborforce if __recent == 1 & __peer1 == 1 ///
    [aw=_weight], meanonly
local chk_olf = 1 - r(mean)
display as text "Persona 1 peer labour-position sum=" ///
    as result %7.2f (100 * (`chk_emp' + `chk_unemp' + `chk_olf')) as text "%"

display as text "All cohort comparisons use age 25-34 and cohorts 1970s/1980s/1990s."
display as text "Missing KBLI/KBJI values are excluded from classified distributions."
display as text "No displayed result should be interpreted causally."

*=============================================================================*
* FINAL COMPACT PERSONA TABLE
*=============================================================================*

local p1_age_s : display %4.1f `p1_age_mean'
local p2_age_s : display %4.1f `p2_age_mean'
local p3_age_s : display %4.1f `p3_age_mean'
local p1_pop_s : display %15.0fc `p1_exactpop24'
local p2_pop_s : display %15.0fc `p2_exactpop24'
local p3_pop_s : display %15.0fc `p3_exactpop24'
local p1_peer_s : display %15.0fc `p1_peerpop24'
local p2_peer_s : display %15.0fc `p2_peerpop24'
local p3_peer_s : display %15.0fc `p3_peerpop24'
* Keep long category labels within their 29-character table columns.
local p1_sex_s = substr("`p1_sex'", 1, 26)
local p2_sex_s = substr("`p2_sex'", 1, 26)
local p1_edu_s = substr("`p1_edu'", 1, 26)
local p2_edu_s = substr("`p2_edu'", 1, 26)
local p1_occ_s = substr("`p1_occ'", 1, 26)
local p3_sector_s = substr("`p3_sector'", 1, 26)
local p3_occ_s = substr("`p3_occ'", 1, 26)
local p1_type_s = substr("`p1_empltype'", 1, 26)
local p2_type_s = substr("`p2_empltype'", 1, 26)
local p3_type_s = substr("`p3_empltype'", 1, 26)

display as text _newline(2) "================================================================================================================"
display as text "FINAL PERSONA SUMMARY (2019-24 traits; 2024 populations)"
display as text "================================================================================================================"
display as text _col(1) "Statistic" _col(39) "Adri" _col(68) "Urang" _col(97) "Tirta"
display as text "----------------------------------------------------------------------------------------------------------------"
display as text "ABOUT THEM"
display as text _col(1) "Mean age" _col(39) "`p1_age_s'" _col(68) "`p2_age_s'" _col(97) "`p3_age_s'"
display as text _col(1) "Sex" _col(39) "`p1_sex_s'" _col(68) "`p2_sex_s'" _col(97) "Female"
display as text _col(1) "Education" _col(39) "`p1_edu_s'" _col(68) "`p2_edu_s'" _col(97) "Tertiary"
display as text _col(1) "Married (%)" _col(39) %6.1f `p1_married' _col(68) %6.1f `p2_married' _col(97) %6.1f `p3_married'
display as text _col(1) "Area" _col(39) "Rural" _col(68) "Urban" _col(97) "Urban"
display as text _col(1) "Sector" _col(39) "KBLI 1" _col(68) "KBLI 6" _col(97) "`p3_sector_s'"
display as text _col(1) "Occupation" _col(39) "`p1_occ_s'" _col(68) "KBJI group 6" _col(97) "`p3_occ_s'"
display as text _col(1) "Employment type" _col(39) "`p1_type_s'" _col(68) "`p2_type_s'" _col(97) "`p3_type_s'"
display as text _col(1) "Modal employment-type share (%)" ///
    _col(39) %6.1f `p1_type_share' _col(68) %6.1f `p2_type_share' ///
    _col(97) %6.1f `p3_type_share'
display as text _col(1) "Formal code (%)" _col(39) %6.1f `p1_formal' _col(68) %6.1f `p2_formal' _col(97) %6.1f `p3_formal'
display as text _col(1) "Weekly hours (median)" _col(39) %7.1f `p1_hours' _col(68) %7.1f `p2_hours' _col(97) %7.1f `p3_hours'
display as text _col(1) "Hourly median, modal type" ///
    _col(39) %12.0fc `p1_type_earnings' _col(68) %12.0fc `p2_wage' ///
    _col(97) %12.0fc `p3_wage'
display as text _col(1) "Employee wage median (benchmark)" ///
    _col(39) %12.0fc `p1_wage' _col(68) %12.0fc `p2_wage' ///
    _col(97) %12.0fc `p3_wage'
display as text "Modal-type medians condition on positive observed earnings."
display as text "Adri's self-employment earnings and employee wages measure different work arrangements."
display as text "The formal code follows wage-employee status in these waves; it is not an independent job-quality measure."

display as text _newline "ABOUT THEIR PEERS"
display as text _col(1) "2024 broad peer population" _col(39) "`p1_peer_s'" _col(68) "`p2_peer_s'" _col(97) "`p3_peer_s'"
display as text _col(1) "2024 exact persona population" _col(39) "`p1_pop_s'" _col(68) "`p2_pop_s'" _col(97) "`p3_pop_s'"
display as text _col(1) "Persona share of all peers (%)" _col(39) %6.1f `p1_prev_all' _col(68) %6.1f `p2_prev_all' _col(97) %6.1f `p3_prev_all'
display as text _col(1) "Persona share of employed peers (%)" ///
    _col(39) %6.1f `p1_prev_emp' _col(68) %6.1f `p2_prev_emp' ///
    _col(97) %6.1f `p3_prev_emp'
display as text _col(1) "Employment rate (%)" _col(39) %6.1f `p1_peer_emp' _col(68) %6.1f `p2_peer_emp' _col(97) %6.1f `p3_peer_emp'
display as text _col(1) "Unemployment rate, LF (%)" _col(39) %6.1f `p1_peer_urate' _col(68) %6.1f `p2_peer_urate' _col(97) %6.1f `p3_peer_urate'
display as text _col(1) "Outside labour force (%)" _col(39) %6.1f `p1_peer_olf' _col(68) %6.1f `p2_peer_olf' _col(97) %6.1f `p3_peer_olf'

display as text _newline "ABOUT THEIR GENERATION (each persona has its own peer denominator)"
display as text _col(1) "Persona rate: 1970s cohort (%)" _col(39) %7.2f `p1_rate70' _col(68) %7.2f `p2_rate70' _col(97) %7.2f `p3_rate70'
display as text _col(1) "Persona rate: 1980s cohort (%)" _col(39) %7.2f `p1_rate80' _col(68) %7.2f `p2_rate80' _col(97) %7.2f `p3_rate80'
display as text _col(1) "Persona rate: 1990s cohort (%)" _col(39) %7.2f `p1_rate90' _col(68) %7.2f `p2_rate90' _col(97) %7.2f `p3_rate90'
display as text _col(1) "1990s vs 1970s change (pp)" _col(39) %7.2f `p1_change' _col(68) %7.2f `p2_change' _col(97) %7.2f `p3_change'

display as text _newline "ABOUT THEIR ECONOMY"
local p1_sector_change = `p1_ag24' - `p1_ag04'
local p2_sector_change = `p2_kbli624' - `p2_kbli604'
local p3_sector_change = `p3_tertiary24' - `p3_tertiary04'
local p1_occ_change = `p1_joint24' - `p1_joint04'
local p2_occ_change = `p2_group624' - `p2_group604'
local p3_occ_change = `p3_high24' - `p3_high04'
display as text "Context trends have different denominators; read each persona separately:"
display as text "  Adri: agriculture/national employment=" as result %7.2f `p1_sector_change' ///
    as text " pp; middle agriculture/national employment=" as result %7.2f `p1_occ_change' as text " pp"
display as text "  Urang: KBLI 6/national employment=" as result %7.2f `p2_sector_change' ///
    as text " pp; KBJI 6/KBLI 6 employment=" as result %7.2f `p2_occ_change' as text " pp"
display as text "  Tirta: tertiary/urban women=" as result %7.2f `p3_sector_change' ///
    as text " pp; high-skill employed/urban women=" as result %7.2f `p3_occ_change' as text " pp"
display as text "================================================================================================================"

display as text _newline "Persona profiles completed. No source data were changed."

log close
