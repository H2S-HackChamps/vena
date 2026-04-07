import os
import dotenv
from mcp_medical_app import tools
from google.adk.agents import LlmAgent
from google.adk.agents.callback_context import CallbackContext
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset

from . import prompt

dotenv.load_dotenv()

MODEL = os.getenv('GOOGLE_GEMINI_MODEL', 'gemini-2.5-flash')


def refresh_bigquery_toolset(callback_context: CallbackContext) -> None:
    """Recreates the BigQuery toolset at the start of each session.

    Module-level code runs once at import time and is cached by Python.
    This means a toolset created at module level reuses the same credentials
    object for the lifetime of the process — even across new sessions — and
    will start returning Access Denied once the OAuth token expires (~1 hour).

    Recreating the toolset here ensures fresh credentials are obtained at the
    start of every session.
    """
    fresh_toolset = tools.get_bigquery_mcp_toolset()
    patient_agent.tools = [fresh_toolset]


patient_agent = LlmAgent(
    model=MODEL,
    name='patient_agent',
    description="Query patient demographics, encounters, medications, and synthetic EHR records.",
    instruction=prompt.PATIENT_AGENT_PROMPT,
    tools=[tools.get_bigquery_mcp_toolset()],
    before_agent_callback=refresh_bigquery_toolset
)