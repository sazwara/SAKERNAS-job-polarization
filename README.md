# Job polarisation in Indonesia

A Stata project examining changes in employment, occupational composition, and earnings using SAKERNAS, Indonesia’s National Labour Force Survey.

Developed for my J-PAL internship capstone, the workflow reconstructs 25 August survey waves from 2000–2024. Much of the subsequent analysis focuses on 2004–2024, comparing patterns across birth cohorts, education, gender, and urban or rural location.

## What the project covers

- Mapping changing variable names across annual survey waves.
- Harmonising industry and occupation classifications.
- Constructing employment, household, education, and earnings variables.
- Appending annual files into a consistent dataset.
- Adjusting hourly earnings using sector-specific GDP deflators.
- Producing weighted individual and cohort statistics.
- Examining education–occupation gaps and wage premiums.
- Decomposing employment changes into within-group and between-group components.
- Creating survey-based persona profiles to communicate findings.

## Where to start

Three scripts provide an introduction to the analytical work:

- `00_clean and append.do`: annual variable mappings, classification harmonisation, household-variable construction, and appending survey waves.
- `02_Data exploration.do`: weighted employment and wage analysis, industry shift-share decomposition, and reconstruction checks.
- `04_SBTC.do`: reusable cohort-decomposition programs, common-support and thin-cell sensitivity specifications, and treatment of cohort entry and exit.

`00_Directory.do` is the master script and defines the execution order.

## Workflow

| Script | Purpose |
|---|---|
| `00_Directory.do` | Configure directories and run the workflow |
| `00_clean and append.do` | Clean, harmonise, and append survey waves |
| `00_wage_adjustment.do` | Construct real hourly earnings |
| `01_summary_stats.do` | Construct weighted cohort data |
| `02_Data exploration.do` | Analyse individual-level patterns |
| `03_cohort level exploration.do` | Compare education and employment across cohorts |
| `04_SBTC.do` | Analyse occupation–industry patterns and cohort decomposition |
| `05_Urban Women.do` | Examine urban employment and earnings by gender |
| `06_persona_profiles.do` | Produce weighted persona profiles and diagnostics |

The optional descriptive-table and variable-mean sections in `01_summary_stats.do` are currently commented out; cohort construction is active.

## Data and setup

The repository contains code. Raw survey files, reconstructed datasets, and generated outputs are not included.

To run the workflow:

1. Use Stata 16 or a compatible later version.
2. Create a project folder with `code/` and `SAKERNAS/` subfolders.
3. Place the do-files in `code/` and annual survey files in `SAKERNAS/`.
4. Update the username condition and project path in `00_Directory.do`.
5. Confirm access to the deflator source used by `00_wage_adjustment.do`.
6. Run the master script.

Annual filenames must match those expected by the cleaning script, such as `2000 SAKERNAS.dta`.

The master creates output and temporary directories. Outputs include reconstructed individual and cohort datasets, decomposition results, PNG figures, and a persona log.

## Interpretation

SAKERNAS is a repeated cross-sectional survey: cohort comparisons do not track the same individuals over time.

Household reconstruction uses wave-specific identifiers or ordering assumptions. Household variables remain missing where the code cannot construct an identifier.

Occupational categories are harmonised analytical groupings. Decompositions describe changes in composition, while personas summarise weighted survey cells rather than individual life histories. These analyses do not establish causal effects of technological change.
