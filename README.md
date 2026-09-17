# Azure Multi-Region Infrastructure Deployment via Bicep

## Overview

This repository serves as a practical implementation and reference guide for concepts learned in the Microsoft Learn Azure Bicep paths. It provisions a multi-region Azure environment featuring SQL databases, Virtual Networks, and an optional Node.js App Service, demonstrating how to use Infrastructure as Code (IaC) to build scalable, repeatable, and secure cloud environments.

## Architecture & Design Decisions

This project deliberately avoids hardcoding single resources to practice advanced Bicep capabilities, specifically focusing on **Loops** and **Conditions**.

* **Module Loops (Multi-Region Databases):** The `database.bicep` module is wrapped in a `[for location in locations: {}]` loop within `main.bicep`. By passing an array of Azure regions (`westus3`, `centralus`), Bicep concurrently deploys identical, globally unique SQL Servers and databases to all regions simultaneously without duplicating code.
* **Resource Loops (Virtual Networks & Subnets):** The Virtual Networks use a resource loop to deploy alongside the databases in every specified region. Furthermore, it uses a nested property loop to dynamically generate `frontend` and `backend` subnets by iterating over a variable array (`var subnets = [...]`).
* **Conditional Deployments:** SQL auditing settings and their associated Storage Accounts are conditionally deployed using the `if (auditingEnabled)` syntax. They are only provisioned when the deployment environment is set to `prod`.
* **Secure Parameters:** Administrator passwords are never hardcoded. The deployment relies on Azure Key Vault references within the parameter files to securely inject secrets at runtime.

## Repository Structure

```text
toyhr-deployment-project/
├── docs/
│   └── architecture.md
├── infra/
│   ├── modules/
│   │   ├── appService.bicep
│   │   └── database.bicep
│   ├── main.bicep
│   └── main.parameters.example.json
├── src/
│   └── index.js
└── README.md

```

## Deployment Guide

Deploying this project requires a two-step pipeline: provisioning the infrastructure via Bicep, and subsequently pushing the application code to the created App Service.

### Prerequisites

1. An active Azure Subscription.
2. Azure CLI installed and authenticated (`az login`).
3. A configured Azure Key Vault containing a secret named `sqlAdminPassword`.

### Phase 1: Infrastructure Provisioning

1. **Prepare Parameters:** Copy `infra/main.parameters.example.json` to a new file (e.g., `main.parameters.dev.json`). Update the Key Vault reference to point to your specific Azure Subscription and Key Vault ID.
2. **Create a Resource Group:**
```bash
az group create --name ToyAppResourceGroup --location centralus

```


3. **Deploy the Bicep Template:**
```bash
az deployment group create \
  --name multi-region-deploy \
  --resource-group ToyAppResourceGroup \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.dev.json

```



### Phase 2: Application Code Deployment

*Note: Ensure the `appService` module is uncommented in `main.bicep` for this step.*
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

**Azure Free Trial Quotas:** If deploying on an Azure Free Trial subscription, you may encounter `SubscriptionIsOverQuotaForSku` errors for `B1` or `F1` App Service plans. Microsoft strictly limits these compute instances globally on trial accounts.

* **Workaround:** The `appService` module is commented out by default in `main.bicep`. Leaving it commented allows you to successfully provision the databases, virtual networks, and storage accounts to test the Bicep loop and condition logic without hitting trial compute limits.


Stepping away and letting the backend rate limits and quota blocks cool off for a few days is exactly how seasoned cloud engineers handle Azure Free Trial constraints.

To ensure anyone cloning your repository doesn't hit the same `Forbidden` and `BadRequest` Key Vault errors you ran into, you can replace the placeholder Key Vault section in your `README.md` with this detailed explanation.

### Security Pre-requisites: Azure Key Vault Setup

This infrastructure relies on Azure Key Vault to securely inject the SQL Server administrator password at deployment time, ensuring credentials are never hardcoded in the parameter files.

For Azure Resource Manager (ARM) to successfully retrieve the secret during the deployment process, the Key Vault must have the `enabledForTemplateDeployment` property set to true. Additionally, if your Key Vault has network firewall rules applied, you must explicitly allow trusted Microsoft services to bypass the firewall so ARM can reach the data plane.

Run the following commands to provision and configure your Key Vault correctly before initiating the Bicep deployment:

**1. Create the Key Vault with Template Deployment Enabled**

```bash
az keyvault create \
  --name <YOUR_KEY_VAULT_NAME> \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --location centralus \
  --enabled-for-template-deployment true

```

**2. Update Firewall Bypass (If network ACLs are active)**
If you apply network restrictions to your vault, you must allow Azure services to bypass them to maintain deployment access:

```bash
az keyvault update \
  --name <YOUR_KEY_VAULT_NAME> \
  --bypass AzureServices \
  --enabled-for-template-deployment true

```

**3. Set the SQL Administrator Password Secret**
*(Note: You must have the "Key Vault Secrets Officer" role assigned to your account to perform this action).*

```bash
az keyvault secret set \
  --vault-name <YOUR_KEY_VAULT_NAME> \
  --name "sqlAdminPassword" \
  --value "<YOUR_COMPLEX_PASSWORD>"

```

Once the vault is configured and the secret is set, copy the vault's Resource ID and paste it into the `main.parameters.dev.json` file.