from google.adk.apps.app import App
from google.adk.agents import LlmAgent
from google.adk.models import Gemini
from google.adk.tools import AgentTool

from .config import MODEL, RETRY_OPTIONS
from .plugins import graceful_plugin
from .prompt import ROOT_AGENT_PROMPT
from .tools import add_prompt_to_state
from .sub_agents.patient_agent import patient_agent
from .sub_agents.pubmed_agent import pubmed_agent

root_agent = LlmAgent(
    model=Gemini(model=MODEL, retry_options=RETRY_OPTIONS),
    name='root_agent',
    instruction=ROOT_AGENT_PROMPT,
    tools=[
        AgentTool(patient_agent), 
        AgentTool(pubmed_agent), 
        add_prompt_to_state
    ]
)

graceful_plugin.apply_429_interceptor(root_agent)

app = App(
    name="mcp_medical_app",
    root_agent=root_agent,
    plugins=[graceful_plugin]
)
