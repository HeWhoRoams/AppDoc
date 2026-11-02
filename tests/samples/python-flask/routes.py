"""Ticket routes (Flask blueprint).

These endpoints mirror the help-desk REST surface: list/create a ticket and
fetch or close a single ticket. The list endpoint accepts an optional ``status``
query filter and returns a count + the matching rows.
"""
from flask import Blueprint, jsonify, request

from data.db import get_tickets, get_ticket_by_id, create_ticket, delete_ticket

tickets_bp = Blueprint("tickets", __name__)


@tickets_bp.route("/api/tickets", methods=["GET"])
def list_tickets():
    """GET /api/tickets — list tickets, optionally filtered by status."""
    status = request.args.get("status")
    tickets = get_tickets(status)
    return jsonify({"count": len(tickets), "tickets": tickets})


@tickets_bp.route("/api/tickets", methods=["POST"])
def create_new_ticket():
    """POST /api/tickets — create a ticket from the JSON body."""
    payload = request.get_json(silent=True) or {}
    if not payload.get("subject"):
        return jsonify({"error": "subject is required"}), 400
    created = create_ticket(payload)
    return jsonify(created), 201


@tickets_bp.route("/api/tickets/<int:ticket_id>")
def get_single_ticket(ticket_id):
    """GET /api/tickets/<id> — fetch one ticket by numeric id."""
    ticket = get_ticket_by_id(ticket_id)
    if not ticket:
        return jsonify({"error": "ticket not found", "id": ticket_id}), 404
    return jsonify(ticket)


@tickets_bp.route("/api/tickets/<int:ticket_id>", methods=["DELETE"])
def close_ticket(ticket_id):
    """DELETE /api/tickets/<id> — close and remove a ticket."""
    deleted = delete_ticket(ticket_id)
    if not deleted:
        return jsonify({"error": "ticket not found", "id": ticket_id}), 404
    return jsonify({"deleted": True, "id": ticket_id})
