"""Python / Flask golden fixture (help-desk ticket service).

A minimal but realistic Flask + SQLAlchemy(psycopg2) + requests app used by
``tests/powershell/test-golden-python-flask.ps1`` to prove the framework-agnostic
AppDoc pipeline generalizes to a Python target:

  * requirements.txt with ``flask``           -> framework detection (Flask)
  * app.py ``app = Flask(__name__)`` + routes  -> Flask app + /health endpoint
  * routes.py ``@bp.route`` + methods         -> /api/tickets endpoint catalog
  * models.py ``@dataclass`` annotated fields -> data-model records (Ticket)
  * data/db.py psycopg2 + DB_PASSWORD          -> config-catalog + [REDACTED]
  * services/itsm.py ``requests.put``          -> External Call Register (outbound)
  * .env with FakeP@ss123                       -> redaction must strip the secret

No .NET SDK / no Python AST: the AppDoc pipeline extracts Python routes and models
via the generic regex extractors (see AppDoc.ApiInventory.Extractor.psm1 and
AppDoc.DataModel.Extractor.psm1).
"""
