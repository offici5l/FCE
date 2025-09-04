
import os
import subprocess
from flask import Flask, request, jsonify, send_from_directory

# Initialize Flask app
app = Flask(__name__)

# Define the output directory
OUTPUT_DIR = "/workspace/output"
# The entrypoint script is now in the same directory
ENTRYPOINT_SCRIPT = "./entrypoint.sh"

@app.route('/')
def index():
    """A simple endpoint to confirm the server is running."""
    return "<h1>FCE Web Service</h1><p>Ready to extract firmware content.</p>"

@app.route('/extract', methods=['POST'])
def extract():
    """
    The main endpoint to trigger the extraction process.
    Expects a JSON body with 'url' and 'file'.
    """
    # Get data from the request
    data = request.get_json()
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    rom_url = data.get('url')
    file_to_extract = data.get('file')

    if not rom_url or not file_to_extract:
        return jsonify({"error": "Missing 'url' or 'file' parameters"}), 400

    # --- Run the extraction script ---
    # Ensure the script is executable
    subprocess.run(['chmod', '+x', ENTRYPOINT_SCRIPT], check=True)
    
    # Execute the script
    process = subprocess.run(
        [ENTRYPOINT_SCRIPT, rom_url, file_to_extract],
        capture_output=True,
        text=True
    )

    # --- Handle the result ---
    if process.returncode != 0:
        # If the script fails, return the error log
        error_log = process.stderr or process.stdout
        return jsonify({
            "error": "Extraction script failed.",
            "log": error_log
        }), 500

    # If successful, find the output file
    output_filename = f"{file_to_extract}.zip"
    output_path = os.path.join(OUTPUT_DIR, output_filename)

    if os.path.exists(output_path):
        # Send the file for download
        # Note: In a production environment, it's better to upload this to a
        # persistent storage (like S3) and return a URL.
        # For Render's free tier, direct download might be slow or time out.
        return send_from_directory(OUTPUT_DIR, output_filename, as_attachment=True)
    else:
        # If the output file is not found for some reason
        return jsonify({"error": "Extraction successful, but output file not found."}), 500

if __name__ == "__main__":
    # Render provides the PORT environment variable
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
