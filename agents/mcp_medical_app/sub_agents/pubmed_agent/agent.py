from google.adk.agents import LlmAgent
from google.adk.models import Gemini

from .prompt import PUBMED_AGENT_PROMPT
from mcp_medical_app.tools import get_pubmed_mcp_toolset
from mcp_medical_app.config import MODEL, RETRY_OPTIONS

pubmed_toolset = get_pubmed_mcp_toolset()

pubmed_agent = LlmAgent(
    model=Gemini(model=MODEL, retry_options=RETRY_OPTIONS),
    name='pubmed_agent',
    description="Search peer-reviewed literature and clinical guidelines.",
    instruction=PUBMED_AGENT_PROMPT,
    tools=[pubmed_toolset]
)