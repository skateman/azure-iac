#!/bin/bash

# Azure IaC Setup Script
# This script helps set up Azure authentication for GitHub Actions

set -e

echo "🚀 Azure IaC Setup Script"
echo "=========================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo "🔐 Please log in to Azure CLI first:"
    az login
fi

# Get subscription info
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo "📋 Current Azure subscription:"
echo "   ID: $SUBSCRIPTION_ID"
echo "   Name: $SUBSCRIPTION_NAME"
echo ""

read -p "Continue with this subscription? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please select the correct subscription using 'az account set --subscription <id>'"
    exit 1
fi

# Create service principal
echo "🔑 Creating service principal for GitHub Actions..."
echo "   This may take a few moments..."

SP_JSON=$(az ad sp create-for-rbac \
    --name "github-actions-azure-iac-$(date +%s)" \
    --role contributor \
    --scopes /subscriptions/$SUBSCRIPTION_ID \
    --sdk-auth)

echo ""
echo "✅ Service principal created successfully!"
echo ""
echo "🔐 GitHub Secret Configuration:"
echo "================================"
echo "1. Go to your GitHub repository"
echo "2. Navigate to Settings → Secrets and variables → Actions"
echo "3. Create a new repository secret named: AZURE_CREDENTIALS"
echo "4. Copy and paste the following JSON as the secret value:"
echo ""
echo "--- COPY EVERYTHING BELOW THIS LINE ---"
echo "$SP_JSON"
echo "--- COPY EVERYTHING ABOVE THIS LINE ---"
echo ""
echo "⚠️  IMPORTANT: Keep this information secure and never commit it to your repository!"
echo ""
echo "🎉 Setup complete! You can now use the GitHub Actions workflow for automatic deployment."