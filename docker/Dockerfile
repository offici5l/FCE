# Build stage - Installs all dependencies and tools
FROM python:3.11-slim as builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    aria2 \
    git \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Clone payload_dumper
RUN git clone https://github.com/vm03/payload_dumper.git /tools

# --- Final stage - A smaller image with only necessary files ---
FROM python:3.11-slim

# Install only runtime dependencies

RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    aria2 \
    git \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy tools and scripts from the builder stage
COPY --from=builder /tools /tools

# Install Python dependencies (bsdiff4 and others)
RUN pip install -r /tools/requirements.txt

# Download and extract erofs-utils
RUN aria2c -o erofs-utils.zip https://github.com/sekaiacg/erofs-utils/releases/download/v1.8.1-240810/erofs-utils-v1.8.1-gddbed144-Linux_x86_64-2408101422.zip \
    && 7z x erofs-utils.zip -o/tools \
    && rm -f erofs-utils.zip

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Add tools to the PATH
ENV PATH="/tools:${PATH}"

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]