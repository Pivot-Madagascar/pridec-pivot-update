# Comment faire des mise à jours PRIDE-C
### Mise à jour: 14 Mai 2026

# PAS ENCORE A JOUR AVEC LE NOUVEAU WORKFLOW

## Pre-requis

- pridec-docker installé sur le serveur à Ranomafana avec l'installation automatique (voir [ici](https://docs.google.com/document/d/1DAk7sy8jt8oDqzWNBD6TDdCRDpk3PkgdMzk1qVI9je0/edit?usp=sharing))

Tous les commandes sont lancés depuis un terminal `bash`.

Verifier avec:

```
which pridec
pridec --help
pridec etl --help
pridec forecast --help
```

## Set-Up

Le suivant est déjà fait sur le serveur à Ranomafana.

1. Clone de `pridec-pivot-update` (il se trouve dans pridec/pridec-pivot-update)
2. Création de fichier `.env` et `.gee-private-key.json` dans le projet root


## Workflow de mise à jour

### Connectez à le serveur à Ranomafana

Connecte via le VPN au serveur de Ranomafana. Naviguer vers `pridec/pridec-pivot-update`

Tous les étapes sont aussi documentés dans le [README du repo `pridec-pivot-update`](https://github.com/Pivot-Madagascar/pridec-pivot-update/blob/main/README.md), si tu as des questions.


### 1. Importation des données GEE

```
pridec etl import_gee -e DRYRUN='True'
pridec etl import_gee -e DRYRUN='FAlse'
```

Il va prendre 30 minutes, surtout l'importation de Sen-1 Flood Indicator qui est fait en dernier. Un DRYRUN est plus rapide et utilise un sous-selection des images (5 minutes totales).

2. Importation des données de santé Pivot

```
pridec etl import_pivot_com
pridec etl import_pivot_csb
```

Chaque importation va prendre 1-2 minutes. Il y aura des messages de verifications dans ton terminal. Verifier que le maximum nombre de cas pour COMcases soient moins de 100 et pour CSBcases, moins de 1000.

3. Build les tableaux d'analytiques

Après que tous les données soint importés, tu dois "build" les tableaux d'analytiques pour que ces données soint disponible:

```
pridec etl build_analytics
```

Tu dois attendre ~5 minutes pour que les tableaux sont fait avant que tu commence le prochain étape. Verifiez s'ils ont terminé en suivant le lien dans les messages dans le terminal.

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

Nous faisons les prédictions pour chaque `DISEASE_CODE` individuellement.


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

Pour finaliser la mise à jour, tu dois build encore les tableaux d'analytiques et mettre à jour le clé que nous utilisons pour relancer le cache de l'application PRIDE-C.Il faut attendre à chaque fois que tu fais un build des tableaux d'analytiques pour qu'il sont fait. Sinon, il y aura une erreur dans la cache.

```
pridec etl build_analytics #wait 10 minutes
pridec etl calc_CSB_alerts
pridec etl build_analytics #wait 10 minutes
pridec etl update_key
```

Comme toujours, le build des tableaux d'analytiques va prendre 10-15 minutes. Après ce temps, tu peux te connecter à [l'instance PRIDE-C](https://pridec.pivot-dashboard.org/) et verifier que l'application est à jour.