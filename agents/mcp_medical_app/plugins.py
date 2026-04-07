from .adk_utils.plugins import Graceful429Plugin

graceful_plugin = Graceful429Plugin(
    name="graceful_429_plugin",
    fallback_text={
        "default": "Vena is currently unavailable due to high demand on our cloud resources. Please try again in a few minutes.\n\nIf this issue persists, you can explore the patient dataset directly via [Google BigQuery](https://console.cloud.google.com/bigquery) or search for clinical guidelines on [PubMed](https://pubmed.ncbi.nlm.nih.gov/)."
    }
)