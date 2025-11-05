 # Advanced Boston Housing Analysis: EDA, CV models, diagnostics, and reporting

 # Reproducibility
 set.seed(123)

 # Libraries (conditionally load where possible)
 suppressPackageStartupMessages({
   library(tidyverse)
   library(caret)
   library(glmnet)
   library(car)
   library(lmtest)
   library(sandwich)
 })

 # Optional models if available
 rf_available <- requireNamespace("randomForest", quietly = TRUE)
 gbm_available <- requireNamespace("gbm", quietly = TRUE)

 # ---- Load Data ----
 # Expects Boston.csv in the working directory
boston <- read.csv("Boston.csv")

# Create output directories
fig_dir <- "figures"
res_dir <- "results"
if (!dir.exists(fig_dir)) dir.create(fig_dir)
if (!dir.exists(res_dir)) dir.create(res_dir)

 # Drop first column if it looks like an index
 if (ncol(boston) > 1 && names(boston)[1] %in% c("X", "Unnamed..0", "index")) {
   boston <- boston[, -1]
 }

 # Basic cleaning
 if ("chas" %in% names(boston)) boston$chas <- factor(boston$chas)

 # Remove rows with any NA
 boston <- boston %>% drop_na()

 # Persist cleaned data
 write.csv(boston, "clean_boston.csv", row.names = FALSE)

 # ---- EDA ----
 # Glimpse and missingness summary
 print(glimpse(boston))
 print(colSums(is.na(boston)))

 # Correlation heatmap for numeric columns
 numeric_cols <- boston %>% select(where(is.numeric))
 if (ncol(numeric_cols) > 1) {
   cor_matrix <- cor(numeric_cols)
   cor_df <- as.data.frame(as.table(cor_matrix)) %>%
     setNames(c("Var1", "Var2", "value"))
   p_cor <- ggplot(cor_df, aes(Var1, Var2, fill = value)) +
     geom_tile(color = "white") +
     scale_fill_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0, limits = c(-1, 1)) +
     theme_minimal() +
     theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
     labs(title = "Correlation Heatmap", x = "", y = "")
   print(p_cor)
 }

if (exists("p_cor")) {
  try(ggsave(file.path(fig_dir, "correlation_heatmap.png"), p_cor, width = 8, height = 6, dpi = 150))
}

 # ---- Train/Test Split ----
 stopifnot("medv" %in% names(boston))
 set.seed(123)
 train_idx <- createDataPartition(boston$medv, p = 0.8, list = FALSE)
 train <- boston[train_idx, ]
 test  <- boston[-train_idx, ]

 # Preprocess: center/scale numeric predictors
 numeric_predictors <- setdiff(names(train %>% select(where(is.numeric))), c("medv"))
 preproc <- preProcess(train[, numeric_predictors], method = c("center", "scale"))
 train_scaled <- train
 train_scaled[, numeric_predictors] <- predict(preproc, train[, numeric_predictors])

 test_scaled <- test
 test_scaled[, numeric_predictors] <- predict(preproc, test[, numeric_predictors])

 # ---- Cross-Validated Models ----
 cv_ctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 3)

 # 1) Linear Regression
 set.seed(123)
 lm_fit <- train(medv ~ ., data = train_scaled, method = "lm", trControl = cv_ctrl)

 # 2) Elastic Net (includes Ridge/Lasso via alpha)
 set.seed(123)
 glmnet_grid <- expand.grid(alpha = seq(0, 1, by = 0.25), lambda = 10^seq(-3, 1, length = 30))
 glmnet_fit <- train(
   medv ~ .,
   data = train_scaled,
   method = "glmnet",
   trControl = cv_ctrl,
   tuneGrid = glmnet_grid,
   standardize = FALSE
 )

 # 3) Random Forest (optional)
 rf_fit <- NULL
 if (rf_available) {
   set.seed(123)
   rf_fit <- train(medv ~ ., data = train_scaled, method = "rf", trControl = cv_ctrl, importance = TRUE)
 }

 # 4) Gradient Boosting (optional)
 gbm_fit <- NULL
 if (gbm_available) {
   set.seed(123)
   gbm_fit <- train(
     medv ~ .,
     data = train_scaled,
     method = "gbm",
     trControl = cv_ctrl,
     verbose = FALSE
   )
 }

 # ---- Evaluation on Test Set ----
 predict_and_metrics <- function(fit, test_df) {
   preds <- predict(fit, newdata = test_df)
   rmse <- RMSE(preds, test_df$medv)
   r2 <- R2(preds, test_df$medv)
   tibble(Model = fit$modelInfo$label %||% fit$method, RMSE = rmse, R2 = r2)
 }
 `%||%` <- function(a, b) if (!is.null(a)) a else b

 results <- bind_rows(
   predict_and_metrics(lm_fit, test_scaled),
   predict_and_metrics(glmnet_fit, test_scaled),
   if (!is.null(rf_fit)) predict_and_metrics(rf_fit, test_scaled) else NULL,
   if (!is.null(gbm_fit)) predict_and_metrics(gbm_fit, test_scaled) else NULL
 ) %>% arrange(RMSE)

print(results)
write.csv(results, file.path(res_dir, "model_comparison_results.csv"), row.names = FALSE)

 # ---- Linear Model Diagnostics (train fit) ----
 lm_model <- lm(medv ~ ., data = train_scaled)
 summary_lm <- summary(lm_model)
 print(summary_lm)

 # Multicollinearity
 if (requireNamespace("car", quietly = TRUE)) {
   vif_vals <- car::vif(lm_model)
   print(vif_vals)
 }

 # Heteroskedasticity (Breusch-Pagan)
 if (requireNamespace("lmtest", quietly = TRUE)) {
   bp <- lmtest::bptest(lm_model)
   print(bp)
 }

 # Normality of residuals
 shapiro_res <- tryCatch(shapiro.test(residuals(lm_model)), error = function(e) NULL)
 print(shapiro_res)

 # Influence diagnostics (Cook's distance)
 cooks <- cooks.distance(lm_model)
 inf_df <- tibble(index = seq_along(cooks), cooks = as.numeric(cooks)) %>%
   arrange(desc(cooks)) %>% slice(1:10)
 print(inf_df)

 # ---- ANOVA and Post-hoc on Distance Groups ----
 if ("dis" %in% names(boston)) {
   dis_breaks <- quantile(boston$dis, probs = c(0, 0.33, 0.66, 1), na.rm = TRUE)
   boston$dis_group <- cut(boston$dis, breaks = dis_breaks, labels = c("Near", "Mid", "Far"), include.lowest = TRUE)
   dis_aov <- aov(medv ~ dis_group, data = boston)
   print(summary(dis_aov))
   if (requireNamespace("stats", quietly = TRUE)) {
     print(TukeyHSD(dis_aov))
   }
   p_box <- ggplot(boston, aes(x = dis_group, y = medv, fill = dis_group)) +
     geom_boxplot(alpha = 0.8) +
     theme_minimal() +
     labs(title = "Median Home Value by Distance Group", x = "Distance Group", y = "medv")
   print(p_box)
 }

if (exists("p_box")) {
  try(ggsave(file.path(fig_dir, "boxplot_medv_by_dis_group.png"), p_box, width = 8, height = 6, dpi = 150))
}

 # ---- ANCOVA: ptratio and rm (if available) ----
 if (all(c("ptratio", "rm") %in% names(boston))) {
   ancova_model <- lm(medv ~ ptratio + rm, data = boston)
   print(car::Anova(ancova_model, type = 2))
 }

 # ---- Feature importance for glmnet ----
 if (!is.null(glmnet_fit$finalModel)) {
   best <- glmnet_fit$bestTune
   coefs <- coef(glmnet_fit$finalModel, s = best$lambda)
   lasso_df <- data.frame(
     Feature = rownames(coefs),
     Coefficient = as.numeric(coefs)
   ) %>% filter(Feature != "(Intercept)") %>% arrange(desc(abs(Coefficient)))
   print(head(lasso_df, 20))
  top_coefs <- lasso_df %>% slice_max(order_by = abs(Coefficient), n = 20)
  p_imp <- ggplot(top_coefs, aes(x = reorder(Feature, Coefficient), y = Coefficient)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    theme_minimal() +
    labs(title = "Elastic Net: Top 20 Coefficients", x = "Feature", y = "Coefficient")
  print(p_imp)
  try(ggsave(file.path(fig_dir, "elastic_net_top20_coefficients.png"), p_imp, width = 8, height = 6, dpi = 150))
 }

 # ---- Save session info for reproducibility ----
writeLines(capture.output(sessionInfo()), file.path(res_dir, "sessionInfo.txt"))

cat("\nAnalysis complete. Key files written:\n",
    "- clean_boston.csv\n",
    paste0("- ", file.path(res_dir, "model_comparison_results.csv"), "\n"),
    paste0("- ", file.path(res_dir, "sessionInfo.txt"), "\n"),
    paste0("- ", file.path(fig_dir, "*.png"), "\n"))

