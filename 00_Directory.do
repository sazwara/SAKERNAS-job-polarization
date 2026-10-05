*=============================================================================*
* MASTER DO-FILE: Sakernas Capstone
*=============================================================================*

version 16
clear all
set more off

graph set window fontface "Garamond"

* User-specific project directory

if "`c(username)'" == "sazwara" {
    global project ///
        "/Users/sazwara/Library/CloudStorage/GoogleDrive-tasazwara@gmail.com/My Drive/Job polarization"
}
else {
    display as error "Project directory is not configured for this user."
    exit 198
}

* Shared directories
global code   "$project/code"
global output "$project/output"
global temp   "$project/temp"
global viz    "$output/Visualizations"

global wage_adjustment        "$viz/00_wage_adjustment"
global summary_stats          "$viz/01_summary_stats"
global individual_exploration "$viz/02_individual_exploration"
global cohort_exploration     "$viz/03_cohort_exploration"
global sbtc                   "$viz/04_sbtc"
global urban_women            "$viz/05_urban_women"

capture mkdir "$output"
capture mkdir "$code"
capture mkdir "$temp"
capture mkdir "$viz"
capture mkdir "$wage_adjustment"
capture mkdir "$summary_stats"
capture mkdir "$individual_exploration"
capture mkdir "$cohort_exploration"
capture mkdir "$sbtc"
capture mkdir "$urban_women"

* J-PAL colour palette
global jpal_orange "227 89 37"
global jpal_teal   "47 170 159"
global jpal_green  "145 183 127"
global jpal_yellow "244 195 0"
global jpal_navy   "45 97 110"
global jpal_gray   "160 160 160"

*Run analysis
do "$code/00_clean and append.do"
do "$code/00_wage_adjustment.do"
do "$code/01_summary_stats.do"
do "$code/02_Data exploration.do"
do "$code/03_cohort level exploration.do"
do "$code/04_SBTC.do"
do "$code/05_Urban Women.do" 
do "$code/06_persona_profiles.do"

display as result "CAPSTONE analysis completed successfully."
