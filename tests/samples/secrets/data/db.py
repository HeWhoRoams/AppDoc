"""Data access layer for the ticket service.

Credentials are read from the environment (see .env) and NEVER hard-coded.
The connection string is assembled from parts; the password portion is
sourced from ``DB_PASSWORD`` and treated as sensitive.
"""
import os

import psycopg2
from psycopg2.extras import RealDictRow


def _build_connection_string() -> str:
    """Assemble the DB connection string from environment variables."""
    return (
        "host=%s port=%s user=%s dbname=%s password=%s"
        % (
            os.environ.get("DB_HOST"),
            os.environ.get("DB_PORT", "5432"),
            os.environ.get("DB_USER"),
            os.environ.get("DB_NAME"),
            os.environ.get("DB_PASSWORD"),
        )
    )


def _connect():
    return psycopg2.connect(_build_connection_string())


def get_tickets(status=None):
    """Return tickets, optionally filtered by status (newest first)."""
    conn = _connect()
    try:
        cur = conn.cursor()
        if status:
            cur.execute(
                "SELECT * FROM helpdesk_tickets WHERE status = %s ORDER BY created_at DESC",
                (status,),
            )
        else:
            cur.execute("SELECT * FROM helpdesk_tickets ORDER BY created_at DESC")
        rows = [dict(row) for row in cur.fetchall()]
        return rows
    finally:
        conn.close()


def get_ticket_by_id(ticket_id):
    """Return a single ticket by id, or None."""
    conn = _connect()
    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM helpdesk_tickets WHERE id = %s", (ticket_id,))
        row = cur.fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def create_ticket(payload):
    """Insert a new ticket and return the stored row."""
    conn = _connect()
    try:
        cur = conn.cursor()
        cur.execute(
            (
                "INSERT INTO helpdesk_tickets (subject, customer_name, status, priority, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, NOW(), NOW()) RETURNING *"
            ),
            (
                payload.get("subject"),
                payload.get("customerName"),
                payload.get("status", "open"),
                int(payload.get("priority", 1)),
            ),
        )
        row = cur.fetchone()
        conn.commit()
        return dict(row)
    finally:
        conn.close()


def delete_ticket(ticket_id):
    """Close and remove a ticket. Returns True when a row was affected."""
    conn = _connect()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM helpdesk_tickets WHERE id = %s", (ticket_id,))
        conn.commit()
        return cur.rowcount > 0
    finally:
        conn.close()
