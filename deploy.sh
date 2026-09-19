#!/bin/bash

set -e

RESOURCE_GROUP="ToyAppResourceGroup"
LOCATION="centralus"
KEY_VAULT_NAME="<YOUR_KEY_VAULT_NAME>"
SQL_ADMIN_PASSWORD="<YOUR_COMPLEX_PASSWORD>"
DEPLOYMENT_NAME="multi-region-deploy"
APP_SERVICE_NAME="<DEPLOYED_APP_SERVICE_NAME>"

echo "Infrastructure Provisioning..."

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enabled-for-template-deployment true

# Set the SQL Administrator Password Secret
# You must have the "Key Vault Secrets Officer" role assigned to your account to perform this action.
read -p "Do you have the 'Key Vault Secrets Officer' role assigned to your account? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Please assign the 'Key Vault Secrets Officer' role to your account and run the script again."
    exit 1
fi

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "sqlAdminPassword" \
  --value "$SQL_ADMIN_PASSWORD"


#  Ensure you have copied infra/main.parameters.example.json to infra/main.parameters.dev.json 
read -p "Have you updated main.parameters.dev.json with the new Key Vault ID? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Please update the parameter file and run the script again."
    exit 1
fi

az deployment group create \
  --name $DEPLOYMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.dev.json

echo "Infrastructure provisioned successfully."
echo "Application Code Deployment..."

# Zip the contents of the src/ directory
cd src
zip -r app.zip ./*

# Deploy the zip file to the App Service
az webapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME \
  --src app.zip

echo "Deployment complete!"