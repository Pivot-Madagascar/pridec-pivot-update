# Pivot-specific PRIDE-C Monthly Update Workflow

This contains the workflow needed to run the monthly updates on Pivot's PRIDE-C instance.

It relies on the [PRIDE-C R Package](https://github.com/Pivot-Madagascar/PRIDEC-package) and the [PRIDEC Docker workflow](https://github.com/Pivot-Madagascar/pridec-docker)

## Requirements

The PRIDEC docker app must be installed via the automated `install.sh` script following instructions in the [pride-docker repo](https://github.com/Pivot-Madagascar/pridec-docker).

This currently only works on Linux systems using `bash`.

The PRIDEC docker app requires Docker Compose v2 and works best when it is installed via the Docker engine and not docker desktop. You can find the official installation instructions [here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).

This workflow also requires the `jq` package to update json files. It can be installed via:

```
sudo apt install jq
```

### Set up `.env` & `.gee-private-key.json`

This requires a `.env` file in the project root directory with the following structure:

```
DHIS2_PRIDEC_URL="http://44.218.51.103:8080/"
DHIS2_TOKEN="your-pridec-dhis2-token"
PARENT_OU="VtP4BdCeXIo"

GEE_SERVICE_ACCOUNT='your-service-account@project.iam.gserviceaccount.com'

PIVOT_URL="https://www.dhis2-pivot.org/prod/"
PIVOT_TOKEN="your-pivot-dhis2-token"
```

In order to use the `import-gee` service, you must also have the private key that corresponds to the `GEE_SERVICE_ACCOUNT` in the project root directory. See the [guide for creating GEE service accounts](https://developers.google.com/earth-engine/guides/service_account).

## Usage

The workflow can be seperated into two steps:

1. Importation of data into PRIDE-C instance [once per month, before forecasting]
2. Creation of forecasts and importation into PRIDE-C instance [one for each dataElement]
3. Launching of Analytics Table and update of dataStore key [once per month, after forecasting]

The first and third step only needs to be done once per month, while the forecast creation step needs to be done for each our nine dataElements that we predict over. The dataElements that we predict are:

| DISEASE_CODE                | Name                                             |
|-----------------------------|--------------------------------------------------|
| pridec_historic_CSBMalaria  | PRIDEC : HISTORIC CSB Reported Cases  - Malaria  |
| pridec_historic_CSBDiarrhea | PRIDEC : HISTORIC CSB Reported Cases  - Diarrhea |
| pridec_historic_CSBRespinf  | PRIDEC : HISTORIC CSB Reported Cases  - Resp Inf |
| pridec_historic_ADJMalaria  | PRIDEC : HISTORIC Adjusted Case Rate  - Malaria  |
| pridec_historic_ADJDiarrhea | PRIDEC : HISTORIC Adjusted Case Rate  - Diarrhea |
| pridec_historic_ADJRespinf  | PRIDEC : HISTORIC Adjusted Case Rate  - Resp Inf |
| pridec_historic_COMMalaria  | PRIDEC : HISTORIC COM Reported Cases  - Malaria  |
| pridec_historic_COMDiarrhea | PRIDEC : HISTORIC COM Reported Cases  - Diarrhea |
| pridec_historic_COMRespinf  | PRIDEC : HISTORIC COM Reported Cases  - Resp Inf |

Each step corresponds to a docker `service`. They all have the capability of running in `DRYRUN` mode for testing purposes. In the code below, `DRYRUN` is always set to `true`. Once you are sure everything works, you can set `DRYRUN=false` to actually import data into the instance.

### 1. Importation step

This step imports health data from Pivot's DHIS2 instance into the PRIDE-C instance and imports climate data from GEE into the PRIDE-C instance. Note that you must have the neccessary tokens for both DHIS2 instances and your GEE service account for this to work.


**Import GEE Climate data**

This imports 10 environmental variables from GEE into the PRIDE-C DHIS2 instance. While most indicators are quite quick (<1 minute), the Sen-1 flooding incidcator can take between 30-45 minutes.

```
pridec run --env-from-file .env --env DRYRUN="true" --rm import-gee
```

**Import historical health data**

We also import historical health data from the Pivot DHIS2 instance into the PRIDE-C instance to create the dataElements that we want to forecast. This includes some formatting and aggregation of multiple dataElement to create each `pridec_historic_` dataElement. It needs to be run twice, once for the community case data (`COMcases`) and once for the CSB-level case data (`CSBcases`).

```
pridec run --env-from-file .env --env DRYRUN=true --rm import-pivot-data COMcases.py
pridec run --env-from-file .env --env DRYRUN=true --rm import-pivot-data CSBcases.py
```

**Launch Analytics Table**

In order for this new data to be accessible via the `analytics` endpoint, the Analytics Table must be rebuilt. 

```
pridec run --env-from-file .env --env DRYRUN=true --rm post analytics.py
```

This will take ~15 minutes. You can check the progress by going to the URL mentioned in the output. This step can also be done manually via the DHIS2 user interface.

### 2. Forecast Step


The primary script used to forecast is the `pivot_forecast.sh` script. This ensures the correct configuration and data is used for each dataElement. It is simply looped over the 9 dataElements that we forecast on the Pivot PRIDE-C instance.


Based on the DISEASE_CODE provided to `pivot_forecast.sh`, it will automatically fetch the data and create a forecast. The CLI will then pause while you can inspect the forecast report (`output/forecast_report.html`) to ensure everything looks okay before you POST the forecasts to the DHIS2 instance.


#### Forecast one dataElement

To forecast one dataElement you can run `pivot_forecast.sh` directly. 

To run a test, which will just use two simple models that take less than 10 seconds to run. This will not POST to the instance.

```
. ./pivot_forecast.sh "pridec_historic_CSBMalaria" test
```

To run using an actual configuration file, remove the test argument:

```
. ./pivot_forecast.sh "pridec_historic_CSBMalaria"
```

#### Forecast all nine dataElements

I prefer to forecsat each dataElement one by one so that the process can be more easily monitored. They are in order of fastest to slowest model building. They should be run line by line. You can append the `test` argument if you want to test the dataElement.

This needs to be run in the Terminal to start the shell script:

```
# 3-5 minutes per data source
. ./pivot_forecast.sh "pridec_historic_CSBMalaria"
. ./pivot_forecast.sh "pridec_historic_CSBDiarrhea"
. ./pivot_forecast.sh "pridec_historic_CSBRespinf"


# 5-10 minutes per data source
. ./pivot_forecast.sh "pridec_historic_COMMalaria"
. ./pivot_forecast.sh "pridec_historic_COMDiarrhea"
. ./pivot_forecast.sh "pridec_historic_COMRespinf"

# 10-20 minutes per data source
. ./pivot_forecast.sh "pridec_historic_ADJMalaria"
. ./pivot_forecast.sh "pridec_historic_ADJDiarrhea"
. ./pivot_forecast.sh "pridec_historic_ADJRespinf"
```

#### 3. Analytics Update

Once all forecasts have been created and POSTed to the instance, the Analytics Tables can be built one more time and the pridec dataStore update key updated. This is needed to signal to the app that the forecasts have been updated and that user's cache should be refreshed.

```
pridec run --env-from-file .env --env DRYRUN=true --rm post analytics.py
pridec run --env-from-file .env --env DRYRUN=true --rm post dataStoreKey.py
```