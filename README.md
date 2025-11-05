## Boston Housing Analysis (R)

 Advanced, end-to-end analysis of the Boston housing dataset including:
 - Data cleaning and EDA (correlation heatmap, boxplots)
 - Cross-validated models: Linear Regression, Elastic Net (glmnet), Random Forest, GBM
 - Model comparison on a held-out test set (RMSE, R²)
 - Diagnostics: VIF, Breusch–Pagan, Shapiro–Wilk, Cook’s distance
 - ANOVA (distance groups) and ANCOVA (ptratio + rm)

**Report (HTML)**: `results/report.html`

### Files
- `boston_housing_analysis.R`: Main analysis script
 - `Boston.csv`: Input data (expects standard Boston Housing columns)
 - Outputs (generated when running the script):
   - `results/model_comparison_results.csv`
   - `results/sessionInfo.txt`
   - Figures saved in `figures/` (heatmap, boxplots, feature importance)

 ### How to run
 1) Ensure R (>= 4.0) is installed
2) From this folder, run in R:
    ```r
   source("boston_housing_analysis.R")
    ```
    or from a shell:
    ```bash
    Rscript boston_housing_analysis.R
    ```

 The script will install missing packages if needed (tidyverse, caret, glmnet, car, lmtest, sandwich). Random Forest (`randomForest`) and GBM (`gbm`) are used if installed.

### Report
- Knit the R Markdown to produce an HTML report (already rendered at `results/report.html`):
   ```r
   rmarkdown::render("report.Rmd")
   ```
  Output is saved to `results/report.html`.

 ### Notes
 - Reproducibility: the script sets a seed and writes `sessionInfo.txt`.
 - Data: `Boston.csv` should be in this folder. If your file has an index column, it will be dropped automatically.
 - Results: `model_comparison_results.csv` summarizes test performance across models.
 - Licensing: MIT (see `LICENSE`).

