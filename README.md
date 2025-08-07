# Pivot-specific PRIDE-C Monthly Update Workflow

This contains the workflow needed to run the monthly updates on Pivot's PRIDE-C instance.

It relies on the [PRIDE-C R Package](https://github.com/Pivot-Madagascar/PRIDEC-package) and the [PRIDEC Docker workflow](https://github.com/Pivot-Madagascar/pridec-docker)

## Requirements

The PRIDEC docker app must be installed via the automated `install.sh` script following instructions in the [pride-docker repo](https://github.com/Pivot-Madagascar/pridec-docker).

This currently only works on Linux systems using `bash`.

### Set up `.env`

This requires a `.env` file in the root directory with the following structure:

```
DHIS2_PRIDEC_URL="http://44.218.51.103:8080/"
DHIS2_TOKEN="your-dhis-token"
PARENT_OU="VtP4BdCeXIo"
```


## Usage

The primary script used in this workflow is the `pivot_workflow.sh` script. It is simply looped over the 9 dataElements that we forecast on the Pivot PRIDE-C instance.

The dataElements are as follows:

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

Based on the DISEASE_CODE provided to `pivot_workflow.sh`, it will automatically fetch the data and create a forecast. The CLI will then pause while you can inspect the forecast report to ensure everything looks okay before you POST the forecasts to the DHIS2 instance.


### Forecast one dataElement

To forecast one dataElement you can run `pivot_workflow.sh` directly. 

To run a test, which will just use two simple models that take less than 10 seconds to run. This will not POST to the instance.

```
. ./pivot_workflow.sh "pridec_historic_CSBMalaria" test
```

To run using an actual configuration file, remove the test argument:

```
. ./pivot_workflow.sh "pridec_historic_CSBMalaria"
```

### Forecast all nine dataElements

1. Update climate data on DHIS2 instance using `gee-pridec` python package

- add link on how to install (it isn't a proper package yet)
- running this based on .env file

2. Forecast each dataElement 

While this could be all put into one script, I prefer to do it one by one so that the process can be more easily monitored. They are in order of fastest to slowest model building. They should be run line by line. You can append the `test` argument if you want to test the dataElement.

```
#5-10 minutes per data source
. ./pivot_workflow.sh "pridec_historic_CSBMalaria"
. ./pivot_workflow.sh "pridec_historic_CSBDiarrhea"
. ./pivot_workflow.sh "pridec_historic_CSBRespinf"


# 10-0 minutes per data source
. ./pivot_workflow.sh "pridec_historic_COMMalaria"
. ./pivot_workflow.sh "pridec_historic_COMDiarrhea"
. ./pivot_workflow.sh "pridec_historic_COMRespinf"

#15-30 minutes per data source
. ./pivot_workflow.sh "pridec_historic_ADJMalaria"
. ./pivot_workflow.sh "pridec_historic_ADJDiarrhea"
. ./pivot_workflow.sh "pridec_historic_ADJRespinf"
```


Started at 12:50