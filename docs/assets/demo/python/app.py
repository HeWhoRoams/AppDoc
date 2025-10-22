"""
Demo Flask web service for AppDoc demonstration.

This file contains a simple Flask application with various functions
to showcase documentation analysis.
"""

from flask import Flask, jsonify, request
from datetime import datetime

app = Flask(__name__)

def get_user_data(user_id: int) -> dict:
    """Retrieve user data by ID.

    Args:
        user_id: Unique identifier for the user

    Returns:
        Dictionary containing user information
    """
    return {
        "id": user_id,
        "name": "Demo User",
        "email": "user@example.com"
    }

def process_data():
    """Process incoming data without proper documentation."""
    data = request.json
    # Some processing logic here
    return {"status": "processed"}

def validate_input(data):
    """Basic input validation function."""
    if not data:
        return False
    # More validation logic
    return True

@app.route('/users/<int:user_id>')
def get_user(user_id: int):
    """API endpoint to get user information.

    Retrieves user data from the database and returns JSON response.
    This function is properly documented.
    """
    user = get_user_data(user_id)
    return jsonify(user)

@app.route('/health')
def health_check():
    """Health check endpoint.

    Returns current timestamp and service status.
    Used by monitoring systems to verify service availability.
    """
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True)
