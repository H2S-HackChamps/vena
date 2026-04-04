#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/../agents/mcp_medical_app/.env"

# Verify .env exists before sourcing
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

# Get Google Cloud Project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo "Error: Could not determine Google Cloud Project ID."
    echo "Please run 'gcloud config set project <PROJECT_ID>' first."
    exit 1
fi

echo "Found Project ID: $PROJECT_ID"
echo ""

if [ -z "$GOOGLE_CLOUD_SA_NAME" ]; then
    echo "Error: Could not determine Service Account Name."
    exit 1
fi

echo "Found Service Account Name: $GOOGLE_CLOUD_SA_NAME"
echo ""

if [ -z "$GOOGLE_CLOUD_SERVICE_ACCOUNT" ]; then
    echo "Error: Could not determine Service Account."
    exit 1
fi

echo "Found Service Account: $GOOGLE_CLOUD_SERVICE_ACCOUNT"
echo ""

# Enable necessary APIs
echo "Enabling APIs.."
gcloud services enable run.googleapis.com --project=$PROJECT_ID
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID
gcloud services enable aiplatform.googleapis.com --project=$PROJECT_ID
gcloud services enable compute.googleapis.com --project=$PROJECT_ID
echo "DONE"
echo ""

# Create Service Account
echo "Creating Service Account.."
gcloud iam service-accounts create $GOOGLE_CLOUD_SA_NAME --display-name="Service Account for Hackathon Submission"
echo "DONE"
echo ""

# Grant the "Vertex AI User" role to your service account
echo "Granting the "Vertex AI User" role to the service account.."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$GOOGLE_CLOUD_SERVICE_ACCOUNT" --role="roles/aiplatform.user"
echo "DONE"
echo ""

# Run the deployment command
echo "Deploying to Google Cloud .."
uvx --from google-adk==1.28.0
cd agents/mcp_medical_app 
adk deploy cloud_run --project=$PROJECT_ID --region=europe-west1 --service_name=vena --with_ui . -- --labels=dev-tutorial=hackaton-adk --service-account=$GOOGLE_CLOUD_SERVICE_ACCOUNT