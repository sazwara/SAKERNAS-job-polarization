version 16
clear all
set more off

*=============================================================================*
* Sector-specific real hourly earnings using GDP deflators
*=============================================================================*

local dataset "$output/sakernas_recons_2000_2024.dta"

* Google Sheet: PDB Sektoral, gid 780407024
local gdp_url ///
"https://docs.google.com/spreadsheets/d/1X-4CRDfsZZh1DF43wkv2QIL0hy9F3uW7Co_fICoyh6M/export?format=csv&gid=780407024"

local sector1 "Agriculture, forestry and fishing"
local sector2 "Mining and quarrying"
local sector3 "Manufacturing"
local sector4 "Electricity, gas and water"
local sector5 "Construction"
local sector6 "Trade, restaurants and accommodation"
local sector7 "Transport, storage and communication"
local sector8 "Finance, real estate and business services"
local sector9 "Community, social and personal services"

*-------------------------------------------------------------*
* Import GDP deflators
*-------------------------------------------------------------*

import delimited using "`gdp_url'", ///
    varnames(4) case(lower) clear

rename year             _year
rename kbliharmonized   _kbli_harmonized
rename gdpdeflator      _gdp_deflator

keep _year _kbli_harmonized _gdp_deflator
drop if missing(_year, _kbli_harmonized)

isid _year _kbli_harmonized

label variable _gdp_deflator ///
    "Sector GDP deflator ratio, 2010=1"

tempfile sector_deflator
save `sector_deflator'

*-------------------------------------------------------------*
* Merge deflators into individual SAKERNAS data
*-------------------------------------------------------------*

use "`dataset'", clear

capture drop _gdp_deflator
capture drop _real_hourly_earnings
capture drop _ln_real_hourly_wage

merge m:1 _year _kbli_harmonized using `sector_deflator', ///
    keep(master match) nogen

* Confirm valid sector-year observations were matched
assert !missing(_gdp_deflator) if ///
    inrange(_year, 2001, 2024) & ///
    inrange(_kbli_harmonized, 1, 9)

* Nominal hourly earnings converted to constant 2010 rupiah
gen double _real_hourly_earnings = ///
    _hourly_earnings / _gdp_deflator ///
    if !missing(_hourly_earnings) & _gdp_deflator > 0

label variable _real_hourly_earnings ///
    "Real hourly earnings, sector GDP-deflated (2010 IDR)"

* Log real earnings: only defined for positive earnings
gen double _ln_real_hourly_wage = ///
    ln(_real_hourly_earnings) ///
    if _real_hourly_earnings > 0

label variable _ln_real_hourly_wage ///
    "Log real hourly earnings, sector GDP-deflated"

* Save separately so the original dataset remains untouched
save "`dataset'", replace

*=============================================================================*
* Weighted mean real hourly earnings by economic sector and year
*=============================================================================*

preserve

keep if inrange(_year, 2001, 2024)
keep if inrange(_age, 15, 64)
keep if _employed == 1
keep if inrange(_kbli_harmonized, 1, 9)
keep if _real_hourly_earnings > 0
keep if _weight > 0 & !missing(_weight)

collapse ///
    (mean) mean_real_wage = _real_hourly_earnings ///
    [pw=_weight], ///
    by(_year _kbli_harmonized)

label define sector_lbl ///
    1 "Agriculture, forestry and fishing" ///
    2 "Mining and quarrying" ///
    3 "Manufacturing" ///
    4 "Electricity, gas and water" ///
    5 "Construction" ///
    6 "Trade, restaurants and accommodation" ///
    7 "Transport, storage and communication" ///
    8 "Finance, real estate and business services" ///
    9 "Community, social and personal services", replace

label values _kbli_harmonized sector_lbl

forvalues s = 1/9 {

    twoway ///
        (connected mean_real_wage _year ///
            if _kbli_harmonized == `s', ///
            sort ///
            lcolor("$jpal_navy") ///
            mcolor("$jpal_navy") ///
            msymbol(O) ///
            msize(small)), ///
        title("Real hourly earnings: `sector`s''", size(medsmall)) ///
        subtitle("Employed persons ages 15–64 with positive earnings", ///
            size(small)) ///
        xtitle("Year") ///
        ytitle("Mean real hourly earnings (2010 IDR)") ///
        xlabel(2001(3)2024, angle(45) labsize(small)) ///
        ylabel(, angle(horizontal) format(%12.0fc) labsize(small)) ///
        legend(off) ///
        graphregion(color(white)) ///
        name(realwage_sector`s', replace)

    graph export ///
        "$wage_adjustment/real_hourly_wage_sector`s'.png", ///
        replace width(2400)
}

restore

*=============================================================================*
* GDP deflator by harmonized KBLI sector
*=============================================================================*

preserve

import delimited using "`gdp_url'", ///
    varnames(4) case(lower) clear

rename year             _year
rename kbliharmonized   _kbli_harmonized
rename gdpdeflator      _gdp_deflator

keep if inrange(_year, 2001, 2024)
keep if inrange(_kbli_harmonized, 1, 9)
drop if missing(_gdp_deflator)

forvalues s = 1/9 {

    twoway ///
        (connected _gdp_deflator _year ///
            if _kbli_harmonized == `s', ///
            sort ///
            lcolor("$jpal_navy") ///
            mcolor("$jpal_navy") ///
            msymbol(O) ///
            msize(small)), ///
        yline(1, lcolor("$jpal_gray") lpattern(dash)) ///
        title("GDP deflator: `sector`s''", size(medsmall)) ///
        subtitle("Sector output prices; 2010 = 1", size(small)) ///
        xtitle("Year") ///
        ytitle("GDP deflator") ///
        xlabel(2001(3)2024, angle(45) labsize(small)) ///
        ylabel(, angle(horizontal) format(%4.2f)) ///
        legend(off) ///
        graphregion(color(white)) ///
        name(gdp_deflator_sector`s', replace)

    graph export ///
        "$wage_adjustment/gdp_deflator_sector`s'.png", ///
        replace width(2400)
}

restore
