"""Entry point for the help-desk ticket service (Flask)."""
import os

from dotenv import load_dotenv
from flask import Flask

from routes import tickets_bp

load_dotenv()

app = Flask(__name__)

# Mount the ticket routes as a blueprint.
app.register_blueprint(tickets_bp)


@app.route("/health")
def health():
    """Liveness probe for the container orchestrator."""
    return {"status": "ok", "service": "helpdesk-tickets-api"}


if __name__ == "__main__":
    # Bind to the configured port; debug is never enabled in this image.
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")), debug=False)
