#!/bin/bash

# The script is quite simple, it sets up the environment variables, clones the two repositories, deploys the CloudSQL instance and the associated service accounts, and then deploys the helm chart. 
# The helm chart is deployed with the following values: 
# envFrontend.serviceAccountEmail=$SA_EMAIL envFrontend.serviceUrl=$SVC_URL envRetrieval.dbRegion=$DB_REGION envRetrieval.dbInstance=$DB_INSTANCE dbPassword=$DB_PASSWORD DB_USER=$DB_USER envUniversal.googleProject=$GOOGLE_PROJECT 
# The script is quite simple, but it does the job. 
# The script can be run with the following command: 
# bash setup.sh

#Set up environment variables for the deployment
export GOOGLE_PROJECT=<Your GCP Project>
export TEAM_NAME=<Your Team Name>
export DB_INSTANCE=genai-rag-db-$(echo $TEAM_NAME)
export SA_EMAIL=$(echo $DB_INSTANCE)@$(echo $GOOGLE_PROJECT).iam.gserviceaccount.com
export SVC_URL="http://rag-$(echo $TEAM_NAME)-genai-retrieval-augmented-generation-retrieval.$(echo $TEAM_NAME).svc.cluster.local"
export DB_REGION=europe-west2 #Can be changed if needed
export DB_USER=retrieval-service
export DB_PASSWORD=your-database-password

#Set up a local working folder
mkdir github
cd github
git clone git@github.com:rh-uki-openshift-ssa/genai-retrieval-augmented-generation.git
git clone git@github.com:rh-uki-openshift-ssa/genai-retrieval-augmented-generation-terraform.git


#Deploy CloudSQL and associated service accounts
cd genai-retrieval-augmented-generation-terraform
terraform init
#yolo :-)
terraform apply -var project_id="$(echo $GOOGLE_PROJECT)" -var instance_name="$(echo $DB_INSTANCE)" -var database_name="assistantdemo" -var database_password="$(echo $DB_PASSWORD)" -var database_user="$(echo $DB_USER)" -var sa_teamname="$(echo $TEAM_NAME)"

#Prepare the 'files' folder for the helm chart ready for the sa_key
mkdir -p ../genai-retrieval-augmented-generation/genai-retrieval-augmented-generation/files
terraform output -raw sa_key | base64 -d > ../genai-retrieval-augmented-generation/genai-retrieval-augmented-generation/files/service-account.json


cd ../genai-retrieval-augmented-generation

oc new-project $(echo $TEAM_NAME) #Create a new project for the team
oc project $(echo $TEAM_NAME) #Switch to the new project. And if the above fails, switch to the project if it already exists

#We're getting lazy - remove helm chart if pre-existing, will error if it doesn't but that doesn't matter, helps if we need
#to re-run the script
helm uninstall rag-$(echo $TEAM_NAME)

#Deploy the helm chart
helm install rag-$(echo $TEAM_NAME) genai-retrieval-augmented-generation/ -f genai-retrieval-augmented-generation/values.yaml --set envFrontend.serviceAccountEmail=$SA_EMAIL \
--set envFrontend.serviceUrl=$SVC_URL --set envRetrieval.dbRegion=$DB_REGION \
--set envRetrieval.dbInstance=$DB_INSTANCE --set dbPassword=$DB_PASSWORD \
--set DB_USER=$DB_USER --set envUniversal.googleProject=$GOOGLE_PROJECT


#clean up
cd ../
rm -Rf github/
 
