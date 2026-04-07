import os
import dotenv

from google.genai import types

dotenv.load_dotenv()

RETRY_OPTIONS = types.HttpRetryOptions(initial_delay=1, max_delay=3, attempts=30)

MODEL = os.getenv('GOOGLE_GEMINI_MODEL', 'gemini-2.5-flash')
NCBI_API_KEY = os.getenv('NCBI_API_KEY', 'no_api_found')
NCBI_EMAIL = os.getenv('NCBI_EMAIL', 'no_email_found')
PROJECT_ID = os.getenv('GOOGLE_CLOUD_PROJECT', 'project_not_set')
DATASET_NAME = os.getenv('BIG_QUERY_DATASET', 'mcp_medical')

BIGQUERY_MCP_URL = "https://bigquery.googleapis.com/mcp" 
PUBMED_MCP_URL = "https://pubmed.caseyjhand.com/mcp"
BIGQUERY_AUTH_URL = "https://www.googleapis.com/auth/bigquery"