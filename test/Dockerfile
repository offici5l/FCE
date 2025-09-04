FROM python:3.11-slim

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    aria2 \
    git \
    zip \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/vm03/payload_dumper.git /tools

RUN aria2c -o erofs-utils.zip https://github.com/sekaiacg/erofs-utils/releases/download/v1.8.1-240810/erofs-utils-v1.8.1-gddbed144-Linux_x86_64-2408101422.zip \
    && 7z x erofs-utils.zip -o/tools \
    && rm -f erofs-utils.zip

ENV PATH="/tools:${PATH}"

RUN pip install --no-cache-dir -r /tools/requirements.txt

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY entrypoint.sh .

RUN chmod +x ./entrypoint.sh

EXPOSE 8080

CMD ["python", "-u", "app.py"]
