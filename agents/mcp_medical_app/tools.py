import os
import dotenv
import logging

import google.auth
import google.cloud.logging

from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams
from google.adk.tools.tool_context import ToolContext

BIGQUERY_MCP_URL = "https://bigquery.googleapis.com/mcp" 
PUBMED_MCP_URL = "https://pubmed.caseyjhand.com/mcp"

def get_bigquery_mcp_toolset():   
        
    credentials, project_id = google.auth.default(
        scopes=["https://www.googleapis.com/auth/bigquery"]
    )

    credentials.refresh(google.auth.transport.requests.Request())
    oauth_token = credentials.token
        
    HEADERS_WITH_OAUTH = {
        "Authorization": f"Bearer {oauth_token}",
        "x-goog-user-project": project_id
    }

    tools = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=BIGQUERY_MCP_URL,
            headers=HEADERS_WITH_OAUTH,
            timeout=30.0,          
            sse_read_timeout=300.0
        )
    )
    print("MCP Toolset configured for Streamable HTTP connection.")
    return tools


def get_pubmed_mcp_toolset():
    dotenv.load_dotenv()
    ncbi_api_key = os.getenv('NCBI_API_KEY', 'no_api_found')
    ncbi_email = os.getenv('NCBI_EMAIL', 'no_api_found')

    HEADERS_WITH_API_AUTH = {
        "NCBI_API_KEY": ncbi_api_key,
        "NCBI_EMAIL": ncbi_email,
        "Accept": "application/json, text/event-stream"
    }

    tools = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=PUBMED_MCP_URL,
            headers=HEADERS_WITH_API_AUTH,
            timeout=30.0,          
            sse_read_timeout=300.0
        )
    )

    print("MCP Toolset configured for Streamable HTTP connection.")
    return tools

# --- Setup Logging and Environment ---

cloud_logging_client = google.cloud.logging.Client()
cloud_logging_client.setup_logging()

def add_prompt_to_state(
    tool_context: ToolContext, prompt: str
) -> dict[str, str]:
    """Saves the user's initial prompt to the state."""
    tool_context.state["PROMPT"] = prompt
    logging.info(f"[State updated] Added to PROMPT: {prompt}")
    return {"status": "success"}