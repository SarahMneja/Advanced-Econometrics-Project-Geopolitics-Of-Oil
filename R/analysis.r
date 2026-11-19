# =============================================================================
# Panel Data Econometrics - FULL GOOGLE COLAB R SCRIPT
# Project: The Geopolitics of Oil - Assessing the Macroeconomic Impact
#          of the 2026 Gulf Crisis
 =============================================================================




# ============================================================
# CELL 0: UPLOAD DATASET (Run this cell FIRST)
# ============================================================


# --- Option A: Interactive upload (recommended) ---
# Uncomment the 3 lines below to use a file picker:
# library(googledrive)
# uploaded <- shiny::fileUpload("panel_data_econometrics.csv")
# file.copy(uploaded$datapath, "/content/panel_data_econometrics.csv")


# --- Option B: Manual upload via sidebar ---
# Just use the folder icon on the left, click upload, and select your CSV.
# No code needed - the file goes to /content/ automatically.


# --- Option C: Mount Google Drive ---
# If your file is on Google Drive, uncomment these lines:
# library(googledrive)
# drive_mount("/content/drive")
# Then copy: file.copy("/content/drive/MyDrive/panel_data_econometrics.csv", "/content/")


# --- Verify the file is there ---
cat("Checking for dataset file...\n")
if (file.exists("/content/panel_data_econometrics.csv")) {
  cat("SUCCESS: panel_data_econometrics.csv found in /content/\n")
  cat(sprintf("  File size: %.1f KB\n", file.size("/content/panel_data_econometrics.csv") / 1024))
} else {
  cat("WARNING: panel_data_econometrics.csv NOT found in /content/\n")
  cat("Please upload it using the folder icon on the left sidebar,\n")
  cat("then re-run this cell to verify.\n")
}




# ============================================================
# CELL 1: INSTALL AND LOAD PACKAGES
# ============================================================
# In Colab R runtime, packages need to be installed each session
# (the environment resets when you close the notebook).
# This takes ~2-3 minutes the first time.


cat("Installing required packages (this may take a few minutes)...\n\n")


# Set CRAN mirror for Colab
options(repos = c(CRAN = "https://cloud.r-project.org"))


# Install packages (Colab has some pre-installed, but we ensure all are present)
pkg_list <- c("tidyverse", "plm", "lmtest", "stargazer", "ggplot2",
              "car", "sandwich")


for (pkg in pkg_list) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("Installing %s...\n", pkg))
    install.packages(pkg, quiet = TRUE)
  } else {
    cat(sprintf("%s already installed.\n", pkg))
  }
}


cat("\nLoading packages...\n")
library(tidyverse)    # Data manipulation and plotting
library(plm)          # Panel data econometrics
library(lmtest)       # Robust standard errors and tests
library(stargazer)    # Publication-quality regression tables
library(ggplot2)      # Advanced plotting
library(car)          # Hypothesis tests
library(sandwich)     # Robust covariance matrices


cat("\nAll packages loaded successfully!\n")


# Colab-specific plot settings (larger default plot size)
options(repr.plot.width = 12, repr.plot.height = 6)




# ============================================================
# CELL 2: LOAD AND PREPARE THE DATA
# ============================================================
cat("Loading dataset from /content/...\n\n")


data_file <- "/content/panel_data_econometrics.csv"


# Check if file exists
if (!file.exists(data_file)) {
  stop("ERROR: panel_data_econometrics.csv not found in /content/!\n
       Please upload it using the folder icon on the left sidebar, then re-run.")
}


data_raw <- read.csv(data_file, stringsAsFactors = FALSE)


# Inspect the data structure
cat("=== Data Structure ===\n")
str(data_raw)
cat("\n")


cat("=== First 6 Rows ===\n")
print(head(data_raw))
cat("\n")


cat("=== Summary Statistics ===\n")
print(summary(data_raw[, c("cpi", "ipi", "brent", "neer", "policy_rate", "vix",
                            "oil_pct_change", "post_crisis")]))
cat("\n")


# Convert date column to Date format
data_raw$date <- as.Date(data_raw$date)


# Re-verify derived variables for reproducibility
data_processed <- data_raw %>%
  mutate(
    ln_cpi  = log(cpi),
    ln_ipi  = log(ipi),
    ln_neer = log(neer),
    post_crisis = ifelse(date >= as.Date("2026-03-01"), 1, 0),
    oil_pct_change = c(NA, diff(brent) / head(brent, -1) * 100)
  ) %>%
  group_by(country) %>%
  mutate(oil_pct_change = ifelse(is.na(oil_pct_change), 0, oil_pct_change)) %>%
  ungroup() %>%
  filter(!is.na(ln_cpi), !is.na(ln_ipi), !is.na(oil_pct_change))


cat(sprintf("Processed dataset: %d rows x %d columns\n",
            nrow(data_processed), ncol(data_processed)))
cat(sprintf("Countries: %s\n", paste(unique(data_processed$country), collapse = ", ")))
cat(sprintf("Date range: %s to %s\n",
            as.character(min(data_processed$date)),
            as.character(max(data_processed$date))))
cat(sprintf("Observations per country: %s\n\n",
            paste(tapply(data_processed$country, data_processed$country, length), collapse = ", ")))




# ============================================================
# CELL 3: EXPLORATORY DATA ANALYSIS (EDA) - PLOTS
# ============================================================
# In Google Colab, ggplot graphs are displayed INLINE automatically
# when you print() them. No need to save to file.


cat("Generating EDA plots...\n\n")


# --- 3a. Brent Crude Oil Price over time ---
plot_brent <- ggplot(data_processed, aes(x = date, y = brent)) +
  geom_line(color = "darkred", linewidth = 0.8) +
  geom_vline(xintercept = as.Date("2026-03-01"),
             linetype = "dashed", color = "blue", linewidth = 0.7) +
  annotate("text", x = as.Date("2026-03-01"), y = max(data_processed$brent) * 1.02,
           label = "Crisis Start\n(Mar 2026)", hjust = -0.05, size = 3.2, color = "blue") +
  labs(
    title = "Brent Crude Oil Price: Pre and Post 2026 Gulf Crisis",
    subtitle = "Monthly average, USD per barrel",
    x = "Date", y = "USD per Barrel"
  ) +
  theme_minimal(base_size = 14)


print(plot_brent)
cat("Plot: Brent Oil Price displayed above.\n\n")


# --- 3b. Log CPI trends by country ---
plot_cpi <- ggplot(data_processed, aes(x = date, y = ln_cpi, color = country)) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = as.Date("2026-03-01"),
             linetype = "dashed", color = "gray40") +
  labs(
    title = "Log(CPI) Trends by Country",
    subtitle = "Consumer Price Index (2015 = 100), natural log",
    x = "Date", y = "Log(CPI)", color = "Country"
  ) +
  theme_minimal(base_size = 14) +
  scale_color_manual(values = c("Germany" = "#E41A1C",
                                 "France" = "#377EB8",
                                 "Italy" = "#4DAF4A"))


print(plot_cpi)
cat("Plot: Log(CPI) by Country displayed above.\n\n")


# --- 3c. Log IPI trends by country ---
plot_ipi <- ggplot(data_processed, aes(x = date, y = ln_ipi, color = country)) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = as.Date("2026-03-01"),
             linetype = "dashed", color = "gray40") +
  labs(
    title = "Log(IPI) Trends by Country",
    subtitle = "Industrial Production Index (2015 = 100), natural log",
    x = "Date", y = "Log(IPI)", color = "Country"
  ) +
  theme_minimal(base_size = 14) +
  scale_color_manual(values = c("Germany" = "#E41A1C",
                                 "France" = "#377EB8",
                                 "Italy" = "#4DAF4A"))


print(plot_ipi)
cat("Plot: Log(IPI) by Country displayed above.\n\n")


# --- 3d. Oil price % change (the shock variable) ---
plot_shock <- ggplot(data_processed, aes(x = date, y = oil_pct_change)) +
  geom_col(aes(fill = post_crisis == 1), alpha = 0.8) +
  geom_vline(xintercept = as.Date("2026-03-01"),
             linetype = "dashed", color = "blue") +
  labs(
    title = "Oil Price Percentage Change (The Geopolitical Shock)",
    subtitle = "Monthly % change in Brent crude oil price",
    x = "Date", y = "% Change", fill = "Post-Crisis"
  ) +
  scale_fill_manual(labels = c("Pre-Crisis", "Post-Crisis"),
                    values = c("FALSE" = "steelblue", "TRUE" = "darkred")) +
  theme_minimal(base_size = 14)


print(plot_shock)
cat("Plot: Oil Price Shock displayed above.\n\n")


# --- 3e. VIX over time ---
plot_vix <- ggplot(data_processed, aes(x = date, y = vix)) +
  geom_line(color = "darkorange", linewidth = 0.8) +
  geom_vline(xintercept = as.Date("2026-03-01"),
             linetype = "dashed", color = "blue") +
  labs(
    title = "VIX Volatility Index Over Time",
    subtitle = "Proxy for global financial uncertainty and risk aversion",
    x = "Date", y = "VIX"
  ) +
  theme_minimal(base_size = 14)


print(plot_vix)
cat("Plot: VIX Index displayed above.\n\n")


# --- 3f. Combined faceted plot for comparison ---
plot_combined <- data_processed %>%
  select(country, date, ln_cpi, ln_ipi, oil_pct_change) %>%
  pivot_longer(cols = c(ln_cpi, ln_ipi, oil_pct_change),
               names_to = "variable", values_to = "value") %>%
  mutate(variable_label = case_when(
    variable == "ln_cpi" ~ "Log(CPI) - Inflation",
    variable == "ln_ipi" ~ "Log(IPI) - Industrial Production",
    variable == "oil_pct_change" ~ "Oil Price Change (%)"
  )) %>%
  ggplot(aes(x = date, y = value, color = country)) +
  geom_line(linewidth = 0.7) +
  geom_vline(xintercept = as.Date("2026-03-01"),
             linetype = "dashed", color = "gray40") +
  facet_wrap(~ variable_label, scales = "free_y", ncol = 1) +
  labs(title = "Key Variables Over Time: Pre and Post 2026 Gulf Crisis",
       x = "Date", y = "Value", color = "Country") +
  theme_minimal(base_size = 13) +
  scale_color_manual(values = c("Germany" = "#E41A1C",
                                 "France" = "#377EB8",
                                 "Italy" = "#4DAF4A"))


print(plot_combined)
cat("Plot: Combined faceted view displayed above.\n\n")




# ============================================================
# CELL 4: DESCRIPTIVE STATISTICS TABLE
# ============================================================
cat("=== Descriptive Statistics ===\n\n")


# Variable means by country
cat("Variable means by country:\n")
means_table <- data_processed %>%
  select(country, cpi, ipi, brent, neer, policy_rate, vix, oil_pct_change) %>%
  group_by(country) %>%
  summarise(across(everything(), ~mean(., na.rm = TRUE), .names = "{.col}"))
print(means_table, digits = 3)
cat("\n")


# Full descriptive stats by country
cat("Full descriptive statistics by country:\n")
desc_stats <- data_processed %>%
  select(country, cpi, ipi, brent, neer, policy_rate, vix, oil_pct_change) %>%
  group_by(country) %>%
  summarise(
    across(everything(), list(
      Mean = ~mean(., na.rm = TRUE),
      SD   = ~sd(., na.rm = TRUE),
      Min  = ~min(., na.rm = TRUE),
      Max  = ~max(., na.rm = TRUE)
    ), .names = "{.col}_{.fn}")
  )
print(desc_stats, digits = 3)
cat("\n")


# Correlation matrix for key variables
cat("Correlation matrix (key variables):\n")
cor_matrix <- cor(data_processed %>%
  select(ln_cpi, ln_ipi, oil_pct_change, ln_neer, policy_rate, vix),
  use = "complete.obs")
print(round(cor_matrix, 3))
cat("\n")


# Pre vs Post crisis comparison
cat("Pre vs Post Crisis Comparison:\n")
pre_post <- data_processed %>%
  mutate(period = ifelse(post_crisis == 1, "Post-Crisis (Mar-Jun 2026)", "Pre-Crisis (Jan 2023-Feb 2026)")) %>%
  group_by(period) %>%
  summarise(
    mean_cpi = mean(cpi),
    mean_ipi = mean(ipi),
    mean_brent = mean(brent),
    mean_vix = mean(vix),
    mean_oil_pct = mean(oil_pct_change)
  )
print(pre_post, digits = 2)
cat("\n")




# ============================================================
# CELL 5: PANEL DATA REGRESSION ANALYSIS
# ============================================================
cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("PANEL DATA REGRESSION ANALYSIS\n")
cat(paste0(rep("=", 69), collapse = ""), "\n\n")


# Declare the data as a panel data frame
pdata <- pdata.frame(data_processed, index = c("country", "date"))


cat(sprintf("Panel dimensions: %d individuals (countries), %d time periods (months)\n\n",
            length(unique(pdata$country)), length(unique(pdata$date))))


# ----------------------------------------
# MODEL SET A: Dependent Variable = ln_cpi (Inflation)
# ----------------------------------------
cat("--- MODEL SET A: Dependent Variable = ln_cpi (Inflation) ---\n\n")


# Model 1A: Pooled OLS (POLS) - Inflation
pols_cpi <- plm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
                data = pdata, model = "pooling")
cat("Pooled OLS (ln_cpi):\n")
summary(pols_cpi)
cat("\n")


# Model 2A: Fixed Effects (FE) - Inflation
fe_cpi <- plm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
              data = pdata, model = "within")
cat("Fixed Effects (ln_cpi):\n")
summary(fe_cpi)
cat("\n")


# Model 3A: Random Effects (RE) - Inflation
# NOTE: With only 3 countries, the default Swamy-Arora ("swar") method fails.
# We use Wallace-Hussain ("walhus") which works with small N.
re_cpi <- plm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
              data = pdata, model = "random", random.method = "walhus")
cat("Random Effects (ln_cpi) [Wallace-Hussain method]:\n")
summary(re_cpi)
cat("\n")


# ----------------------------------------
# MODEL SET B: Dependent Variable = ln_ipi (Growth/Output)
# ----------------------------------------
cat("--- MODEL SET B: Dependent Variable = ln_ipi (Growth/Output) ---\n\n")


# Model 1B: Pooled OLS (POLS) - Growth
pols_ipi <- plm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
                data = pdata, model = "pooling")
cat("Pooled OLS (ln_ipi):\n")
summary(pols_ipi)
cat("\n")


# Model 2B: Fixed Effects (FE) - Growth
fe_ipi <- plm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
              data = pdata, model = "within")
cat("Fixed Effects (ln_ipi):\n")
summary(fe_ipi)
cat("\n")


# Model 3B: Random Effects (RE) - Growth
# NOTE: With only 3 countries, we use Wallace-Hussain method (same as above).
re_ipi <- plm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
              data = pdata, model = "random", random.method = "walhus")
cat("Random Effects (ln_ipi) [Wallace-Hussain method]:\n")
summary(re_ipi)
cat("\n")




# ============================================================
# CELL 6: DIAGNOSTIC TESTS
# ============================================================
cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("DIAGNOSTIC TESTS\n")
cat(paste0(rep("=", 69), collapse = ""), "\n\n")


# --- 6a. Hausman Test: FE vs RE ---
cat("--- Hausman Test (FE vs RE) ---\n\n")


# For Inflation model
hausman_cpi <- phtest(fe_cpi, re_cpi)
cat("Hausman Test (ln_cpi models):\n")
print(hausman_cpi)
if (hausman_cpi$p.value < 0.05) {
  cat("  => p < 0.05: REJECTED H0. Fixed Effects model is preferred for inflation.\n")
} else {
  cat("  => p >= 0.05: FAIL TO REJECT H0. Random Effects model is acceptable for inflation.\n")
}
cat("\n")


# For Growth model
hausman_ipi <- phtest(fe_ipi, re_ipi)
cat("Hausman Test (ln_ipi models):\n")
print(hausman_ipi)
if (hausman_ipi$p.value < 0.05) {
  cat("  => p < 0.05: REJECTED H0. Fixed Effects model is preferred for growth.\n")
} else {
  cat("  => p >= 0.05: FAIL TO REJECT H0. Random Effects model is acceptable for growth.\n")
}
cat("\n")


# --- 6b. Breusch-Pagan Lagrange Multiplier Test: POLS vs RE ---
cat("--- Breusch-Pagan LM Test (POLS vs RE) ---\n\n")


# For Inflation model
bp_cpi <- plmtest(pols_cpi, effect = "individual", type = "bp")
cat("Breusch-Pagan LM Test (ln_cpi models):\n")
print(bp_cpi)
if (bp_cpi$p.value < 0.05) {
  cat("  => p < 0.05: REJECTED H0. Random Effects is preferred over Pooled OLS.\n")
} else {
  cat("  => p >= 0.05: FAIL TO REJECT H0. Pooled OLS is sufficient.\n")
}
cat("\n")


# For Growth model
bp_ipi <- plmtest(pols_ipi, effect = "individual", type = "bp")
cat("Breusch-Pagan LM Test (ln_ipi models):\n")
print(bp_ipi)
if (bp_ipi$p.value < 0.05) {
  cat("  => p < 0.05: REJECTED H0. Random Effects is preferred over Pooled OLS.\n")
} else {
  cat("  => p >= 0.05: FAIL TO REJECT H0. Pooled OLS is sufficient.\n")
}
cat("\n")


# --- 6c. Serial Correlation Test ---
cat("--- Serial Correlation Test (Wooldridge) ---\n\n")


# For FE inflation model
bptest_fe_cpi <- pdwtest(fe_cpi)
cat("Wooldridge Test for Serial Correlation (FE ln_cpi):\n")
print(bptest_fe_cpi)
cat("\n")


bptest_fe_ipi <- pdwtest(fe_ipi)
cat("Wooldridge Test for Serial Correlation (FE ln_ipi):\n")
print(bptest_fe_ipi)
cat("\n")


# --- 6d. Robust Standard Errors ---
cat("--- Robust Standard Errors ---\n\n")


# FE Inflation model with Arellano robust SE (clustered by individual)
cat("FE Inflation model - Arellano (1987) robust SE:\n")
fe_cpi_robust <- coeftest(fe_cpi, vcov = vcovHC(fe_cpi, method = "arellano", type = "HC3"))
print(fe_cpi_robust)
cat("\n")


# FE Growth model with Arellano robust SE
cat("FE Growth model - Arellano (1987) robust SE:\n")
fe_ipi_robust <- coeftest(fe_ipi, vcov = vcovHC(fe_ipi, method = "arellano", type = "HC3"))
print(fe_ipi_robust)
cat("\n")


# Double-clustered SE (Driscoll-Kraay) for FE inflation
cat("FE Inflation model - Double-clustered SE (Driscoll-Kraay):\n")
fe_cpi_dk <- coeftest(fe_cpi, vcov = vcovSCC(fe_cpi, type = "HC3"))
print(fe_cpi_dk)
cat("\n")


cat("FE Growth model - Double-clustered SE (Driscoll-Kraay):\n")
fe_ipi_dk <- coeftest(fe_ipi, vcov = vcovSCC(fe_ipi, type = "HC3"))
print(fe_ipi_dk)
cat("\n")




# ============================================================
# CELL 7: COUNTRY-LEVEL HETEROGENEITY ANALYSIS
# ============================================================
cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("COUNTRY-LEVEL HETEROGENEITY ANALYSIS\n")
cat(paste0(rep("=", 69), collapse = ""), "\n\n")


cat("NOTE: All 3 countries (Germany, France, Italy) are Advanced Net-Importers.\n")
cat("We analyze heterogeneity by individual country instead of importer/exporter split.\n\n")


# --- 7a. Country-by-country models for Inflation ---
cat("--- Country-by-Country Models (ln_cpi) ---\n\n")


country_cpi_models <- list()
for (cntry in c("Germany", "France", "Italy")) {
  cd <- data_processed %>% filter(country == cntry)
  m <- lm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
          data = cd)
  # Assign clean call to avoid stargazer naming bug
  m$call <- call("lm", formula = ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis)
  country_cpi_models[[cntry]] <- m
}


cat("Country-level Inflation models (OLS per country):\n")
tryCatch({
  stargazer(country_cpi_models[["Germany"]], country_cpi_models[["France"]], country_cpi_models[["Italy"]],
            title = "Oil Shock Impact on Inflation (ln_cpi): By Country",
            column.labels = c("Germany", "France", "Italy"),
            dep.var.labels = "Log(CPI)",
            type = "text",
            keep.stat = c("n", "rsq", "adj.rsq"),
            df = FALSE,
            object.names = FALSE,
            model.numbers = TRUE)
}, error = function(e) {
  cat("Stargazer table failed. Printing model summaries instead:\n")
  for (cntry in c("Germany", "France", "Italy")) {
    cat(sprintf("\n--- %s ---\n", cntry))
    print(summary(country_cpi_models[[cntry]]))
  }
})
cat("\n")


# --- 7b. Country-by-country models for Growth ---
cat("--- Country-by-Country Models (ln_ipi) ---\n\n")


country_ipi_models <- list()
for (cntry in c("Germany", "France", "Italy")) {
  cd <- data_processed %>% filter(country == cntry)
  m <- lm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
          data = cd)
  # Assign clean call to avoid stargazer naming bug
  m$call <- call("lm", formula = ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis)
  country_ipi_models[[cntry]] <- m
}


cat("Country-level Growth models (OLS per country):\n")
tryCatch({
  stargazer(country_ipi_models[["Germany"]], country_ipi_models[["France"]], country_ipi_models[["Italy"]],
            title = "Oil Shock Impact on Industrial Production (ln_ipi): By Country",
            column.labels = c("Germany", "France", "Italy"),
            dep.var.labels = "Log(IPI)",
            type = "text",
            keep.stat = c("n", "rsq", "adj.rsq"),
            df = FALSE,
            object.names = FALSE,
            model.numbers = TRUE)
}, error = function(e) {
  cat("Stargazer table failed. Printing model summaries instead:\n")
  for (cntry in c("Germany", "France", "Italy")) {
    cat(sprintf("\n--- %s ---\n", cntry))
    print(summary(country_ipi_models[[cntry]]))
  }
})
cat("\n")


# --- 7c. Importers subset FE model ---
cat("--- All Importers: FE Models ---\n\n")


importers_data <- pdata  # All 3 countries are importers


fe_importers_cpi <- plm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
                         data = importers_data, model = "within")
fe_importers_ipi <- plm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
                         data = importers_data, model = "within")


cat("Importers FE (ln_cpi):\n")
summary(fe_importers_cpi)
cat("\n")
cat("Importers FE (ln_ipi):\n")
summary(fe_importers_ipi)
cat("\n")




# ============================================================
# CELL 8: PUBLICATION-QUALITY REGRESSION TABLES
# ============================================================
cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("PUBLICATION-QUALITY REGRESSION TABLES\n")
cat(paste0(rep("=", 69), collapse = ""), "\n\n")


# --- 8a. Main Table: Inflation Models (POLS, FE, RE) ---
cat("--- Table 1: Inflation Models (Dependent Variable: ln_cpi) ---\n\n")


tryCatch({
  stargazer(pols_cpi, fe_cpi, re_cpi,
            title = "Panel Data Estimates: Impact of Oil Price Shock on Inflation (ln CPI)",
            column.labels = c("Pooled OLS", "Fixed Effects", "Random Effects"),
            dep.var.labels = "Log(CPI)",
            covariate.labels = c(
              "Oil Price Shock (%)",
              "Log(NEER)",
              "Policy Rate (%)",
              "VIX",
              "Post-Crisis Dummy"
            ),
            type = "text",
            keep.stat = c("n", "rsq", "adj.rsq"),
            df = FALSE,
            object.names = FALSE,
            star.cutoffs = c(0.05, 0.01, 0.001))
}, error = function(e) {
  cat("Stargazer table failed. Printing model summaries instead:\n")
  cat("Pooled OLS:\n"); print(summary(pols_cpi))
  cat("Fixed Effects:\n"); print(summary(fe_cpi))
  cat("Random Effects:\n"); print(summary(re_cpi))
})


cat("\n\n")


# --- 8b. Main Table: Growth Models (POLS, FE, RE) ---
cat("--- Table 2: Growth Models (Dependent Variable: ln_ipi) ---\n\n")


tryCatch({
  stargazer(pols_ipi, fe_ipi, re_ipi,
            title = "Panel Data Estimates: Impact of Oil Price Shock on Industrial Production (ln IPI)",
            column.labels = c("Pooled OLS", "Fixed Effects", "Random Effects"),
            dep.var.labels = "Log(IPI)",
            covariate.labels = c(
              "Oil Price Shock (%)",
              "Log(NEER)",
              "Policy Rate (%)",
              "VIX",
              "Post-Crisis Dummy"
            ),
            type = "text",
            keep.stat = c("n", "rsq", "adj.rsq"),
            df = FALSE,
            object.names = FALSE,
            star.cutoffs = c(0.05, 0.01, 0.001))
}, error = function(e) {
  cat("Stargazer table failed. Printing model summaries instead:\n")
  cat("Pooled OLS:\n"); print(summary(pols_ipi))
  cat("Fixed Effects:\n"); print(summary(fe_ipi))
  cat("Random Effects:\n"); print(summary(re_ipi))
})


cat("\n\n")


# --- 8c. Robust SE Table: FE with different SE adjustments ---
cat("--- Table 3: Fixed Effects with Robust Standard Errors ---\n\n")


cat("Inflation (ln_cpi) - FE with various robust SE:\n")
cat("Standard SE:\n");   print(coeftest(fe_cpi))
cat("Arellano SE:\n");   print(coeftest(fe_cpi, vcov = vcovHC(fe_cpi, method = "arellano", type = "HC3")))
cat("Driscoll-Kraay SE:\n"); print(coeftest(fe_cpi, vcov = vcovSCC(fe_cpi, type = "HC3")))
cat("\n")


cat("Growth (ln_ipi) - FE with various robust SE:\n")
cat("Standard SE:\n");   print(coeftest(fe_ipi))
cat("Arellano SE:\n");   print(coeftest(fe_ipi, vcov = vcovHC(fe_ipi, method = "arellano", type = "HC3")))
cat("Driscoll-Kraay SE:\n"); print(coeftest(fe_ipi, vcov = vcovSCC(fe_ipi, type = "HC3")))
cat("\n")


# --- 8d. Comprehensive stargazer table: All 6 main models ---
cat("--- Table 4: All Models Side-by-Side ---\n\n")


tryCatch({
  stargazer(pols_cpi, fe_cpi, re_cpi, pols_ipi, fe_ipi, re_ipi,
            title = "Complete Panel Data Results: Oil Price Shocks on Inflation and Growth",
            column.labels = c("POLS", "FE", "RE", "POLS", "FE", "RE"),
            column.separate = c(3, 3),
            dep.var.labels = c("Log(CPI)", "Log(IPI)"),
            covariate.labels = c(
              "Oil Price Shock (%)",
              "Log(NEER)",
              "Policy Rate (%)",
              "VIX",
              "Post-Crisis Dummy"
            ),
            type = "text",
            keep.stat = c("n", "rsq", "adj.rsq"),
            df = FALSE,
            object.names = FALSE,
            star.cutoffs = c(0.05, 0.01, 0.001),
            notes = "All models estimated with panel-corrected data. 3 countries, 42 months each.")
}, error = function(e) {
  cat("Stargazer comprehensive table failed. Individual tables already printed above.\n")
})


cat("\n")




# ============================================================
# CELL 9: INTERACTION TERMS & ADVANCED MODELS
# ============================================================
cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("INTERACTION TERMS & ADVANCED MODELS\n")
cat(paste0(rep("=", 69), collapse = ""), "\n\n")


# --- 9a. Interaction: Oil Shock x Post-Crisis ---
cat("--- Interaction: Oil Shock x Post-Crisis ---\n\n")
cat("Does the oil shock have a DIFFERENT effect during the crisis period?\n\n")


fe_interaction_cpi <- plm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix +
                            post_crisis + oil_pct_change:post_crisis,
                          data = pdata, model = "within")
cat("FE Inflation with Oil Shock x Post-Crisis interaction:\n")
summary(fe_interaction_cpi)
cat("\n")


fe_interaction_ipi <- plm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix +
                            post_crisis + oil_pct_change:post_crisis,
                          data = pdata, model = "within")
cat("FE Growth with Oil Shock x Post-Crisis interaction:\n")
summary(fe_interaction_ipi)
cat("\n")


# --- 9b. Two-way FE (country + time fixed effects) ---
cat("--- Two-Way Fixed Effects (Country + Time) ---\n\n")


fe_twoway_cpi <- plm(ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
                      data = pdata, model = "within", effect = "twoways")
cat("Two-way FE Inflation:\n")
summary(fe_twoway_cpi)
cat("\n")


fe_twoway_ipi <- plm(ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis,
                      data = pdata, model = "within", effect = "twoways")
cat("Two-way FE Growth:\n")
summary(fe_twoway_ipi)
cat("\n")


# --- 9c. stargazer table for advanced models ---
cat("--- Advanced Models Summary Table ---\n\n")


tryCatch({
  stargazer(fe_interaction_cpi, fe_interaction_ipi, fe_twoway_cpi, fe_twoway_ipi,
            title = "Advanced Models: Interactions and Two-Way Fixed Effects",
            column.labels = c("Interaction CPI", "Interaction IPI",
                             "Two-Way FE CPI", "Two-Way FE IPI"),
            dep.var.labels = c("Log(CPI)", "Log(IPI)", "Log(CPI)", "Log(IPI)"),
            covariate.labels = c(
              "Oil Price Shock (%)",
              "Log(NEER)",
              "Policy Rate (%)",
              "VIX",
              "Post-Crisis Dummy",
              "Oil Shock x Post-Crisis"
            ),
            type = "text",
            keep.stat = c("n", "rsq", "adj.rsq"),
            df = FALSE,
            object.names = FALSE,
            star.cutoffs = c(0.05, 0.01, 0.001))
}, error = function(e) {
  cat("Stargazer advanced table failed. Printing model summaries instead:\n")
  cat("Interaction CPI:\n"); print(summary(fe_interaction_cpi))
  cat("Interaction IPI:\n"); print(summary(fe_interaction_ipi))
  cat("Two-Way FE CPI:\n"); print(summary(fe_twoway_cpi))
  cat("Two-Way FE IPI:\n"); print(summary(fe_twoway_ipi))
})


cat("\n")




# ============================================================
# CELL 10: SUMMARY OF KEY FINDINGS
# ============================================================
cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("SUMMARY OF KEY FINDINGS\n")
cat(paste0(rep("=", 69), collapse = ""), "\n\n")


# Extract key coefficients from FE models
fe_cpi_coef <- summary(fe_cpi)$coefficients
fe_ipi_coef <- summary(fe_ipi)$coefficients


cat("INFLATION MODEL (FE, ln_cpi):\n")
cat(sprintf("  Oil Shock coefficient (b1):     %.4f (p = %.4f) %s\n",
            fe_cpi_coef["oil_pct_change", "Estimate"],
            fe_cpi_coef["oil_pct_change", "Pr(>|t|)"],
            ifelse(fe_cpi_coef["oil_pct_change", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  Log(NEER) coefficient (b2):     %.4f (p = %.4f) %s\n",
            fe_cpi_coef["ln_neer", "Estimate"],
            fe_cpi_coef["ln_neer", "Pr(>|t|)"],
            ifelse(fe_cpi_coef["ln_neer", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  Policy Rate coefficient (b3):   %.4f (p = %.4f) %s\n",
            fe_cpi_coef["policy_rate", "Estimate"],
            fe_cpi_coef["policy_rate", "Pr(>|t|)"],
            ifelse(fe_cpi_coef["policy_rate", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  VIX coefficient (b4):           %.4f (p = %.4f) %s\n",
            fe_cpi_coef["vix", "Estimate"],
            fe_cpi_coef["vix", "Pr(>|t|)"],
            ifelse(fe_cpi_coef["vix", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  Post-Crisis coefficient:        %.4f (p = %.4f) %s\n",
            fe_cpi_coef["post_crisis", "Estimate"],
            fe_cpi_coef["post_crisis", "Pr(>|t|)"],
            ifelse(fe_cpi_coef["post_crisis", "Pr(>|t|)"] < 0.05, "***", "")))
cat("\n")


cat("GROWTH MODEL (FE, ln_ipi):\n")
cat(sprintf("  Oil Shock coefficient (b1):     %.4f (p = %.4f) %s\n",
            fe_ipi_coef["oil_pct_change", "Estimate"],
            fe_ipi_coef["oil_pct_change", "Pr(>|t|)"],
            ifelse(fe_ipi_coef["oil_pct_change", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  Log(NEER) coefficient (b2):     %.4f (p = %.4f) %s\n",
            fe_ipi_coef["ln_neer", "Estimate"],
            fe_ipi_coef["ln_neer", "Pr(>|t|)"],
            ifelse(fe_ipi_coef["ln_neer", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  Policy Rate coefficient (b3):   %.4f (p = %.4f) %s\n",
            fe_ipi_coef["policy_rate", "Estimate"],
            fe_ipi_coef["policy_rate", "Pr(>|t|)"],
            ifelse(fe_ipi_coef["policy_rate", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  VIX coefficient (b4):           %.4f (p = %.4f) %s\n",
            fe_ipi_coef["vix", "Estimate"],
            fe_ipi_coef["vix", "Pr(>|t|)"],
            ifelse(fe_ipi_coef["vix", "Pr(>|t|)"] < 0.05, "***", "")))
cat(sprintf("  Post-Crisis coefficient:        %.4f (p = %.4f) %s\n",
            fe_ipi_coef["post_crisis", "Estimate"],
            fe_ipi_coef["post_crisis", "Pr(>|t|)"],
            ifelse(fe_ipi_coef["post_crisis", "Pr(>|t|)"] < 0.05, "***", "")))
cat("\n")


# Hausman test summary
cat("MODEL SELECTION:\n")
cat(sprintf("  Hausman test (CPI): chi2 = %.3f, p = %.4f => %s\n",
            hausman_cpi$statistic, hausman_cpi$p.value,
            ifelse(hausman_cpi$p.value < 0.05, "FE preferred", "RE acceptable")))
cat(sprintf("  Hausman test (IPI): chi2 = %.3f, p = %.4f => %s\n",
            hausman_ipi$statistic, hausman_ipi$p.value,
            ifelse(hausman_ipi$p.value < 0.05, "FE preferred", "RE acceptable")))
cat(sprintf("  BP LM test (CPI):   chi2 = %.3f, p = %.4f => %s\n",
            bp_cpi$statistic, bp_cpi$p.value,
            ifelse(bp_cpi$p.value < 0.05, "RE > POLS", "POLS sufficient")))
cat(sprintf("  BP LM test (IPI):   chi2 = %.3f, p = %.4f => %s\n",
            bp_ipi$statistic, bp_ipi$p.value,
            ifelse(bp_ipi$p.value < 0.05, "RE > POLS", "POLS sufficient")))
cat("\n")


# Interpretation guidance
cat("ECONOMIC INTERPRETATION:\n")
cat("  - A positive oil_pct_change coefficient for ln_cpi means: a 1% increase\n")
cat("    in oil price raises CPI by b1% (inflationary effect).\n")
cat("  - A negative oil_pct_change coefficient for ln_ipi means: a 1% increase\n")
cat("    in oil price reduces industrial production by b1% (stagflationary effect).\n")
cat("  - The post_crisis dummy captures the level shift after March 2026.\n")
cat("  - Expected signs per theory:\n")
cat("      b1 (oil shock): + for CPI, - for IPI  [stagflation]\n")
cat("      b2 (NEER):      - for CPI              [appreciation lowers import prices]\n")
cat("      b3 (rate):       - for CPI, - for IPI  [contractionary monetary policy]\n")
cat("      b4 (VIX):       + for CPI, - for IPI   [uncertainty increases risk premia]\n")
cat("\n")


cat(paste0(rep("=", 69), collapse = ""), "\n")
cat("END OF ANALYSIS\n")
cat(paste0(rep("=", 69), collapse = ""), "\n")