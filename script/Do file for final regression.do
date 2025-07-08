********************************************************************************
************************* MASTER DO ********************************************
********************************************************************************

* set up the directory

cd "C:\Users\Data and code"
global dirMain= "C:\Users\Data and code\"
global dirCov="C:\Users\Covariate\"
global dirHealth="C:\Users\Health data\"



*===================================
**# 1. Cleanning and merging data
*===================================


*** *** ***
**# *** 1.1. Merge Covariates
*** *** ***


import delimited using "${dirCov}\population-density-vs-prosperity.csv", clear
save covariatedata.dta, replace

* Merge population-density.csv
import delimited using "${dirCov}\population-density.csv", clear
tempfile pop_density
save `pop_density'
use covariatedata.dta, clear
merge 1:1 iso3 year using `pop_density', nogen
save covariatedata.dta, replace

* Merge political-regime.csv
import delimited using "${dirCov}\political-regime.csv", clear
tempfile pol_regime
save `pol_regime'
use covariatedata.dta, clear
merge 1:1 iso3 year using `pol_regime', nogen
save covariatedata.dta, replace

* Merge economic-inequality-gini-index.csv
import delimited using "${dirCov}\economic-inequality-gini-index.csv", clear
tempfile gini_idx
save `gini_idx'
use covariatedata.dta, clear
merge 1:1 iso3 year using `gini_idx', nogen
save covariatedata.dta, replace



* Merge Economic_Indicators1.csv
import delimited using "${dirCov}\Economic_Indicators1.csv", clear
tempfile econ1
save `econ1'
use covariatedata.dta, clear
merge 1:1 iso3 year using `econ1', nogen
save covariatedata.dta, replace

* Merge Economic_Indicators2.csv
import delimited using "${dirCov}\Economic_Indicators2.csv", clear
tempfile econ2
save `econ2'
use covariatedata.dta, clear
merge 1:1 iso3 year using `econ2', nogen
save covariatedata.dta, replace

* Merge Economic_Indicators3.csv
import delimited using "${dirCov}\Economic_Indicators3.csv", clear
tempfile econ3
save `econ3'
use covariatedata.dta, clear
merge 1:1 iso3 year using `econ3', nogen
save covariatedata.dta, replace

* Merge Economic_Indicators4.csv
import delimited using "${dirCov}\Economic_Indicators4.csv", clear
tempfile econ4
save `econ4'
use covariatedata.dta, clear
merge 1:1 iso3 year using `econ4', nogen
save covariatedata.dta, replace



* Merge Poverty.csv
import delimited using "${dirCov}\Poverty.csv", clear
tempfile poverty
save `poverty'
use covariatedata.dta, clear
merge 1:1 iso3 year using `poverty', nogen
save covariatedata.dta, replace

* Merge Population.csv
import delimited using "${dirCov}\Population.csv", clear
tempfile population
save `population'
use covariatedata.dta, clear
merge 1:1 iso3 year using `population', nogen
save covariatedata.dta, replace

* Merge Health&nutrition.csv
import delimited using "${dirCov}\Health&nutrition.csv", clear
tempfile healthnut
save `healthnut'
use covariatedata.dta, clear
merge 1:1 iso3 year using `healthnut', nogen
save covariatedata.dta, replace

* Merge Gender.csv
import delimited using "${dirCov}\Gender.csv", clear
tempfile gender
save `gender'
use covariatedata.dta, clear
merge 1:1 iso3 year using `gender', nogen
save covariatedata.dta, replace

* Merge UCDPGED.csv (conflict/violence data)
import delimited using "${dirCov}\UCDPGED.csv", clear
tempfile ucdp
save `ucdp'
use covariatedata.dta, clear
merge 1:1 iso3 year using `ucdp', nogen
save covariatedata.dta, replace




*** *** ***
**# *** 1.2. Merge with heath indicator
*** *** ***

*1. life expectancy
import delimited using "${dirHealth}\life-expectancy.csv", clear
rename code iso3
drop if missing(iso3)
tempfile lifeexpect
save `lifeexpect'
use covariatedata.dta, clear
merge 1:1 iso3 year using `lifeexpect'
drop if _merge ==2
drop _merge
save covariatedata.dta, replace


*2. EMDAT Epidemic of Disaster
import excel "${dirHealth}\public_emdat epidemic.xlsx", sheet("EM-DAT Data") firstrow clear
keep ISO Country StartYear DisasterSubtype Subregion Region StartYear  ///
     TotalDeaths NoInjured NoAffected NoHomeless TotalAffected CPI
rename ISO iso3
drop if missing(iso3)	
save epidemic_climate.dta, replace 

use epidemic_climate.dta, clear
/// duplicates report iso3 StartYear DisasterSubtype
gen subtype = subinstr(DisasterSubtype, " ", "", .)
tab subtype
replace subtype = "Infectious" if subtype == "Infectiousdisease(General)" 
replace subtype = subinstr(subtype, "disease", "", .)
collapse (sum) TotalDeaths NoInjured NoAffected NoHomeless TotalAffected CPI, ///
    by(iso3 StartYear subtype)

reshape wide TotalDeaths NoInjured NoAffected NoHomeless TotalAffected CPI, ///
    i(iso3 StartYear) j(subtype) string
rename 	StartYear year
save epidemic_climate_final, replace	


/// merge with covariatedata
use  "${dirCov}covariatedata.dta",  clear
merge 1:1 iso3 year using "${dirHealth}epidemic_climate_final"
drop if _merge ==2
drop _merge
drop if missing(iso3)
drop if missing(year)
duplicates report iso3 year
drop if year <= 1960
drop CPIBacterial CPIInfectious CPIParasitic CPIViral  /// availale in the covariates

foreach v of varlist TotalDeathsBacterial NoInjuredBacterial NoAffectedBacterial NoHomelessBacterial TotalAffectedBacterial TotalDeathsInfectious NoInjuredInfectious NoAffectedInfectious NoHomelessInfectious TotalAffectedInfectious TotalDeathsParasitic NoInjuredParasitic NoAffectedParasitic NoHomelessParasitic TotalAffectedParasitic TotalDeathsViral NoInjuredViral NoAffectedViral NoHomelessViral TotalAffectedViral {
	replace `v' = 0 if missing(`v')
	g log_`v' = log(1 + `v')
}

save final_data.dta, replace




*** *** ***
**# *** 1.3. Merge with climate policy 
*** *** ***



**# *** >>> a. Action with Semi-supervise ML

*** Cleaning data:

import delimited using "${dirMain}\aggregated_policyaction_panel_iso3.csv", clear
/* variable meaning
| Variable           | Type        | Description                                                                                                      |
| ------------------ | ----------- | ---------------------------------------------------------------------------------------------------------------- |
| `num_docs`         | Integer     | Total number of policy documents for that country-year.                                                          |
| `avg_xgb_prob`     | Float (0–1) | **Average predicted probability** from Imbalanced XGBoost for policy action (across all documents in the group). |
| `share_xgb_pred_1` | Float (0–1) | **Share (proportion) of documents** with `xgb_pred == 1` (i.e., predicted as taking policy action).              |
| `sum_xgb_pred_1`   | Integer     | Total number of documents with `xgb_pred == 1` in that country-year group.                                       |


*/

***# Label key variables in the aggregated panel ===
label variable num_docs "Total number of policy documents for that country-year"
label variable avg_xgb_prob "Average predicted probability (XGBoost) of policy action, across documents"
label variable share_xgb_pred_1 "Share of documents predicted as policy action (xgb_pred == 1)"
label variable sum_xgb_pred_1 "Number of documents predicted as policy action (xgb_pred == 1) per country-year"

foreach v of varlist avg_xgb_prob share_xgb_pred_1 sum_xgb_pred_1 {
	rename `v' action_`v'
	
}
save climate_action.dta, replace

*** merging full data:
use final_data.dta, clear
merge 1:1 iso3 year using climate_action
drop if _merge ==2
drop _merge
foreach v of varlist num_docs action_avg_xgb_prob action_share_xgb_pred_1 action_sum_xgb_pred_1 {
	replace `v' = 0 if missing(`v')
}

save final_data_andclimate, replace




**# *** >>> b. Ambition with keyword scoring:

*** Cleaning data:
*** >>> Ambition basic:
import delimited using "${dirMain}\ambition_keywordscore.csv", clear
/* Variable meaning
| **Variable**         | **Type**        | **Description / Meaning**                                                                 |
| -------------------- | --------------- | ----------------------------------------------------------------------------------------- |
| `num_docs`           | Integer         | Number of policy documents associated with that country-year.                             |
| `mean_raw`           | Float (≥ 0)     | Average number of ambition-related **keywords** found per document (raw count).           |
| `mean_weight`        | Float (0.5–1.5) | Average **ambition weight** per document (e.g., 0.5 = low priority, 1.5 = high priority). |
| `share_high_weights` | Float (0–1)     | Share of documents with **ambition weight ≥ 1.0** — signals higher ambition focus.        |
| `mean_adjusted`      | Float (≥ 0)     | Mean ambition score after adjusting for document weight: `mean_raw * ambition_weight`.    |
| `total_adjusted`     | Float (≥ 0)     | Total ambition score across all documents in that country-year. Useful for scaling.       |


*/ 

label variable num_docs           "Number of policy documents associated with that country-year."
label variable mean_raw           "Average number of ambition-related keywords found per document (raw count)."
label variable mean_weight        "Average ambition weight per document (e.g., 0.5 = low priority, 1.5 = high priority)."
label variable share_high_weight_docs "Share of documents with ambition weight ≥ 1.0 — signals higher ambition focus."
label variable mean_adjusted      "Mean ambition score after adjusting for document weight: mean_raw * ambition_weight."
label variable total_adjusted     "Total ambition score across all documents in that country-year. Useful for scaling."
rename share_high_weight_docs share_high_weight 
 
foreach v of varlist  num_docs mean_raw mean_weight share_high_weight mean_adjusted total_adjusted {
	rename `v'   ambitionkey_`v'
}
save climate_ambition.dta, replace 


 *** >>> Ambition with keyword scoring: (CPR ICLR 2024 target enhancement)
import delimited using "${dirMain}\ambition_keywordscore_enhance.csv", clear
label variable num_docs           "Number of policy documents associated with that country-year."
label variable mean_raw           "Average number of ambition-related keywords found per document (raw count)."
label variable mean_weight        "Average ambition weight per document (e.g., 0.5 = low priority, 1.5 = high priority)."
label variable share_high_weight_docs "Share of documents with ambition weight ≥ 1.0 — signals higher ambition focus."
label variable mean_adjusted      "Mean ambition score after adjusting for document weight: mean_raw * ambition_weight."
label variable total_adjusted     "Total ambition score across all documents in that country-year. Useful for scaling."
rename share_high_weight_docs share_high_weight 
 
foreach v of varlist  num_docs mean_raw mean_weight share_high_weight mean_adjusted total_adjusted {
	rename `v'   ambitionkey2_`v'
}
save climate_ambition_2.dta, replace 



*** merging full data:
use final_data_andclimate.dta, clear
merge 1:1 iso3 year using climate_ambition
drop if _merge ==2
drop _merge
merge 1:1 iso3 year using climate_ambition_2
drop if _merge ==2
drop _merge
foreach v of varlist ambitionkey_num_docs ambitionkey_mean_raw ambitionkey_mean_weight ambitionkey_share_high_weight ambitionkey_mean_adjusted ambitionkey_total_adjusted ambitionkey2_num_docs ambitionkey2_mean_raw_v4 ambitionkey2_mean_weight ambitionkey2_share_high_weight ambitionkey2_mean_adjusted_v4 ambitionkey2_total_adjusted_v4 mean_normalized_v4 {
	replace `v' = 0 if missing(`v')
}

save final_data_andclimate2, replace



**# *** >>> c. Ambition with Topic modeling (Bertopic):

import delimited using "${dirMain}\bert_topic_panel.csv", clear
/*
| **Variable**         | **Type**        | **Description / Meaning**                                                                                        |
| -------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------- |
| `num_docs`           | Integer (≥ 1)   | Number of climate-related policy documents from that country in that year.                                       |
| `mean_topic_score`   | Float (0–1)     | Average **ambition score** across documents, computed as the sum of probabilities for ambition-related topics.   |
| `share_high_topic`   | Float (0–1)     | Share of documents labeled as **High** ambition (i.e., `ambition_score_topic ≥ 0.6`).                            |
| `share_medium_topic` | Float (0–1)     | Share of documents labeled as **Medium** ambition (`0.3 ≤ ambition_score_topic < 0.6`).                          |
| `share_low_topic`    | Float (0–1)     | Share of documents labeled as **Low** ambition (`ambition_score_topic < 0.3`).                                   |
| `avg_topic_prob`     | Float (0–1)     | Average **maximum topic probability** per document, reflecting BERTopic confidence.                              |


*/

label variable num_docs            "Number of climate-related policy documents in that country-year"
label variable mean_topic_score    "Average ambition score (sum of probabilities for ambition-related topics)"
label variable share_high_topic    "Share of documents with High ambition score (≥ 0.6)"
label variable share_medium_topic  "Share of documents with Medium ambition score (0.3–0.6)"
label variable share_low_topic     "Share of documents with Low ambition score (< 0.3)"
label variable avg_topic_prob      "Average top topic probability per document (BERTopic confidence)"



foreach v of varlist  num_docs mean_topic_score share_high_topic share_medium_topic share_low_topic avg_topic_prob {
	rename `v'   ambitionkey3_`v'
}

save climate_ambition_3.dta, replace 



*** merging full data:
use final_data_andclimate2.dta, clear
merge 1:1 iso3 year using climate_ambition_3
drop if _merge ==2
drop _merge
foreach v of varlist ambitionkey3_num_docs ambitionkey3_mean_topic_score ambitionkey3_share_high_topic ambitionkey3_share_medium_topic ambitionkey3_share_low_topic ambitionkey3_avg_topic_prob {
	replace `v' = 0 if missing(`v')
}

save final_data_andclimate3, replace




*===================================
**# 2. Regression and data analysis
*===================================

use  final_data_andclimate3, replace
keep if year >= 1990
encode iso3, g(iso)
xtset iso year
rename periodlifeexpectancyatbirthsexto life_expectancy


*** *** ***
**# *** 1.0. Visualization
*** *** ***


preserve
* Average ambition score by year
collapse (mean) ambitionkey_mean_adjusted, by(year)
twoway line ambitionkey_mean_adjusted year, ///
      title("Average Climate Policy Ambition Over Time") ///
    subtitle("Based on Keyword from Net Zero Target") ///
    xtitle("Year") ///
    lwidth(medium) lcolor(navy)

	
	
preserve
* Average ambition score by year
collapse (mean) ambitionkey2_mean_adjusted_v4, by(year)	
twoway line ambitionkey2_mean_adjusted_v4 year, ///
    title("Average Climate Policy Ambition Over Time") ///
    subtitle("Based on Keyword Scoring Enhanced with CPR Targets") ///
    ytitle("Mean Adjusted Ambition Score") ///
    xtitle("Year") ///
    lwidth(medium) lcolor(red)
	
	

preserve
* Average ambition score by year
collapse (mean) ambitionkey3_mean_topic_score, by(year)	
twoway line ambitionkey3_mean_topic_score year, ///
    title("Average Climate Policy Ambition Over Time") ///
    subtitle("Ambition from BERTopic (Unsupervised)") ///
    ytitle("Mean Adjusted Ambition Score") ///
    xtitle("Year") ///
    lwidth(medium) lcolor(green)
	
	

preserve
* Average Action score by year
collapse (mean) action_avg_xgb_prob, by(year)	
twoway line action_avg_xgb_prob year, ///
    title("Average Climate Policy Action Over Time") ///
    subtitle("Measurement from semi-supervising ML") ///
    ytitle("Mean Adjusted Ambition Score") ///
    xtitle("Year") ///
    lwidth(medium) lcolor(orange)
		

	

*** *** ***
**# *** 1.1. standard fixed effect
*** *** ***
 
**# *** >>> a. action:
 * action: action_avg_xgb_prob
 xtreg life_expectancy  action_avg_xgb_prob ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant  (+)
 
 xtreg log_TotalDeathsInfectious  action_avg_xgb_prob ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)
 
 xtreg log_TotalDeathsViral  action_avg_xgb_prob ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl    ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   


* ---

 
 * action: action_share_xgb_pred_1
 xtreg life_expectancy  action_share_xgb_pred_1 ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant  (+)
 
 xtreg log_TotalDeathsInfectious  action_share_xgb_pred_1 ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)
 
 xtreg log_TotalDeathsViral  action_share_xgb_pred_1 ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl    ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   
 

* ---


**# *** >>> b. Ambition with keyword scoring 1:
 
 * ambition,ambitionkey_num_docs:
 xtreg life_expectancy  ambitionkey_num_docs ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
 
 xtreg log_TotalDeathsInfectious  ambitionkey_num_docs ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)
 
 xtreg log_TotalDeathsViral  ambitionkey_num_docs ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl    ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   





 
 * ambition, ambitionkey_mean_weight:
 xtreg life_expectancy  ambitionkey_mean_weight ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)

 
 xtreg log_TotalDeathsInfectious  ambitionkey_mean_weight ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)
 
 xtreg log_TotalDeathsViral  ambitionkey_mean_weight ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl    ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   
 

 
 

 
 
* -----------------------

 * ambition, CPR
 xtreg life_expectancy  ambitionkey2_num_docs ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)

	  
 xtreg log_TotalDeathsInfectious  ambitionkey2_num_docs ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   
 
 xtreg log_TotalDeathsViral  ambitionkey2_num_docs ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl    ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   
 

 
* -----------------------
 * ambition, ambitionkey_total_adjusted:
 xtreg life_expectancy  ambitionkey2_mean_raw_v4 ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (+)   
	  
 xtreg log_TotalDeathsInfectious  ambitionkey2_mean_raw_v4 ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl              ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
/// significant (-)   
 
 xtreg log_TotalDeathsViral  ambitionkey2_mean_raw_v4 ///
      pop_65plus_pct agedep_tot_pct   /// Age Structure and Demography
	  gdp_pc_ppp_c21intl    ///   Income and Fiscal Capacity
	  birth_crude    pop_gro_pct      ///  Basic Population and Fertility
	  i.year, fe vce(robust)
 

 
 
 
 

*** *** ***
**# *** 1.2. Lasso regression
*** *** ***

* 1. Set seed for reproducibility
set seed 12345

* 2. Generate random number and sort
gen u = runiform()

* 3. Generate split indicator: 1 = train (70%), 0 = test (30%)
gen train = u <= 0.7

* 4. Confirm split balance
tab train


*  Define variable types for lasso using vl
vl set
/*

-------------------------------------------------------------------------------
                  |                      Macro's contents
                  |------------------------------------------------------------
Macro             |  # Vars   Description
------------------+------------------------------------------------------------
System            |
  $vlcategorical  |      17   categorical variables
  $vlcontinuous   |     377   continuous variables
  $vluncertain    |      25   perhaps continuous, perhaps categorical variables
  $vlother        |      11   all missing or constant variables
-------------------------------------------------------------------------------

*/
vl list
vl list vlcontinuous
vl list vlcategorical

sum $vlcontinuous
mdesc $vlcontinuous


* Split training data into two folds for selection and inference (ONLY WITHIN TRAINING SET)
splitsample if train == 1, generate(sample) nsplit(2) rseed(1234)
vl drop (life_expectancy)


lasso linear life_expectancy  $vlcontinuous  $vlcategorical  if sample == 1, rseed(1234)
di "`e(post_sel_vars)'"


*** Useful link 

https://lancetcountdown.org/explore-our-data/