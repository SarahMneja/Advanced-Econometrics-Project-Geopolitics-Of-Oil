# ============================================================================
# PROJECT: The Geopolitics of Oil - Macroeconomic Impact of the 2026 Gulf Crisis
# DATA PIPELINE: Merge CSVs, Handle Missing Values, ARIMA Forecasting
# Countries: Germany, France, Italy
# Time Period: Jan 2023 - Jun 2026
# ============================================================================


# ============================================================================
# PART 1: ENVIRONMENT SETUP
# ============================================================================


# Clear workspace
rm(list = ls())


# Install required packages (run once)
packages_needed <- c("tidyverse", "lubridate", "zoo", "forecast", "ggplot2")


for (pkg in packages_needed) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
    library(pkg, character.only = TRUE)
  }
}


# Load libraries
library(tidyverse)
library(lubridate)
library(zoo)
library(forecast)
library(ggplot2)


# Create output directories
if (!dir.exists("data")) dir.create("data")
if (!dir.exists("figures")) dir.create("figures")
if (!dir.exists("forecasts")) dir.create("forecasts")


cat("========================================\n")
cat("DATA PIPELINE: MERGING AND FORECASTING\n")
cat("========================================\n\n")


# ============================================================================
# PART 2: LOAD RAW CSV FILES
# ============================================================================


cat("STEP 1: Loading raw CSV files...\n\n")


# CPI data (OECD)
cpi_data <- read.csv("OECD_CPI_DE_FR_IT.csv.csv", stringsAsFactors = FALSE)
cat("  ✓ CPI data loaded\n")


# IPI data
ipi_data <- read.csv("ipi.csv", stringsAsFactors = FALSE)
cat("  ✓ IPI data loaded\n")


# NEER data
neer_data <- read.csv("neer.csv", stringsAsFactors = FALSE)
cat("  ✓ NEER data loaded\n")


# Brent oil price data
brent_data <- read.csv("DCOILBRENTEU.csv", stringsAsFactors = FALSE)
cat("  ✓ Brent data loaded\n")


# VIX data
vix_data <- read.csv("VIXCLS.csv", stringsAsFactors = FALSE)
cat("  ✓ VIX data loaded\n")


# ECB policy rate data
ecb_data <- read.csv("ECBMLFR.csv", stringsAsFactors = FALSE)
cat("  ✓ ECB policy rate data loaded\n\n")


# ============================================================================
# PART 3: PROCESS INDIVIDUAL DATASETS
# ============================================================================


cat("STEP 2: Processing individual datasets...\n\n")


# 3.1 Process CPI data
cpi_clean <- cpi_data %>%
  filter(REF_AREA %in% c("DEU", "FRA", "ITA")) %>%
  mutate(
    date = as.Date(paste0(TIME_PERIOD, "-01")),
    country = case_when(
      REF_AREA == "DEU" ~ "Germany",
      REF_AREA == "FRA" ~ "France",
      REF_AREA == "ITA" ~ "Italy"
    ),
    cpi = as.numeric(OBS_VALUE)
  ) %>%
  filter(date >= as.Date("2023-01-01"), date <= as.Date("2026-03-31")) %>%
  select(country, date, cpi) %>%
  arrange(country, date)


cat("  ✓ CPI processed\n")


# 3.2 Process IPI data
ipi_clean <- ipi_data %>%
  filter(COUNTRY %in% c("Germany", "France", "Italy")) %>%
  mutate(
    year = as.numeric(substr(TIME_PERIOD, 1, 4)),
    month_num = as.numeric(substr(TIME_PERIOD, 6, 7)),
    date = make_date(year, month_num, 1),
    ipi = as.numeric(OBS_VALUE)
  ) %>%
  filter(date >= as.Date("2023-01-01"), date <= as.Date("2026-03-31")) %>%
  select(country = COUNTRY, date, ipi) %>%
  arrange(country, date)


cat("  ✓ IPI processed\n")


# 3.3 Process NEER data
neer_clean <- neer_data %>%
  filter(COUNTRY %in% c("Germany", "France", "Italy")) %>%
  mutate(
    year = as.numeric(substr(TIME_PERIOD, 1, 4)),
    month_num = as.numeric(substr(TIME_PERIOD, 6, 7)),
    date = make_date(year, month_num, 1),
    neer = as.numeric(OBS_VALUE)
  ) %>%
  filter(date >= as.Date("2023-01-01"), date <= as.Date("2026-03-31")) %>%
  select(country = COUNTRY, date, neer) %>%
  arrange(country, date)


cat("  ✓ NEER processed\n")


# 3.4 Process Brent data
brent_clean <- brent_data %>%
  mutate(
    date = as.Date(observation_date),
    brent = as.numeric(DCOILBRENTEU)
  ) %>%
  filter(date >= as.Date("2023-01-01"), date <= as.Date("2026-03-31")) %>%
  arrange(date)


cat("  ✓ Brent processed\n")


# 3.5 Process VIX data
vix_clean <- vix_data %>%
  mutate(
    date = as.Date(observation_date),
    vix = as.numeric(VIXCLS)
  ) %>%
  filter(date >= as.Date("2023-01-01"), date <= as.Date("2026-03-31")) %>%
  arrange(date)


cat("  ✓ VIX processed\n")


# 3.6 Process ECB policy rate data
ecb_clean <- ecb_data %>%
  mutate(
    date = as.Date(observation_date),
    policy_rate = as.numeric(ECBMLFR)
  ) %>%
  filter(date >= as.Date("2023-01-01"), date <= as.Date("2026-03-31")) %>%
  arrange(date)


cat("  ✓ ECB policy rate processed\n\n")


# ============================================================================
# PART 4: MERGE ALL DATASETS
# ============================================================================


cat("STEP 3: Merging datasets into master panel...\n\n")


# Create date sequence
dates <- seq(as.Date("2023-01-01"), as.Date("2026-03-31"), by = "month")
countries <- c("Germany", "France", "Italy")


# Create panel template
panel_template <- expand.grid(country = countries, date = dates, stringsAsFactors = FALSE)


# Merge all datasets using sequential left joins
master_panel <- panel_template %>%
  left_join(cpi_clean, by = c("country", "date")) %>%
  left_join(ipi_clean, by = c("country", "date")) %>%
  left_join(neer_clean, by = c("country", "date")) %>%
  left_join(brent_clean, by = "date") %>%
  left_join(vix_clean, by = "date") %>%
  left_join(ecb_clean, by = "date")


cat("  ✓ Master panel created\n")
cat(paste("  Dimensions:", nrow(master_panel), "rows x", ncol(master_panel), "columns\n"))


# ============================================================================
# PART 5: HANDLE MISSING VALUES (INTERPOLATION)
# ============================================================================


cat("\nSTEP 4: Handling missing values...\n\n")


# Check missing values before
missing_before <- sum(is.na(master_panel))
cat(paste("  Missing values before interpolation:", missing_before, "\n"))


# Interpolate missing values
master_panel <- master_panel %>%
  group_by(country) %>%
  mutate(
    cpi = na.approx(cpi, maxgap = 2, na.rm = FALSE),
    ipi = na.approx(ipi, maxgap = 2, na.rm = FALSE),
    neer = na.approx(neer, maxgap = 2, na.rm = FALSE)
  ) %>%
  ungroup() %>%
  mutate(
    brent = na.approx(brent, maxgap = 2, na.rm = FALSE),
    vix = na.approx(vix, maxgap = 2, na.rm = FALSE),
    policy_rate = na.approx(policy_rate, maxgap = 2, na.rm = FALSE)
  )


# Forward fill any remaining NAs
master_panel <- master_panel %>%
  group_by(country) %>%
  mutate(
    cpi = na.locf(cpi, na.rm = FALSE),
    cpi = na.locf(cpi, fromLast = TRUE, na.rm = FALSE),
    ipi = na.locf(ipi, na.rm = FALSE),
    ipi = na.locf(ipi, fromLast = TRUE, na.rm = FALSE),
    neer = na.locf(neer, na.rm = FALSE),
    neer = na.locf(neer, fromLast = TRUE, na.rm = FALSE)
  ) %>%
  ungroup() %>%
  mutate(
    brent = na.locf(brent, na.rm = FALSE),
    brent = na.locf(brent, fromLast = TRUE, na.rm = FALSE),
    vix = na.locf(vix, na.rm = FALSE),
    vix = na.locf(vix, fromLast = TRUE, na.rm = FALSE),
    policy_rate = na.locf(policy_rate, na.rm = FALSE),
    policy_rate = na.locf(policy_rate, fromLast = TRUE, na.rm = FALSE)
  )


missing_after <- sum(is.na(master_panel))
cat(paste("  Missing values after interpolation:", missing_after, "\n\n"))


# ============================================================================
# PART 6: CALCULATE DERIVED VARIABLES
# ============================================================================


cat("STEP 5: Calculating derived variables...\n\n")


# Calculate oil price changes (global)
brent_unique <- master_panel %>%
  select(date, brent) %>%
  distinct() %>%
  arrange(date)


brent_unique$oil_pct_change <- c(0, diff(brent_unique$brent) / head(brent_unique$brent, -1) * 100)


# Add derived variables to panel
master_panel <- master_panel %>%
  left_join(brent_unique %>% select(date, oil_pct_change), by = "date") %>%
  mutate(
    ln_cpi = log(cpi),
    ln_ipi = log(ipi),
    ln_neer = log(neer),
    post_crisis = ifelse(date >= as.Date("2026-03-01"), 1, 0),
    country_group = "Advanced_NetImporter",
    oil_balance = "importer"
  )


cat("  ✓ Derived variables created:\n")
cat("     - ln_cpi (log of CPI)\n")
cat("     - ln_ipi (log of IPI)\n")
cat("     - ln_neer (log of NEER)\n")
cat("     - oil_pct_change (monthly oil price change)\n")
cat("     - post_crisis (crisis dummy variable)\n\n")


# ============================================================================
# PART 7: ARIMA FORECASTING FOR APRIL-JUNE 2026
# ============================================================================


cat("STEP 6: ARIMA forecasting for April-June 2026...\n\n")


# Function to fit ARIMA and forecast
forecast_arima <- function(hist_data, horizon = 3) {
  hist_data <- hist_data[!is.na(hist_data)]
  if(length(hist_data) < 12) {
    return(rep(tail(hist_data, 1), horizon))
  }
  ts_data <- ts(hist_data, frequency = 12, start = c(2023, 1))
  fit <- auto.arima(ts_data, seasonal = TRUE, stepwise = TRUE)
  return(as.numeric(forecast(fit, h = horizon)$mean))
}


forecast_dates <- seq(as.Date("2026-04-01"), as.Date("2026-06-30"), by = "month")


# 7.1 Forecast Brent oil
cat("  Forecasting Brent oil...")
brent_hist <- master_panel$brent[1:length(dates)]
brent_forecast <- forecast_arima(brent_hist)
brent_full <- c(brent_hist, brent_forecast)
cat(" done\n")


# 7.2 Calculate forecast oil changes
oil_forecast <- c(
  (brent_forecast[1] - tail(brent_hist, 1)) / tail(brent_hist, 1) * 100,
  (brent_forecast[2] - brent_forecast[1]) / brent_forecast[1] * 100,
  (brent_forecast[3] - brent_forecast[2]) / brent_forecast[2] * 100
)


# 7.3 Forecast VIX
cat("  Forecasting VIX...")
vix_hist <- master_panel$vix[1:length(dates)]
vix_forecast <- forecast_arima(vix_hist)
vix_full <- c(vix_hist, vix_forecast)
cat(" done\n")


# 7.4 Forecast policy rate
cat("  Forecasting policy rate...")
policy_hist <- master_panel$policy_rate[1:length(dates)]
policy_forecast <- forecast_arima(policy_hist)
policy_full <- c(policy_hist, policy_forecast)
cat(" done\n")


# 7.5 Create forecast panel
forecast_list <- list()
for(cnt in countries) {
  hist_data <- master_panel %>% filter(country == cnt)
  
  cpi_forecast <- forecast_arima(hist_data$cpi)
  ipi_forecast <- forecast_arima(hist_data$ipi)
  neer_forecast <- forecast_arima(hist_data$neer)
  
  forecast_list[[cnt]] <- data.frame(
    country = cnt,
    date = forecast_dates,
    cpi = cpi_forecast,
    ipi = ipi_forecast,
    policy_rate = policy_forecast,
    neer = neer_forecast,
    brent = brent_forecast,
    vix = vix_forecast,
    oil_pct_change = oil_forecast
  )
}
panel_forecast <- bind_rows(forecast_list)


cat("\n  ✓ Forecast panel created\n")


# ============================================================================
# PART 8: COMBINE HISTORICAL AND FORECAST
# ============================================================================


cat("\nSTEP 7: Combining historical and forecast panels...\n\n")


# Add derived variables to forecast panel
panel_forecast <- panel_forecast %>%
  mutate(
    ln_cpi = log(cpi),
    ln_ipi = log(ipi),
    ln_neer = log(neer),
    post_crisis = 1,
    country_group = "Advanced_NetImporter",
    oil_balance = "importer"
  )


# Combine with historical data
final_panel <- bind_rows(master_panel, panel_forecast) %>%
  arrange(country, date)


cat(paste("  Final panel created: ", nrow(final_panel), " rows x ", ncol(final_panel), " columns\n"))
cat(paste("  Countries: ", paste(unique(final_panel$country), collapse=", "), "\n"))
cat(paste("  Date range: ", min(final_panel$date), " to ", max(final_panel$date), "\n"))
cat(paste("  Observations per country: ", nrow(final_panel) / 3, "\n"))


# ============================================================================
# PART 9: DATA QUALITY VERIFICATION
# ============================================================================


cat("\nSTEP 8: Data quality verification...\n\n")


# Check for missing values
missing_final <- sum(is.na(final_panel))
cat(paste("  Missing values in final panel: ", missing_final, "\n"))


if(missing_final == 0) {
  cat("  ✓ No missing values - dataset is complete!\n")
}


# Check oil price variation
oil_var <- var(final_panel$oil_pct_change, na.rm = TRUE)
cat(paste("  Oil price change variance: ", round(oil_var, 6), "\n"))


if(oil_var > 0) {
  cat("  ✓ oil_pct_change has variation - suitable for econometrics\n")
}


# Check panel balance
panel_balance <- final_panel %>%
  group_by(country) %>%
  summarise(n = n())
cat("\n  Observations per country:\n")
print(panel_balance)


# ============================================================================
# PART 10: EXPORT FINAL DATASET
# ============================================================================


cat("\nSTEP 9: Exporting final dataset...\n\n")


output_file <- "panel_data_econometrics.csv"
write.csv(final_panel, output_file, row.names = FALSE)
saveRDS(final_panel, "panel_data_econometrics.rds")


cat(paste("  ✓ Saved: ", output_file, "\n"))
cat(paste("  ✓ Saved: panel_data_econometrics.rds\n"))


# ============================================================================
# PART 11: FORECAST REPORT
# ============================================================================


forecast_report <- data.frame(
  Variable = c("Brent Oil (USD)", "VIX", "Policy Rate (%)",
               "Germany CPI", "France CPI", "Italy CPI",
               "Germany IPI", "France IPI", "Italy IPI"),
  Apr_2026 = c(
    round(brent_forecast[1], 2),
    round(vix_forecast[1], 1),
    round(policy_forecast[1], 2),
    round(forecast_list$Germany$cpi[1], 2),
    round(forecast_list$France$cpi[1], 2),
    round(forecast_list$Italy$cpi[1], 2),
    round(forecast_list$Germany$ipi[1], 2),
    round(forecast_list$France$ipi[1], 2),
    round(forecast_list$Italy$ipi[1], 2)
  ),
  May_2026 = c(
    round(brent_forecast[2], 2),
    round(vix_forecast[2], 1),
    round(policy_forecast[2], 2),
    round(forecast_list$Germany$cpi[2], 2),
    round(forecast_list$France$cpi[2], 2),
    round(forecast_list$Italy$cpi[2], 2),
    round(forecast_list$Germany$ipi[2], 2),
    round(forecast_list$France$ipi[2], 2),
    round(forecast_list$Italy$ipi[2], 2)
  ),
  Jun_2026 = c(
    round(brent_forecast[3], 2),
    round(vix_forecast[3], 1),
    round(policy_forecast[3], 2),
    round(forecast_list$Germany$cpi[3], 2),
    round(forecast_list$France$cpi[3], 2),
    round(forecast_list$Italy$cpi[3], 2),
    round(forecast_list$Germany$ipi[3], 2),
    round(forecast_list$France$ipi[3], 2),
    round(forecast_list$Italy$ipi[3], 2)
  )
)


write.csv(forecast_report, "forecasts/forecast_report.csv", row.names = FALSE)
cat("  ✓ Saved: forecasts/forecast_report.csv\n")


# ============================================================================
# PART 12: CREATE SUMMARY PLOTS
# ============================================================================


cat("\nSTEP 10: Creating summary plots...\n\n")


# Plot 1: Brent oil price over time
p1 <- ggplot(final_panel %>% distinct(date, brent), aes(x = date, y = brent)) +
  geom_line(color = "darkred", size = 1) +
  geom_vline(xintercept = as.Date("2026-02-27"), linetype = "dashed", color = "blue") +
  labs(title = "Brent Crude Oil Price", x = "Date", y = "USD per Barrel") +
  theme_minimal()
ggsave("figures/brent_oil_price.png", p1, width = 10, height = 6)
cat("  ✓ Saved: figures/brent_oil_price.png\n")


# Plot 2: CPI trends by country
p2 <- ggplot(final_panel, aes(x = date, y = ln_cpi, color = country)) +
  geom_line(size = 1) +
  geom_vline(xintercept = as.Date("2026-02-27"), linetype = "dashed", color = "gray40") +
  labs(title = "Log(CPI) Trends by Country", x = "Date", y = "Log(CPI)") +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave("figures/ln_cpi_by_country.png", p2, width = 10, height = 6)
cat("  ✓ Saved: figures/ln_cpi_by_country.png\n")


# Plot 3: Oil price shocks
p3 <- ggplot(final_panel %>% distinct(date, oil_pct_change), aes(x = date, y = oil_pct_change)) +
  geom_bar(stat = "identity", fill = "darkorange", alpha = 0.7) +
  geom_hline(yintercept = 0) +
  geom_vline(xintercept = as.Date("2026-02-27"), linetype = "dashed", color = "blue") +
  labs(title = "Oil Price Percentage Change", x = "Date", y = "% Change") +
  theme_minimal()
ggsave("figures/oil_price_shock.png", p3, width = 10, height = 6)
cat("  ✓ Saved: figures/oil_price_shock.png\n")


# ============================================================================
# PART 13: FINAL SUMMARY
# ============================================================================


cat("\n========================================\n")
cat("DATA PIPELINE COMPLETED SUCCESSFULLY\n")
cat("========================================\n\n")


cat("SUMMARY:\n")
cat(paste("  • Historical period: Jan 2023 - Mar 2026 (", length(dates), " months)\n"))
cat(paste("  • Forecast period: Apr 2026 - Jun 2026 (3 months)\n"))
cat(paste("  • Total observations: ", nrow(final_panel), "\n"))
cat(paste("  • Countries: 3 (Germany, France, Italy)\n"))
cat(paste("  • Variables: ", ncol(final_panel), "\n"))
cat(paste("  • Missing values: ", missing_final, "\n\n"))


cat("OUTPUT FILES:\n")
cat(paste("  • ", output_file, " - Main dataset for econometric analysis\n"))
cat("  • panel_data_econometrics.rds - R binary format\n")
cat("  • forecasts/forecast_report.csv - ARIMA forecast values\n")
cat("  • figures/ - Summary plots\n\n")


cat("KEY VARIABLES FOR ECONOMETRIC ANALYSIS:\n")
cat("  • ln_cpi - Log of CPI (dependent variable for inflation)\n")
cat("  • ln_ipi - Log of IPI (dependent variable for growth)\n")
cat("  • oil_pct_change - Oil price shock (main explanatory variable)\n")
cat("  • ln_neer - Log of NEER (control)\n")
cat("  • policy_rate - ECB policy rate (control)\n")
cat("  • vix - Volatility index (control)\n")
cat("  • post_crisis - Crisis dummy (structural break)\n\n")


cat("✅ Ready for econometric analysis!\n")


# ============================================================================
# END OF DATA PIPELINE SCRIPT
# ============================================================================