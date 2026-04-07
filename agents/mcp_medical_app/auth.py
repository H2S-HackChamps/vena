import httpx
import google.auth.transport.requests
from typing import Generator

class GoogleCredentialsAuth(httpx.Auth):
    """httpx Auth handler that automatically refreshes Google OAuth tokens.

    Fetching the token once at startup causes Access Denied after ~1 hour
    when the token expires. This class refreshes the token before each
    request, so the agent never hits an expiry mid-session.
    """

    def __init__(self, credentials, project_id: str):
        self.credentials = credentials
        self.project_id = project_id
        self._http_request = google.auth.transport.requests.Request()

    def auth_flow(self, request: httpx.Request) -> Generator[httpx.Request, httpx.Response, None]:
        # Refresh the token if it is expired or about to expire
        if not self.credentials.valid:
            self.credentials.refresh(self._http_request)

        request.headers["Authorization"] = f"Bearer {self.credentials.token}"
        request.headers["x-goog-user-project"] = self.project_id
        yield request