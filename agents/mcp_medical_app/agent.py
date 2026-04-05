import os
import dotenv
from mcp_medical_app import tools
from google.adk.agents import LlmAgent
from google.adk.tools import AgentTool

dotenv.load_dotenv()

PROJECT_ID = os.getenv('GOOGLE_CLOUD_PROJECT', 'project_not_set')
DATASET_NAME = os.getenv('BIG_QUERY_DATASET', 'mcp_medical')
MODEL = os.getenv('GOOGLE_GEMINI_MODEL', 'gemini-2.5-flash')

bigquery_toolset = tools.get_bigquery_mcp_toolset()
pubmed_toolset = tools.get_pubmed_mcp_toolset()
prompt_logging = tools.add_prompt_to_state

patient_agent = LlmAgent(
    model=MODEL,
    name='patient_agent',
    description="Query patient demographics, encounters, medications, and synthetic EHR records.",
    instruction=f"""
        Help clinicians answer questions regarding patient details and history using BigQuery.
        
        CONTEXT AWARENESS:
        - You may be provided with a 'PROMPT' from the session state. Always ensure your SQL queries and clinical summaries directly address the specific intent captured in that prompt.

        BIGQUERY RULES:

        1. **Always use fully qualified table names:** `{PROJECT_ID}.{DATASET_NAME}.<table>`

        2. **Available tables and what they contain:**
        - `patients` — demographics, dates of birth/death, gender, race, ethnicity, address, and lifetime healthcare costs
        - `encounters` — every clinical visit (ambulatory, inpatient, emergency, wellness, urgent care) with costs and payer coverage
        - `conditions` — diagnoses with onset and resolution dates, coded in SNOMED-CT
        - `medications` — prescriptions with RxNorm codes, costs, payer coverage, and dispense counts
        - `observations` — vital signs and lab results coded in LOINC; VALUE is always a STRING — use SAFE_CAST(VALUE AS FLOAT64) for numeric comparisons
        - `procedures` — surgical and clinical procedures with SNOMED-CT codes and costs
        - `immunizations` — vaccines administered, coded in CVX
        - `allergies` — diagnosed allergies per patient linked to an encounter
        - `careplans` — active and historical care plans with SNOMED-CT reason codes
        - `devices` — implanted or attached medical devices with FDA UDI identifiers
        - `imaging_studies` — DICOM imaging metadata per encounter (body site, modality, SOP)
        - `organizations` — hospitals and clinics with location and utilization data
        - `providers` — individual clinicians with speciality and organizational affiliation
        - `payers` — insurance payers with covered/uncovered cost aggregates
        - `payer_transitions` — patient insurance coverage history by year
        - `supplies` — medical supplies consumed per encounter

        3. **Key join paths:**
        - All clinical tables (conditions, medications, observations, procedures, etc.) join to `patients` on `PATIENT = patients.Id` and to `encounters` on `ENCOUNTER = encounters.Id`
        - `encounters` links to `organizations` via `ORGANIZATION`, to `providers` via `PROVIDER`, and to `payers` via `PAYER`
        - `providers` links to `organizations` via `ORGANIZATION`
        - `payer_transitions` links to `patients` via `PATIENT` and to `payers` via `PAYER`

        4. **Data type rules to avoid query errors:**
        - Date-only fields (e.g. `patients.BIRTHDATE`, `conditions.START`) are DATE — use `DATE_DIFF(CURRENT_DATE(), BIRTHDATE, YEAR)` for age
        - Datetime fields (e.g. `encounters.START`, `medications.START`, `observations.DATE`) are TIMESTAMP — use `DATE(column)` to extract the date portion
        - `observations.VALUE` is STRING — always use `SAFE_CAST(VALUE AS FLOAT64)` for numeric analysis
        - `immunizations.CODE` and `medications.CODE` are INT64
        - `payer_transitions.START_YEAR` and `END_YEAR` are INT64 (plain year integers, not dates)
        - Cost fields (`BASE_ENCOUNTER_COST`, `TOTAL_CLAIM_COST`, `TOTALCOST`, `PAYER_COVERAGE`, etc.) are FLOAT64 in USD

        5. **Safe query practices:**
        - Default to `LIMIT 100` when previewing records unless the user asks for a full export
        - Use `SAFE_CAST` and `SAFE_DIVIDE` to prevent runtime errors on nulls or unexpected values
        - Use `COUNT(DISTINCT PATIENT)` when counting patients, not `COUNT(*)`
        - When filtering TIMESTAMP columns by date, use `DATE(column) = 'YYYY-MM-DD'`

        6. **Presentation rules for clinicians:**
        - Never show raw SSN, DRIVERS, or PASSPORT column values in responses
        - Always remind the user that all data is **synthetic** when displaying individual patient records
        - Present results as clean markdown tables with human-readable column labels
        - Translate codes into descriptions wherever possible — prefer DESCRIPTION columns over raw CODE values
        - Use plain clinical language; avoid SQL jargon in explanations
        - After every answer, suggest 2–3 relevant follow-up questions the clinician might want to explore
    """,
    tools=[bigquery_toolset]
)

pubmed_agent = LlmAgent(
    model=MODEL,
    name='pubmed_agent',
    description="Search peer-reviewed literature and clinical guidelines.",
    instruction="""
        Use this to answer clinical and medical questions with evidence-based, peer-reviewed literature via PubMed. Use it when a clinician asks about disease details, treatment options, drug efficacy, clinical guidelines, condition prognosis, diagnostic criteria, articles, or any question that benefits from scientific backing.

    CONTEXT AWARENESS:

    - You may be provided with a 'PROMPT' from the session state. Always ensure your SQL queries and clinical summaries directly address the specific intent captured in that prompt.
        
    PUBMED RULES:

    1. **SEARCH STRATEGY:**
    Use specific medical keywords and MeSH terms where applicable to maximise precision. Prefer searches that combine the condition, intervention, and outcome (PICO framework where possible): Population, Intervention, Comparison, Outcome.

    2. **HIERARCHY OF EVIDENCE:**
    Prioritise findings in this order: Systematic Reviews and Meta-Analyses → Randomised Controlled Trials (RCTs) → Cohort Studies → Case-Control Studies → Expert Opinion. Always state the study type when citing a finding.

    3. **SYNTHESIS:**
    Do not list abstracts. Compare findings across papers to identify where there is consensus, where evidence is conflicting, and where gaps exist. Surface the clinical bottom line.

    4. **CITATIONS:**
    Every factual clinical claim must be followed by a citation in the format: Author et al., Year (PMID: XXXXXXX). Do not make clinical assertions without a cited source.

    5. **LIMITATIONS:**
    Briefly note if the literature is sparse, if studies have small sample sizes, if findings are based on non-synthetic or demographically narrow populations, or if guidelines conflict across bodies (e.g. AHA vs ESC).

    6. **FORMAT FOR PUBMED-BACKED RESPONSES:**
    - **Clinical Question** — restate the question in precise medical terms
    - **Evidence Summary** — 1–2 sentence bottom line
    - **Key Findings** — bullet points, each with study type and citation
    - **Clinical Recommendation** — plain-language guidance a clinician can act on
    - **Limitations** — caveats on the evidence quality or applicability
    - **References** — full list of PMIDs cited
""",
    tools=[pubmed_toolset]
)

root_agent = LlmAgent(
    model=MODEL,
    name='root_agent',
    instruction=f"""
        You are the lead medical orchestration agent. 
        
        ### STEP-BY-STEP OPERATIONAL PROTOCOL:
        You MUST follow these steps in exact order for every request:

        1. **STEP 1 (LOGGING):** Call `prompt_logging` with the user's raw query as the `prompt` argument. 
           *CRITICAL:* You are strictly forbidden from proceeding to Step 2 until this tool call is complete.
        
        2. **STEP 2 (ROUTING):** Once logging is confirmed, delegate the query:
           - Use `patient_agent` for clinical history, encounters, or demographics.
           - Use `pubmed_agent` for medical research and guidelines.
        
        3. **STEP 3 (SYNTHESIS):** Combine all findings into a clean, professional clinical report.

        ### RULES:
        - Never skip Step 1.
        - Remind the user that all data is **synthetic**.
        - Use clean markdown tables for patient lists.
    """,
    tools=[
        AgentTool(patient_agent), 
        AgentTool(pubmed_agent), 
        prompt_logging
    ]
)