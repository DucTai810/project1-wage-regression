# project1-wage-regression
OLS and Machine Learning analysis of wage determinants using Card (1995) dataset

## Data cleaning

Run the cleaning pipeline from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clean_wage_data.ps1
```

Outputs:

- `data/processed/wage_eda.csv`: selected variables for descriptive statistics and visualization.
- `data/processed/wage_model.csv`: modeling table with imputation, missing flags, one-hot `married`, and no `wage` leakage.
- `reports/data_cleaning_summary.md`: generated cleaning summary.
- `reports/data_cleaning_notes_vi.md`: Vietnamese notes for the report.
- `reports/missing_values.csv`, `reports/outliers_iqr.csv`, `reports/variable_roles.csv`: supporting tables.
