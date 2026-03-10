# Debug PRIDE-C Intermediate Data
# Project:
# Authors:

# Michelle V Evans
# Github: mvevans89
# Email: mv.evans.phd@gmail.com

# Script originated Feb 2026

# Description of script and instructions ###############

#' This script contains scratch to help investigate intermediate PRIDE-C data when
#' it shows up with an error in the HTML report.

# Packages and Options ###############################

options(stringsAsFactors = FALSE, scipen = 999)

#plotting
library(ggplot2); theme_set(theme_bw())

library(jsonlite)
library(skimr)

library(dplyr)

# Climate Data #########################################

climate_file <- "/home/mevans/Dropbox/PIVOT/pride-c/appDev/pridec-pivot-update/input/climate_data.json"

climate_data <- fromJSON(climate_file)$dataValues

filter(climate_data, period == "202601")

range(climate_data$period)
skim(climate_data)

unique(climate_data$dataElement)

mndwi <- filter(climate_data, dataElement == "pridec_climate_mndwi") |>
  mutate(date = as.Date(paste(period, "01"), format = "%Y%m%d"))

mndwi |>
  filter(orgUnit %in% sample(unique(orgUnit),2)) |>
  ggplot(aes(y = value, x = date, color = orgUnit)) +
  geom_line()

range(mndwi$date)
table(mndwi$date)

# Model Input data ###############################

input_data <- readRDS("/home/mevans/Dropbox/PIVOT/pride-c/appDev/pridec-pivot-update/output/input_data.RData")


# Forecasts ########################################

forecast_file <- "/home/mevans/Dropbox/PIVOT/pride-c/appDev/pridec-pivot-update/output/forecast.json"

forecast <- fromJSON(forecast_file)$dataValues

apr_2026 <- filter(forecast, period == "202604")
