# Data cleaning summary - Project 1

Input file: wage.xlsx
Raw shape: 3010 rows x 34 columns
EDA output: wage_eda.csv
Model output: wage_model.csv

## Cleaning decisions
- Dropped id from prepared datasets because it is only an identifier.
- Kept wage only in the EDA dataset; it must not be used as a predictor for lwage.
- Kept missing values in the EDA dataset so descriptive statistics can report valid n by variable.
- Filled IQ, KWW, fatheduc, and motheduc with medians in the model dataset.
- Filled married and libcrd14 with modes in the model dataset.
- Added missing-value indicators for imputed variables.
- One-hot encoded married and omitted the first observed category as baseline.
- Dropped reg661 from the model dataset as the region baseline to reduce dummy-variable collinearity.
- Did not delete IQR outliers; they are reported for review before statistical analysis.

## Missing values
- IQ: 949 missing (31.53%); treatment: median for model dataset; impute value: 103
- fatheduc: 690 missing (22.92%); treatment: median for model dataset; impute value: 10
- motheduc: 353 missing (11.73%); treatment: median for model dataset; impute value: 12
- KWW: 47 missing (1.56%); treatment: median for model dataset; impute value: 34
- libcrd14: 13 missing (0.43%); treatment: mode for model dataset; impute value: 1
- married: 7 missing (0.23%); treatment: mode for model dataset; impute value: 1

## Consistency checks
- max abs(lwage - log(wage)): 7.1346075269929088E-07
- mean abs(lwage - log(wage)): 2.9654561461011716E-07
- expersq != exper^2 rows: 0

## IQR outlier review
- wage: 83 outliers (2.76%)
- exper: 50 outliers (1.66%)
- lwage: 38 outliers (1.26%)
- IQ: 21 outliers (1.02%)
- educ: 19 outliers (0.63%)
- KWW: 9 outliers (0.3%)

## Output files
- data/processed/wage_eda.csv: selected variables for descriptive statistics and visualization.
- data/processed/wage_model.csv: numeric modeling table with imputation, missing flags, one-hot married dummies, and no wage leakage.
- reports/missing_values.csv: missing-value counts and treatment.
- reports/outliers_iqr.csv: IQR outlier bounds and counts.
- reports/variable_roles.csv: variable roles and cleaning actions.
