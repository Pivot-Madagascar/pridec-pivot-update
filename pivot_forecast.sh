#!/bin/bash
set -e

#to run:
# . pivot_workflow.sh <your-disease-code>
# . ./pivot_workflow.sh "pridec_historic_CSBMalaria"

# to run with a faster test configuration, provide test as second argument
# . ./pivot_workflow.sh "pridec_historic_CSBMalaria" test


# copy all of the forecast_assets over to here first, keeping them in the forecast_assets/ directory
# you need a .env file at root with:
# DHIS_URL="http://localhost:8082/"
# DHIS_TOKEN="d2pat_odhYW86O8auDuQ73u4r3HElEJxMFQziM3326734980"
# PARENT_OU="VtP4BdCeXIo"

source .env

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disease_code>"
    exit 1
fi

DISEASE_CODE="$1"

#check that jq is installed, it is not by default on some distros
if ! command -v jq &> /dev/null; then
    echo "Error: The 'jq' package is not installed. Please install it before continuing."
    exit 1
fi

if  ! command -v docker compose &> /dev/null; then
    echo "Error: Docker Compose v2 is not installed. Please install it before continuing."
    exit 1
fi

if ! command -v pridec &> /dev/null; then
    echo -e "Error: 'pridec' docker service not found. Please ensure it is installed and available in your PATH.\nSee instructions here: https://github.com/Pivot-Madagascar/pridec-docker"
    exit 1
fi



#takes argument for disease code, then forecasts it, waits for validation, and posts

echo "Starting forecast workflow for $DISEASE_CODE on $DHIS_URL"


#------------copy over needed files-----------------------#
[ -d "output" ] && rm -rf "output"
[ -d "input" ] && rm -rf "input"
mkdir input
mkdir output

if [[ "$DISEASE_CODE" == *Malaria ]]; then
    cp forecast_assets/config_malaria.json input/config.json
elif [[ "$DISEASE_CODE" == *Diarrhea ]]; then
    cp forecast_assets/config_diarrhea.json input/config.json
elif [[ "$DISEASE_CODE" == *Respinf ]]; then
    cp forecast_assets/config_respiratory.json input/config.json
else
    echo "Unknown disease type: $DISEASE_CODE"
    exit 1
fi

#only run naive and rf models for tests
if [[ "$2" = "test" ]]; then
    cp forecast_assets/test_config.json input/config.json
fi

#automatically update the forecast_start, unless it is a test
if [[ "$2" = "test" ]]; then
    forecast_start="202601"
else
    forecast_start=$(date -d "$(date +%Y-%m-01)" +%Y%m)
fi

jq --arg fs "$forecast_start" '.forecast_start = $fs' input/config.json > config.tmp && mv config.tmp input/config.json


if [[ "$DISEASE_CODE" == *ADJ* ]]; then
    cp forecast_assets/external_data_fkt.csv input/external_data.csv
    OU_LEVEL="6"
elif [[ "$DISEASE_CODE" == *COM* ]]; then
    cp forecast_assets/external_data_fkt.csv input/external_data.csv
    OU_LEVEL="6"
elif [[ "$DISEASE_CODE" == *CSB* ]]; then
    cp forecast_assets/external_data_csb.csv input/external_data.csv
    OU_LEVEL="5"
else
    echo "Unknown data source: $DISEASE_CODE"
    exit 1
fi

#-------start docker workflow---------------------#
ENV_ARGS=(-e DISEASE_CODE="$DISEASE_CODE" -e OU_LEVEL="$OU_LEVEL")

pridec etl fetch_disease "${ENV_ARGS[@]}"
pridec etl fetch_climate "${ENV_ARGS[@]}"
pridec etl fetch_geojson "${ENV_ARGS[@]}"
pridec etl validate_inputs "${ENV_ARGS[@]}"
pridec forecast forecast "${ENV_ARGS[@]}"

#create alert forecasts for CSBs only
if [[ "$DISEASE_CODE" == *CSB* ]]; then

    if [[ "$DISEASE_CODE" == *Malaria ]]; then
        ALERT_NAME="CSBMalariaVigilance"
    elif [[ "$DISEASE_CODE" == *Diarrhea ]]; then
        ALERT_NAME="CSBDiarrheaVigilance"
    elif [[ "$DISEASE_CODE" == *Respinf ]]; then
        ALERT_NAME="CSBRespinfVigilance"
    fi

    pridec etl calc_orgUnit_alerts -e DISEASE_CODE="$DISEASE_CODE" -e OU_LEVEL="$OU_LEVEL" -e ALERT_NAME="$ALERT_NAME"
fi

#pause and wait for user to inspect report
#I need to add something to skip this in an automated workflow in the future

if [[ "$2" = "test" ]]; then 
    echo "This is a test run and will use a dryRun POST to an instance. Rerun without the 'test' flag to POST and actually change data."
fi

echo -e "\nOpen output/forecast_report.html in a browser and inspect the output.\nDo you want to POST these forecasts to DHIS2 instance $DHIS_URL? (y/n):"
read -r answer

if [[ "$answer" == "y" ]]; then
    echo "Continuing to POST data to instance."
elif [[ "$answer" == "n" ]]; then
    echo "Exiting..."
    exit 0
else
    echo "Invalid input. Please answer 'y' or 'n'."
    exit 1
fi



if [[ "$2" = "test" ]]; then
    pridec etl post_forecast -e DRYRUN=true
else 
    pridec etl post_forecast -e DRYRUN=false
fi

echo "SUCCESS: updated forecasts for $DISEASE_CODE on $DHIS_URL"