# Comment faire des mise à jours PRIDE-C
### Mise à jour: 13 Aout 2025

## Pre-requis

- [docker compose](https://docs.docker.com/compose/install/)
- OS Ubuntu 22+ (ça peut marcher sur un système Windows, mais il y a quelque scripts d'automation `.sh` qui sont fait pour Ubuntu)

Tous les commandes sont lancés depuis un terminal `bash`.

## Set-Up

### 1. Installer l'application docker `pridec-docker`

L'installation doit être fait une fois, mais je recommande que tu le refais pour être sur qu'il contient tous les mises à jour.

Voir le repo ici pour plus de détails: https://github.com/Pivot-Madagascar/pridec-docker

Tu peux l'installer n'importe ou sur ton ordinateur, il sera disponible via le $PATH.

```
git clone https://github.com/Pivot-Madagascar/pridec-docker.git
cd pridec-docker
```

Mettre à jour le chemin (`COMPOSE_DIR`) pour ce dossier sur ton ordinateur

```
pwd #pour trouver le chemin à ton dosier, doit inclut le pridec-docker à la fin

nano pridec #pour changer le chemin
```

Le fichier pridec doit ressemble celle-ci:

```
#!/bin/bash

COMPOSE_DIR="/path/to/pridec-docker" #update to be path to installed repo
HOST_PWD="$(pwd)"
HOST_PWD="$HOST_PWD" docker compose -f "$COMPOSE_DIR/compose-auto.yaml" "$@"
```

Lancer le script install. Le premier fois que tu le fais, il va prendre 15 minutes. Le prochaine fois, il va utiliser le cache docker pour être plus rapide

```
./install.sh
```

Si `$HOME/bin` n'est pas encore sur ta path, tu va recevoir un message qui dit ça. Tu l'ajouter à ton fichier `~/bashrc`:

```
nano ~/.bashrc
#ajouter le suivant à la fin du fichier
export PATH="/usr/bin:$PATH"
#enregistrer le changement
#re-initialiser bash pour que le PATH soit mise jour
source ~/.bashrc
#verifier si tu trouve pridec maintenant
which pridec
```

### 2. Création du dossier `pridec-pivot-update`

Tous les mises à jours sera lancer depuis le dossier `pridec-pivot-update`. Il peut être installer n'importe ou sur ta machine.

Installer depuis github:

```
git clone https://github.com/Pivot-Madagascar/pridec-pivot-update.git
```

Dans ce dossier, créer un ficher `.env`

```
nano .env
```

Il doit ressemble celle-ci:

```
#testing d2 docker-test
DHIS2_PRIDEC_URL="http://44.218.51.103:8080/"
DHIS2_TOKEN="your-pridec-dhis2-token"
PARENT_OU="VtP4BdCeXIo"

GEE_SERVICE_ACCOUNT='your-service-account@project.iam.gserviceaccount.com'

#only needed for import-pivot-data service
PIVOT_URL="https://www.dhis2-pivot.org/prod/"
PIVOT_TOKEN="your-pivot-dhis2-token"
```

Michelle va te donner tous les TOKEN secrets pour remplacer `DHIS2_TOKEN`, `GEE_SERVICE_ACCOUNT`, et `PIVOT_TOKEN`.

Elle va aussi te donner un fichier `.gee-private-key.json`. Tu doit mettre ce fichier dans le dossier `pridec-pivot-update`.

Créer les sous-dossiers `output` et `input`:

```
mkdir input
mkdir output
```

## Workflow de mise à jour

Tous les étapes sont documentés dans le [README du repo `pridec-pivot-update`](https://github.com/Pivot-Madagascar/pridec-pivot-update/blob/main/README.md), si tu as des questions.

Dans chaque étape, j'ai mis `DRYRUN=true` pour les testes. Quand on fait un `DRYRUN`, il n'aura pas de changements sur l'instance DHIS2. Après que tu as testé que tout marche bien, tu peux changer les commandes pour avoir `DRYRUN=false`.

Avant de commencer la mise à jour, il faut verifier que tout tes scripts sont à jour en effectuant un git pull dans le repo `pridec-docker` et `pridec-pivot-update`. S'il y a un changement des fichiers en `pridec-docker`, tu devrais relancer le script `install.sh`.

### 1. Importation des données GEE

```
pridec run --env-from-file .env --env DRYRUN="true" --rm import-gee
pridec run --env-from-file .env --env DRYRUN=false --rm import-gee
```

Il va prendre 30 minutes, surtout l'importation de Sen-1 Flood Indicator qui est fait en dernier. Un DRYRUN est plus rapide et utilise un sous-selection des images (5 minutes totales).

2. Importation des données de santé Pivot

```
pridec run --env-from-file .env --env DRYRUN=true --rm import-pivot-data COMcases.py
pridec run --env-from-file .env --env DRYRUN=true --rm import-pivot-data CSBcases.py

pridec run --env-from-file .env --env DRYRUN=false --rm import-pivot-data COMcases.py
pridec run --env-from-file .env --env DRYRUN=false --rm import-pivot-data CSBcases.py
```

Chaque importation va prendre 1-2 minutes. Il y aura des messages de verifications dans ton terminal. Verifier que le maximum nombre de cas pour COMcases soient moins de 100 et pour CSBcases, moins de 1000.

3. Build les tableaux d'analytiques

Après que tous les données soint importés, tu dois "build" les tableaux d'analytiques pour que ces données soint disponible:

```
pridec run --env-from-file .env --env DRYRUN=true --rm post analytics.py
pridec run --env-from-file .env --env DRYRUN=false --rm post analytics.py
```

### 2. Création des forecasts

Nous prédisons neuf combinaisons des maladies et sources de données: le palu, le diarrhée, l'IRA pour les sources de données communautaire, CSB, et cas ajustés.

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

Nous faisons les prédictions pour chaque `DISEASE_CODE` individuellement. Le flag `test` à la fin de chaque commande va faire une `DRYRUN`, enlever après que tu as fais des testes.

Tu doit changer les permission pour que le script `pivot_forecast.sh` soit executable:

```
chmod +x pivot_forecast.sh
```

```
# 3-5 minutes per data source
./pivot_forecast.sh "pridec_historic_CSBMalaria" test
./pivot_forecast.sh "pridec_historic_CSBDiarrhea" test
./pivot_forecast.sh "pridec_historic_CSBRespinf" test

./pivot_forecast.sh "pridec_historic_CSBMalaria" 
./pivot_forecast.sh "pridec_historic_CSBDiarrhea"
./pivot_forecast.sh "pridec_historic_CSBRespinf"

# 5-10 minutes per data source
./pivot_forecast.sh "pridec_historic_COMMalaria" test
./pivot_forecast.sh "pridec_historic_COMDiarrhea" test
./pivot_forecast.sh "pridec_historic_COMRespinf" test

./pivot_forecast.sh "pridec_historic_COMMalaria" 
./pivot_forecast.sh "pridec_historic_COMDiarrhea" 
./pivot_forecast.sh "pridec_historic_COMRespinf"

# 10-20 minutes per data source
./pivot_forecast.sh "pridec_historic_ADJMalaria" test
./pivot_forecast.sh "pridec_historic_ADJDiarrhea" test
./pivot_forecast.sh "pridec_historic_ADJRespinf" test

./pivot_forecast.sh "pridec_historic_ADJMalaria"
./pivot_forecast.sh "pridec_historic_ADJDiarrhea"
./pivot_forecast.sh "pridec_historic_ADJRespinf"
```

Après qu'une prédiction a été créer, le script va pauser pour te demander de revoir le report de forecast (`output/forecast_report.html`) avant d'injecter les données dans l'instance PRIDE-C. Si les forecasts sont valides, tu peux approuver l'importation avec `y`. S'il y a des erreurs dans les forecasts, tu peux rejeter l'importation avec `n`.

Si tu veux, tu peux copier chaque `forecast_report.html` en lui donnant un nom de DISEASE_CODE et les envoyer à Karen pour qu'elle puisse les valider avant d'approuver les importations des données.

### 3. Mise à jour du système

Pour finaliser la mise à jour, tu dois build encore les tableaux d'analytiques et mettre à jour le clé que nous utilisons pour relancer le cache de l'application PRIDE-C:

```
pridec run --env-from-file .env --env DRYRUN=true --rm post analytics.py
pridec run --env-from-file .env --env DRYRUN=true --rm post dataStoreKey.py

pridec run --env-from-file .env --env DRYRUN=false --rm post analytics.py
pridec run --env-from-file .env --env DRYRUN=false --rm post dataStoreKey.py
```

Comme toujours, le build des tableaux d'analytiques va prendre 10-15 minutes. Après ce temps, tu peux te connecter à [l'instance PRIDE-C](https://pridec.pivot-dashboard.org/) et verifier que l'application est à jour.