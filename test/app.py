import os
import subprocess
import uuid
import threading
import time
import logging
from flask import Flask, request, jsonify, Response, send_from_directory
from flask_cors import CORS

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

tasks = {}

app = Flask(__name__)
CORS(app)

logging.info("FCE Service application starting up...")

def run_extraction_task(task_id, url, file_to_extract):
    tasks[task_id]['status'] = 'running'
    app.logger.info(f"Task {task_id}: Status set to 'running'. Starting script...")
    
    try:
        command = ["./entrypoint.sh", url, file_to_extract]
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        
        for line in iter(process.stdout.readline, ''):
            line = line.strip()
            if line:
                app.logger.info(f"Task {task_id} Log: {line}")
                tasks[task_id]['log'].append(line)
        
        process.stdout.close()
        return_code = process.wait()
        
        if return_code == 0:
            output_filename = f"{file_to_extract}.zip"
            output_path = os.path.join("/workspace/output", output_filename)
            if os.path.exists(output_path):
                tasks[task_id]['status'] = 'finished'
                tasks[task_id]['output_file'] = output_path
                app.logger.info(f"Task {task_id}: Status set to 'finished'.")
            else:
                raise FileNotFoundError("Extraction succeeded, but output file was not found.")
        else:
            raise Exception(f"Extraction script failed with return code {return_code}.")

    except Exception as e:
        error_message = str(e)
        app.logger.error(f"Task {task_id}: An exception occurred: {error_message}")
        tasks[task_id]['log'].append(f"ERROR: {error_message}")
        tasks[task_id]['status'] = 'error'

@app.route('/')
def index():
    return "<h1>FCE Live Streaming Service (v3)</h1><p>Ready to extract firmware content.</p>"

@app.route('/extract', methods=['POST'])
def start_extract():
    app.logger.info(f"Received /extract request.")
    data = request.get_json()
    if not data or 'url' not in data or 'file' not in data:
        app.logger.warning("Malformed /extract request received.")
        return jsonify({"error": "Missing 'url' or 'file' parameters"}), 400

    task_id = str(uuid.uuid4())
    tasks[task_id] = {'status': 'pending', 'log': [], 'output_file': None}
    app.logger.info(f"Created new task with ID: {task_id}")
    
    thread = threading.Thread(target=run_extraction_task, args=(task_id, data['url'], data['file']))
    thread.start()
    
    return jsonify({"task_id": task_id})

@app.route('/status/<task_id>')
def stream_status(task_id):
    app.logger.info(f"Request received for status stream for task: {task_id}")
    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    def generate():
        log_index = 0
        try:
            while True:
                if tasks[task_id]['status'] in ['finished', 'error']:
                    break
                while log_index < len(tasks[task_id]['log']):
                    log_line = tasks[task_id]['log'][log_index]
                    yield f"data: {log_line}\n\n"
                    log_index += 1
                time.sleep(1)
            
            status = tasks[task_id]['status']
            if status == 'finished':
                app.logger.info(f"Task {task_id}: Sending 'done' event to client.")
                yield f"event: done\ndata: Task finished successfully.\n\n"
            elif status == 'error':
                app.logger.info(f"Task {task_id}: Sending 'error' event to client.")
                yield f"event: error\ndata: Task failed.\n\n"

        except GeneratorExit:
            app.logger.info(f"Client disconnected from task {task_id} stream.")

    return Response(generate(), mimetype='text/event-stream')

@app.route('/download/<task_id>')
def download_file(task_id):
    app.logger.info(f"Request received for download for task: {task_id}")
    if task_id not in tasks or tasks[task_id]['status'] != 'finished':
        return jsonify({"error": "File not ready or task not found"}), 404
    
    output_file = tasks[task_id]['output_file']
    dir_name, file_name = os.path.split(output_file)
    
    return send_from_directory(dir_name, file_name, as_attachment=True)

if __name__ == "__main__":
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
