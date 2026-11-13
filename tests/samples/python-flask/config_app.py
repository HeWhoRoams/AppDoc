"""Config loaded through from_object plus scheduled jobs; the planted values must never reach the Facts file."""
import os

from apscheduler.schedulers.background import BackgroundScheduler
from celery import Celery
from celery.schedules import crontab
from flask import Flask

PAGE_SIZE = 25
SECRET_KEY = "Fl4sk-Sample-S3cret-Key"


class DevConfig:
    MAIL_SERVER = "smtp.dev.internal"
    MAIL_API_TOKEN = "tok_dev_9d41c7a2e6b8"


def create_app():
    app = Flask(__name__)
    app.config.from_object(__name__)
    app.config.from_object("config_app.DevConfig")
    app.config["UPLOAD_DIR"] = "/var/uploads"
    app.config.update(MAX_CONTENT_LENGTH=1024, MAIL_PASSWORD="Mail-Pa55-sample")
    os.environ["REPORT_DIR"] = "/var/reports"
    limit = app.config["PAGE_SIZE"]
    return app, limit


def sync_tickets():
    pass


def nightly_purge():
    pass


scheduler = BackgroundScheduler()
scheduler.add_job(sync_tickets, "interval", minutes=5, id="sync-tickets")
scheduler.add_job(nightly_purge, trigger="cron", hour=2, minute=30)
scheduler.add_job(sync_tickets, "date")

celery = Celery("helpdesk")
celery.conf.beat_schedule = {
    "digest-email": {"task": "tasks.send_digest", "schedule": crontab(hour=7, minute=0)},
    "heartbeat": {"task": "tasks.ping", "schedule": 30.0},
}
