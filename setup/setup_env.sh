#!/bin/bash

# Get Google Cloud Project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo "Error: Could not determine Google Cloud Project ID."
    echo "Please run 'gcloud config set project <PROJECT_ID>' first."
    exit 1
fi

echo "Found Project ID: $PROJECT_ID"

# Enable necessary APIs
echo "Enabling APIs.."
gcloud services enable aiplatform.googleapis.com --project=$PROJECT_ID
gcloud services enable apikeys.googleapis.com --project=$PROJECT_ID
# gcloud services enable mapstools.googleapis.com --project=$PROJECT_ID
gcloud services enable bigquery.googleapis.com --project=$PROJECT_ID
ENABLED_SERVICES=$(gcloud beta services mcp list --enabled --format="value(name.basename())" --project=$PROJECT_ID)
# if [[ ! "$ENABLED_SERVICES" == *"mapstools.googleapis.com"* ]]; then
#     gcloud --quiet beta services mcp enable mapstools.googleapis.com --project=$PROJECT_ID
# fi
if [[ ! "$ENABLED_SERVICES" == *"bigquery.googleapis.com"* ]]; then
    gcloud --quiet beta services mcp enable bigquery.googleapis.com --project=$PROJECT_ID
fi

# # Create API Key
# echo "Creating Google Maps Platform API Key..."

# API_KEY_NAME="medical-demo-key-$(date +%s)"
# API_KEY_JSON=$(gcloud alpha services api-keys create --display-name="$API_KEY_NAME" \
#     --api-target=service=mapstools.googleapis.com \
#     --format=json 2>/dev/null)

# if [ $? -eq 0 ]; then
#     API_KEY=$(echo "$API_KEY_JSON" | grep -oP '"keyString": "\K[^"]+' 2>/dev/null || echo "$API_KEY_JSON" | grep '"keyString":' | cut -d '"' -f 4)
#     if [ -z "$API_KEY" ]; then
#         echo "Could not parse API Key from JSON."
#     fi
#     echo "Successfully created API Key."
# else
#     echo "Could not automate API key creation."
#     read -p "Please enter your Google Maps Platform API Key manually: " API_KEY
# fi

# if [ -z "$API_KEY" ]; then
#     echo "Error: API Key cannot be empty."
#     exit 1
# fi

# Create .env file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/../agents/mcp_medical_app/.env"
mkdir -p $(dirname "$ENV_FILE")

cat <<EOF > "$ENV_FILE"
# Google Cloud
GOOGLE_GENAI_USE_VERTEXAI=1
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_LOCATION=global
GOOGLE_GEMINI_MODEL="gemini-2.5-flash"
BIG_QUERY_DATASET="mcp_medical"

# NCBI / PubMed
NCBI_API_KEY=
NCBI_EMAIL=
EOF

echo "Successfully updated $ENV_FILE"

echo "You can obtain a free NCBI API key at https://www.ncbi.nlm.nih.gov/account/"