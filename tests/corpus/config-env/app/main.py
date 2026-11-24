import os
from flask import Flask
app = Flask(__name__)
db_url = os.getenv("DATABASE_URL")
token = os.getenv("API_TOKEN")
debug = app.config["DEBUG"]  # line 6
# line 7
# line 8
# line 9
# line 10
