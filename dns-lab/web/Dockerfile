# The lab web page (see README.md). Runs with the host's Docker socket
# mounted, so it can list and start/stop the lab's containers; it is not
# attached to the dns-lab network.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app

# xterm.js for the terminals (#9), served from the image rather than a CDN
# so students' browsers only need to reach the lab. Pinned by checksum.
ADD --checksum=sha256:1f991ac3b4b283ebf96e60ae23a00a52765dd3a2e46fa6fdda9f1aab032f7495 \
    https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/lib/xterm.js app/static/vendor/xterm.js
ADD --checksum=sha256:ba8e6985669488981ccf40c0cefe3aba80722cb6c92de7ad628b0bd717faf2b6 \
    https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/css/xterm.css app/static/vendor/xterm.css
ADD --checksum=sha256:bdaefa370b1bfc42ee88d46fe6072400902a4d4b2d45cd93438dda9b23c97089 \
    https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.10.0/lib/addon-fit.js app/static/vendor/addon-fit.js
RUN chmod 644 app/static/vendor/*

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
