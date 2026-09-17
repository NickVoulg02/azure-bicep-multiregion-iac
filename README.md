# Azure Multi-Region Infrastructure Deployment via Bicep

## Overview

This repository serves as a practical implementation and reference guide for concepts learned in the Microsoft Learn Azure Bicep paths. It provisions a multi-region Azure environment featuring SQL databases, Virtual Networks, and an optional Node.js App Service.

## Architecture & Design Decisions

I deliberately avoided hardcoding single resources to practice advanced Bicep capabilities, specifically focusing on **Loops** and **Conditions**.

* **Multi-Region Databases:** Bicep concurrently deploys identical, globally unique SQL Servers and databases to all regions simultaneously without duplicating code.
* **Virtual Networks & Subnets:** The Virtual Networks are deployed alongside the databases in every specified region,`frontend` and `backend` subnets are also generated.
* **Conditional Deployments:** SQL auditing settings and their associated Storage Accounts are conditionally deployed when the deployment environment is set to `prod`.
* **Secure Parameters:** Administrator passwords are never hardcoded. The deployment relies on Azure Key Vault references within the parameter files to securely inject secrets at runtime.


## Deployment Guide

Deploying this project requires a two-step pipeline: provisioning the infrastructure via Bicep, and subsequently pushing the application code to the created App Service.

### Prerequisites

1. An active Azure Subscription.
2. Azure CLI installed and authenticated (`az login`).

### Phase 1: Infrastructure Provisioning

1. **Create a Resource Group:**
```bash
az group create --name <YOUR_RESOURCE_GROUP> --location centralus

```

2. **Create the Key Vault with Template Deployment Enabled**

```bash
az keyvault create \
  --name <YOUR_KEY_VAULT_NAME> \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --location centralus \
  --enabled-for-template-deployment true

```

3. **Set the SQL Administrator Password Secret**
*(Note: You must have the "Key Vault Secrets Officer" role assigned to your account to perform this action).*

```bash
az keyvault secret set \
  --vault-name <YOUR_KEY_VAULT_NAME> \
  --name "sqlAdminPassword" \
  --value "<YOUR_COMPLEX_PASSWORD>"

```

4. **Prepare Parameters:** Copy `infra/main.parameters.example.json` to a new file (e.g., `main.parameters.dev.json`). Update the Key Vault reference to point to your specific Azure Subscription and Key Vault ID.
<br>

5. **Deploy the Bicep Template:**
```bash
az deployment group create \
  --name multi-region-deploy \
  --resource-group ToyAppResourceGroup \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.dev.json

```



### Phase 2: Application Code Deployment

Once the infrastructure finishes deploying, push the Node.js application to the newly created App Service:

1. Zip the contents of the `src/` directory:
```bash
cd src
zip -r app.zip ./*

```


2. Deploy the zip file to the App Service:
```bash
az webapp deployment source config-zip \
  --resource-group ToyAppResourceGroup \
  --name <DEPLOYED_APP_SERVICE_NAME> \
  --src app.zip

```



## Developer Notes & Troubleshooting

I deployed on an Azure Free Trial subscription and encountered `SubscriptionIsOverQuotaForSku` errors for `B1` or `F1` App Service plans. Microsoft strictly limits these compute instances globally on trial accounts. 
Stepping away and letting the backend rate limits and quota blocks cool off for a few days is how I handled the Azure Free Trial constraints.



