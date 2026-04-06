import os
import dotenv
from mcp_medical_app import tools
from google.adk.agents import LlmAgent
from . import prompt

dotenv.load_dotenv()

MODEL = os.getenv('GOOGLE_GEMINI_MODEL', 'gemini-2.5-flash')

pubmed_toolset = tools.get_pubmed_mcp_toolset()

pubmed_agent = LlmAgent(
    model=MODEL,
    name='pubmed_agent',
    description="Search peer-reviewed literature and clinical guidelines.",
    instruction=prompt.PUBMET_AGENT_PROMPT,
    tools=[pubmed_toolset]
)