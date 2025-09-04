# Use a slim Python image as the base
FROM python:3.11-slim

# Set the primary working directory for the container
WORKDIR /workspace

# --- Install System Dependencies ---
# Install tools required for the extraction process
RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    aria2 \
    git \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# --- Install FCE Tools ---
# Clone the payload_dumper tool
RUN git clone https://github.com/vm03/payload_dumper.git /tools

# Download and extract erofs-utils
RUN aria2c -o erofs-utils.zip https://github.com/sekaiacg/erofs-utils/releases/download/v1.8.1-240810/erofs-utils-v1.8.1-gddbed144-Linux_x86_64-2408101422.zip \
    && 7z x erofs-utils.zip -o/tools \
    && rm -f erofs-utils.zip

# Add the tools to the system's PATH
ENV PATH="/tools:${PATH}"

# --- Install Python Dependencies ---
# Install dependencies for payload_dumper
RUN pip install --no-cache-dir -r /tools/requirements.txt

# Copy the web service requirements file into the workspace
COPY requirements.txt .

# Install dependencies for the Flask web service
RUN pip install --no-cache-dir -r requirements.txt

# --- Copy Application Files ---
# Copy the Flask app and the entrypoint script into the workspace
COPY app.py .
COPY entrypoint.sh .

# Make the entrypoint script executable
RUN chmod +x ./entrypoint.sh

# --- Set up Container Command ---
# Expose the port the app runs on
EXPOSE 8080

# Command to run the Flask application
# The -u flag ensures that logs are sent straight to stdout without being buffered
CMD ["python", "-u", "app.py"]