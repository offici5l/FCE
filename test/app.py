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

logging.info("FCE Service starting.")

def run_extraction_task(task_id, url, file_to_extract):
    tasks[task_id]['status'] = 'running'
    app.logger.info(f"Task {task_id}: Running.")
    
    try:
        command = ["./entrypoint.sh", url, file_to_extract]
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        
        for line in iter(process.stdout.readline, ''):
            line = line.strip()
            if line:
                tasks[task_id]['log'].append(line)
        
        process.stdout.close()
        return_code = process.wait()
        
        if return_code == 0:
            output_filename = f"{file_to_extract}.zip"
            output_path = os.path.join("/workspace/output", output_filename)
            if os.path.exists(output_path):
                tasks[task_id]['status'] = 'finished'
                tasks[task_id]['output_file'] = output_path
                app.logger.info(f"Task {task_id}: Finished.")
            else:
                raise FileNotFoundError("Extraction succeeded, but output file was not found.")
        else:
            raise Exception(f"Extraction script failed with return code {return_code}.")

    except Exception as e:
        error_message = str(e)
        app.logger.error(f"Task {task_id}: Error: {error_message}")
        tasks[task_id]['log'].append(f"ERROR: {error_message}")
        tasks[task_id]['status'] = 'error'

@app.route('/')
def index():
    return "<h1>FCE Service</h1>"

@app.route('/extract', methods=['POST'])
def start_extract():
    data = request.get_json()
    if not data or 'url' not in data or 'file' not in data:
        app.logger.warning("Malformed request.")
        return jsonify({"error": "Missing parameters"}), 400

    task_id = str(uuid.uuid4())
    tasks[task_id] = {'status': 'pending', 'log': [], 'output_file': None}
    app.logger.info(f"Task {task_id}: Created.")
    
    thread = threading.Thread(target=run_extraction_task, args=(task_id, data['url'], data['file']))
    thread.start()
    
    return jsonify({"task_id": task_id})

@app.route('/status/<task_id>')
def stream_status(task_id):
    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    def generate():
        log_index = 0
        try:
            while True:
                while log_index < len(tasks[task_id]['log']):
                    log_line = tasks[task_id]['log'][log_index]
                    yield f"data: {log_line}\n\n"
                    log_index += 1

                status = tasks[task_id]['status']
                if status == 'finished':
                    yield f"event: done\ndata: Task finished.\n\n"
                    break
                elif status == 'error':
                    while log_index < len(tasks[task_id]['log']):
                        log_line = tasks[task_id]['log'][log_index]
                        yield f"data: {log_line}\n\n"
                        log_index += 1
                    yield f"event: error\ndata: Task failed. Check logs above.\n\n"
                    break
                
                time.sleep(1)

        except GeneratorExit:
            app.logger.info(f"Client disconnected from task {task_id} stream.")

    return Response(generate(), mimetype='text/event-stream')

@app.route('/download/<task_id>')
def download_file(task_id):
    if task_id not in tasks or tasks[task_id]['status'] != 'finished':
        return jsonify({"error": "File not ready or task not found"}), 404
    
    output_file = tasks[task_id]['output_file']
    dir_name, file_name = os.path.split(output_file)
    
    return send_from_directory(dir_name, file_name, as_attachment=True)

if __name__ == "__main__":
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
