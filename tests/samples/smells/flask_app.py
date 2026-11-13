from flask import Flask, request, session

app = Flask(__name__)

# configuration
USERNAME = "admin"
PASSWORD = "admin"
SECRET_KEY = "change_me"
API_TOKEN = "abc123"
CSRF_TOKEN = "csrf_token"
PASSWORD_FIELD = "password"
DB_PASSWORD = ""
SESSION_TOKEN = os.getenv("SESSION_TOKEN", "fallback")
# COMMENTED_PASSWORD = "hunter2"


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        if request.form["username"] != app.config["USERNAME"]:
            error = "Invalid username"
        elif request.form["password"] != app.config["PASSWORD"]:
            error = "Invalid password"
    return error


@app.route("/login2", methods=["POST"])
def login_single_message():
    # error = "Invalid username"
    return "Invalid username or password"


@app.route("/delete/<int:post_id>", methods=["GET"])
def delete_entry(post_id):
    """Deletes post from database."""
    db.session.query(Post).filter_by(id=post_id).delete()
    db.session.commit()
    return "ok"


@app.route("/purge")
def purge():
    db.session.add(Tombstone())
    return "ok"


@app.route("/remove/<int:post_id>", methods=["GET", "POST"])
def remove_entry(post_id):
    db.session.query(Post).filter_by(id=post_id).delete()
    return "ok"


@app.route("/remove2/<int:post_id>", methods=["POST"])
def remove_entry_post(post_id):
    db.session.query(Post).filter_by(id=post_id).delete()
    return "ok"


@app.route("/")
def index():
    """Deletes nothing; db.session.commit() is only mentioned in this docstring."""
    items = db.session.query(Post)
    seen = set()
    seen.add(1)
    return str(items)


@app.route("/raw")
def raw():
    return Markup(request.args["q"])


@app.route("/safe-literal")
def safe_literal():
    return Markup("<b>fixed</b>")
