// Outbound integration to the ITSM support system. This is an EXTERNAL boundary:
// the response shape is owned by support.internal and is not guaranteed stable.
const SUPPORT_API_URL = process.env.SUPPORT_API_URL || 'https://support.internal/itsm/api';

export interface ItsmTicketSyncResult {
  synced: boolean;
  remoteId: string;
}

// POST an updated ticket status to the ITSM system (outbound HTTP call).
export async function syncTicketStatusToItsm(ticketId: number, status: string): Promise<ItsmTicketSyncResult> {
  const url = `${SUPPORT_API_URL}/tickets/${ticketId}/status`;
  const response = await fetch(url, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status })
  });
  if (!response.ok) {
    throw new Error(`ITSM sync failed: HTTP ${response.status} for ticket ${ticketId}`);
  }
  const payload = (await response.json()) as { remoteId: string };
  return { synced: true, remoteId: payload.remoteId };
}
