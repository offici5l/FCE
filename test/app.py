import os
import subprocess
import logging
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)
CORS(app)

logging.info("FCE Service application starting up (Direct Mode)...")

@app.route('/')
def index():
    return "<h1>FCE Direct Service</h1><p>Ready to extract firmware content.</p>"

@app.route('/extract', methods=['POST'])
def extract_direct():
    app.logger.info("Received direct /extract request.")
    data = request.get_json()
    if not data or 'url' not in data or 'file' not in data:
        app.logger.warning("Malformed /extract request received.")
        return jsonify({"error": "Missing 'url' or 'file' parameters"}), 400

    rom_url = data['url']
    file_to_extract = data['file']

    # Define paths
    output_img_path = f"./output/{file_to_extract}.img"
    output_zip_path = f"./output/{file_to_extract}.zip"

    # --- Run the extraction script synchronously ---
    app.logger.info(f"Executing entrypoint.sh for URL: {rom_url}, File: {file_to_extract}")
    try:
        # Ensure the script is executable
        subprocess.run(['chmod', '+x', './entrypoint.sh'], check=True)

        process = subprocess.run(
            ['./entrypoint.sh', rom_url, file_to_extract],
            capture_output=True,
            text=True,
            check=True # Raise CalledProcessError if exit code is non-zero
        )
        app.logger.info("entrypoint.sh completed successfully.")
        app.logger.info(f"entrypoint.sh stdout:\n{process.stdout}")

    except subprocess.CalledProcessError as e:
        app.logger.error(f"entrypoint.sh failed with exit code {e.returncode}.")
        app.logger.error(f"entrypoint.sh stdout:\n{e.stdout}")
        app.logger.error(f"entrypoint.sh stderr:\n{e.stderr}")
        return jsonify({
            "error": "Extraction failed.",
            "log": e.stdout + e.stderr # Combine stdout and stderr for client
        }), 500
    except Exception as e:
        app.logger.error(f"An unexpected error occurred: {e}")
        return jsonify({"error": "An unexpected server error occurred.", "log": str(e)}), 500

    # --- Serve the final file ---
    if os.path.exists(output_zip_path):
        app.logger.info(f"Serving final file: {output_zip_path}")
        return send_from_directory(os.path.dirname(output_zip_path), os.path.basename(output_zip_path), as_attachment=True)
    else:
        app.logger.error(f"Final output file not found: {output_zip_path}")
        return jsonify({"error": "Extraction completed, but output file was not found.", "log": process.stdout}), 500

if __name__ == "__main__":
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
