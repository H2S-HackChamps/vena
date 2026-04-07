import os
import dotenv
import logging

import google.auth
import google.cloud.logging

from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams, create_mcp_http_client
from google.adk.tools.tool_context import ToolContext

from .auth import GoogleCredentialsAuth
from .config import BIGQUERY_AUTH_URL, BIGQUERY_MCP_URL, NCBI_API_KEY, NCBI_EMAIL, PUBMED_MCP_URL

def get_bigquery_mcp_toolset():

    credentials, project_id = google.auth.default(
        scopes=[BIGQUERY_AUTH_URL]
    )

    bq_auth = GoogleCredentialsAuth(credentials, project_id)

    def bigquery_http_client_factory(headers=None, timeout=None, auth=None):
        return create_mcp_http_client(headers=headers, timeout=timeout, auth=bq_auth)

    tools = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=BIGQUERY_MCP_URL,
            timeout=30.0,
            sse_read_timeout=300.0,
            httpx_client_factory=bigquery_http_client_factory
        )
    )
    print("MCP Toolset configured for Streamable HTTP connection.")
    return tools

def get_pubmed_mcp_toolset():
    HEADERS_WITH_API_AUTH = {
        "NCBI_API_KEY": NCBI_API_KEY,
        "NCBI_EMAIL": NCBI_EMAIL,
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

# Setup Logging and Environment

cloud_logging_client = google.cloud.logging.Client()
cloud_logging_client.setup_logging()

def add_prompt_to_state(
    tool_context: ToolContext, prompt: str
) -> dict[str, str]:
    """Saves the user's initial prompt to the state."""
    tool_context.state["PROMPT"] = prompt
    logging.info(f"[State updated] Added to PROMPT: {prompt}")
    return {"status": "success"}
