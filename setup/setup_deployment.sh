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

# Enable APIs (skip any that are already enabled)
echo "Checking APIs.."
APIS=(
    run.googleapis.com
    artifactregistry.googleapis.com
    cloudbuild.googleapis.com
    aiplatform.googleapis.com
    compute.googleapis.com
)
ENABLED_APIS=$(gcloud services list --enabled --format="value(config.name)" --project=$PROJECT_ID 2>/dev/null)
for API in "${APIS[@]}"; do
    if echo "$ENABLED_APIS" | grep -q "^${API}$"; then
        echo "  [SKIP] $API already enabled"
    else
        echo "  [ENABLING] $API.."
        gcloud services enable $API --project=$PROJECT_ID
    fi
done
echo "DONE"
echo ""

# Create Service Account (skip if it already exists)
echo "Checking Service Account.."
SA_EXISTS=$(gcloud iam service-accounts list \
    --filter="email:${GOOGLE_CLOUD_SERVICE_ACCOUNT}" \
    --format="value(email)" \
    --project=$PROJECT_ID 2>/dev/null)
if [ -n "$SA_EXISTS" ]; then
    echo "  [SKIP] Service account $GOOGLE_CLOUD_SERVICE_ACCOUNT already exists"
else
    echo "  [CREATING] Service account $GOOGLE_CLOUD_SA_NAME.."
    gcloud iam service-accounts create $GOOGLE_CLOUD_SA_NAME \
        --display-name="Service Account for Hackathon Submission" \
        --project=$PROJECT_ID
fi
echo "DONE"
echo ""

# Grant IAM roles (skip any already granted)
echo "Checking IAM roles.."
ROLES=(
    roles/aiplatform.user
    roles/bigquery.dataViewer
    roles/bigquery.jobUser
)
MEMBER="serviceAccount:$GOOGLE_CLOUD_SERVICE_ACCOUNT"
CURRENT_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:${MEMBER}" \
    --format="value(bindings.role)" 2>/dev/null)
for ROLE in "${ROLES[@]}"; do
    if echo "$CURRENT_ROLES" | grep -q "^${ROLE}$"; then
        echo "  [SKIP] $ROLE already granted"
    else
        echo "  [GRANTING] $ROLE.."
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="$MEMBER" \
            --role="$ROLE"
    fi
done
echo "DONE"
echo ""

# Run the deployment command
echo "Deploying to Google Cloud .."
uvx --from google-adk==1.28.0
cd agents/mcp_medical_app 
adk deploy cloud_run --project=$PROJECT_ID --region=europe-west1 --service_name=vena --with_ui . -- --labels=dev-tutorial=hackaton-adk --service-account=$GOOGLE_CLOUD_SERVICE_ACCOUNT