"""Outbound integration to the ITSM support system.

This is an EXTERNAL boundary: the response shape is owned by support.internal
and is not guaranteed stable. All calls go through ``requests`` so the
pipeline can flag them as outbound HTTP integrations.
"""
import os

import requests

SUPPORT_API_URL = os.environ.get("SUPPORT_API_URL", "https://support.internal/itsm/api")
_TIMEOUT_SECONDS = 10


class ItsmsyncResult:
    def __init__(self, synced, remote_id):
        self.synced = synced
        self.remote_id = remote_id


def sync_ticket_status(ticket_id, status):
    """POST an updated ticket status to the ITSM system (outbound HTTP call).

    Returns an ``ItsmSyncResult``; raises ``RuntimeError`` on a non-2xx response.
    """
    url = f"{SUPPORT_API_URL}/tickets/{ticket_id}/status"
    response = requests.put(
        url,
        json={"status": status},
        headers={"Content-Type": "application/json"},
        timeout=_TIMEOUT_SECONDS,
    )
    if response.status_code >= 400:
        raise RuntimeError(f"ITSM sync failed: HTTP {response.status_code} for ticket {ticket_id}")
    payload = response.json()
    return ItsmsyncResult(synced=True, remote_id=payload.get("remoteId"))
