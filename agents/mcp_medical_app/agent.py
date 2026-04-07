import os
import dotenv
from google.adk.agents import LlmAgent
from google.adk.tools import AgentTool
from google.genai import types

from mcp_medical_app import tools
from .sub_agents.patient_agent import patient_agent
from .sub_agents.pubmed_agent import pubmed_agent
from . import prompt

dotenv.load_dotenv()

MODEL = os.getenv('GOOGLE_GEMINI_MODEL', 'gemini-2.5-flash')

prompt_logging = tools.add_prompt_to_state

root_agent = LlmAgent(
    model=MODEL,
    name='root_agent',
    instruction=prompt.ROOT_AGENT_PROMPT,
    tools=[
        AgentTool(patient_agent), 
        AgentTool(pubmed_agent), 
        prompt_logging
    ],
    generate_content_config=types.GenerateContentConfig(
        http_options=types.HttpOptions(
            retry_options=types.HttpRetryOptions(
                initial_delay=1,  # seconds before first retry
                attempts=5        # number of retry attempts
            )
        )
    )
)