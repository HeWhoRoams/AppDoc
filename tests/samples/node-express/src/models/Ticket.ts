// A help-desk ticket row mapped from the helpdesk_tickets table.
export interface Ticket {
  id: number;
  subject: string;
  customerName: string;
  status: string;
  priority: number;
  createdAt: string;
  updatedAt: string;
}

// A paginated list envelope returned by the ticket routes.
export interface TicketListResponse {
  count: number;
  tickets: Ticket[];
}
