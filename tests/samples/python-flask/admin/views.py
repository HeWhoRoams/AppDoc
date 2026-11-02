"""Admin blueprint: exercises prefixes, roles, raw SQL, procs and a few outbound calls."""
import os
import smtplib
import subprocess

import pyodbc
import requests
from flask import Blueprint, abort, current_app, flash, jsonify
from flask_login import current_user, login_required
from flask_security import roles_required
from sqlalchemy import create_engine, text

from extensions import db

admin_bp = Blueprint("admin", __name__, url_prefix="/admin")

# Hard-coded on purpose: these values must never reach the Facts file.
LEGACY_DSN = "DRIVER={SQL Server};SERVER=legacy;UID=svc_admin;PWD=Zx9-Legacy-Pa55w0rd"
ENGINE = create_engine("postgresql://svc_admin:Sup3rS3cretPw@db.internal/app")
REPORT_CONN = pyodbc.connect(LEGACY_DSN)
API_TOKEN = "tok_live_8f3a91c2d7e04b5a9c61"

# @admin_bp.route("/old-route")
# def old_route():
#     flash("commented out message")


class Agent(db.Model):
    __tablename__ = "helpdesk_agents"
    id = db.Column(db.Integer, primary_key=True)


@admin_bp.route("/users", methods=["GET", "POST"])
@login_required
@roles_required("admin", "supervisor")
def users():
    if not current_user.has_role("admin"):
        abort(403, "admins only")
    flash("User list refreshed", "info")
    rows = ENGINE.execute(text("SELECT id, name FROM helpdesk_agents a JOIN helpdesk_teams t ON t.id = a.team_id"))
    return jsonify([dict(r) for r in rows])


@admin_bp.get("/purge")
def purge():
    cur = REPORT_CONN.cursor()
    cur.callproc("usp_PurgeClosedTickets")
    cur.execute("EXEC usp_RebuildIndexes")
    cur.execute("UPDATE helpdesk_tickets SET status = 'closed' WHERE age > 90")
    subprocess.run(["/usr/bin/backup", "--target", "nightly"], check=False)
    smtplib.SMTP("smtp.internal").sendmail("a@b", ["c@d"], "done")
    requests.post("https://hooks.internal/notify?token=abc123secretvalue", json={})
    with open("/var/log/purge.log", "a") as fh:
        fh.write("purged")
    return jsonify(error="purge failed: nothing to purge")


def settings():
    return current_app.config["ADMIN_EMAIL"], os.getenv("ADMIN_API_TOKEN")
