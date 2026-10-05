version 16
clear all
set more off

*=============================================================================*
* SAKERNAS CAPSTONE LABOR_POLARIZATION
* (1) Summary Statistics
* Programmer: Tahtia Sazwara
*=============================================================================*

local dataset "$output/sakernas_recons_2000_2024.dta"

use "`dataset'", clear

/*
*=============================================================================*
* Individual-level summary statistics by year
*=============================================================================*
preserve

set seed 1906317354
sample 1

local varvar ///
    _weight _psu _strata _kode_prov _kode_kab _household_id ///
    _is_rural _is_female _roster _fam_stat _is_married ///
    _hh_n_children _hh_youngest_child_age _hh_oldest_child_age ///
    _age _birthyear _yobcohort _educohort ///
    _laborforce _employed _unemployed _empltype _formal _informal ///
    _hoursworked _hourly_earnings ///
    _kbli_default _kbli_harmonized ///
    _kbji_default _kbji_harmonized

capture drop __year_desc
gen byte __year_desc = 2025 - _year

capture label drop __year_desc_lbl
forvalues y = 2024(-1)2000 {
    local k = 2025 - `y'
    label define __year_desc_lbl `k' "`y'", add
}
label values __year_desc __year_desc_lbl

estpost tabstat `varvar' [aw=_weight], ///
    by(__year_desc) ///
    statistics(count mean sd min max) ///
    columns(statistics) nototal

esttab using "$output/summary_by_year.csv", replace plain ///
    cells("count(fmt(0)) mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") ///
    unstack noobs nonumber 

drop __year_desc

restore

*=============================================================================*
* Variable means by years
*=============================================================================*

local graphvars ///
    _is_rural _is_female _roster _is_married ///
    _hh_n_children _age _birthyear _yobcohort _educohort ///
    _laborforce _employed _unemployed _formal _informal ///
    _hoursworked _hourly_earnings 

preserve
keep if inrange(_age, 15, 65)

collapse (mean) `graphvars' [pw=_weight], by(_year)

foreach v of local graphvars {

    line `v' _year, sort ///
        lcolor("$jpal_navy") ///
        title("Mean of `v' by year") ///
        xtitle("Year") ytitle("Mean") ///
        xlabel(2000(2)2024, angle(45))

    graph export "$summary_stats/mean_`v'.png", ///
        replace width(1800)
}

restore
*/
*=============================================================================*
*  cohort creation
*=============================================================================*
keep if inrange(_age, 15, 64)

quietly tab _fam_stat, gen(_famstatdummy)
qui tab _empltype, gen (_jobstat)
qui tab _kbli_harmonized, gen(_sector)
qui tab _kbji_group, gen(_skill)

* Including rural/urban: 80 possible cohorts
egen long _cohort = group( ///
    _yobcohort _is_female _educohort _is_rural), label


bysort _year _cohort: gen long _cell_n = _N
bysort _year _cohort: egen double _cell_weight = total(_weight)


drop if _cell_n < 100

preserve

collapse (mean) ///
    _age ///
    _employed ///
    _unemployed ///
    _laborforce ///
    _is_married ///
    _formal ///
	_informal ///
    _hoursworked ///
    _hourly_earnings ///
	_ln_real_hourly_wage ///
	_occ_* _skill* ///
    _famstatdummy* _jobstat* _sector* ///
    [pw = _weight], ///
    by(_year _cohort _yobcohort _is_female _educohort _is_rural ///
   _cell_n _cell_weight)

save "$output/sakernas_cohort_panel.dta", replace

restore
*------
* done
*------
