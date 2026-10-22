"""Domain model for a help-desk ticket row.

``Ticket`` maps 1:1 to the ``helpdesk_tickets`` table. The annotated
fields are the source of truth for the data-model documentation.
"""
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Ticket:
    id: Optional[int] = None
    subject: str = ""
    customer_name: str = ""
    status: str = "open"
    priority: int = 1
    created_at: str = ""
    updated_at: str = ""

    def to_dict(self):
        """Flatten to a JSON-friendly dict (drop None id on creation)."""
        return {
            "id": self.id,
            "subject": self.subject,
            "customerName": self.customer_name,
            "status": self.status,
            "priority": self.priority,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
        }


@dataclass
class TicketListResponse:
    count: int = 0
    tickets: list = field(default_factory=list)
