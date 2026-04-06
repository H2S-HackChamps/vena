import os
import dotenv
from mcp_medical_app import tools
from google.adk.agents import LlmAgent
from . import prompt

dotenv.load_dotenv()

MODEL = os.getenv('GOOGLE_GEMINI_MODEL', 'gemini-2.5-flash')

bigquery_toolset = tools.get_bigquery_mcp_toolset()

patient_agent = LlmAgent(
    model=MODEL,
    name='patient_agent',
    description="Query patient demographics, encounters, medications, and synthetic EHR records.",
    instruction=prompt.PATIENT_AGENT_PROMPT,
    tools=[bigquery_toolset]
)