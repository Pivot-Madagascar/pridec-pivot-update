#!/bin/bash

#to run:
# . pivot_workflow.sh <your-disease-code>
# . ./pivot_workflow.sh "pridec_historic_CSBMalaria"

# to run with a faster test configuration, provide test as second argument
# . ./pivot_workflow.sh "pridec_historic_CSBMalaria" test


# copy all of the forecast_assets over to here first, keeping them in the forecast_assets/ directory
# you need a .env file at root with:
# DHIS2_PRIDEC_URL="http://localhost:8082/"
# DHIS2_TOKEN="d2pat_odhYW86O8auDuQ73u4r3HElEJxMFQziM3326734980"
# PARENT_OU="VtP4BdCeXIo"

source .env

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disease_code>"
    exit 1
fi

DISEASE_CODE="$1"

#takes argument for disease code, then forecasts it, waits for validation, and posts

echo "💻 Starting forecast workflow for $DISEASE_CODE on $DHIS2_PRIDEC_URL"


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

#this is just for running tests
if [[ "$2" = "test" ]]; then
    cp forecast_assets/test_config.json input/config.json
fi

if [[ "$DISEASE_CODE" == *ADJ* ]]; then
    cp forecast_assets/external_data_fkt.csv input/external_data.csv
elif [[ "$DISEASE_CODE" == *COM* ]]; then
    cp forecast_assets/external_data_fkt.csv input/external_data.csv
elif [[ "$DISEASE_CODE" == *CSB* ]]; then
    cp forecast_assets/external_data_csb.csv input/external_data.csv
else
    echo "Unknown data source: $DISEASE_CODE"
    exit 1
fi

#-------start docker workflow---------------------#
pridec run --env-from-file .env --env DISEASE_CODE="$DISEASE_CODE" --rm fetch
pridec run --env-from-file .env --rm forecast --config "input/config.json"

#pause and wait for user to inspect report
#I need to add something to skip this in an automated workflow in the future

echo -n "\nOpen output/forecast_report.html in a browser and inspect the output.\nDo you want to POST these forecasts to host $DHIS2_PRIDEC_URL? (y/n):"
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

pridec run --env-from-file .env --env DRYRUN=false --rm post

pridec down --remove-orphans

echo "✅ SUCCESS: updated forecasts for $DISEASE_CODE on $DHIS2_PRIDEC_URL"