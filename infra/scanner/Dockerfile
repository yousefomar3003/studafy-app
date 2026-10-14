# FILE-051 malware scanner: ClamAV behind a small authenticated HTTP API that
# speaks the ExternalMalwareScannerClient contract
# (packages/infrastructure/src/fileScanner.ts): POST /scan with the raw bytes
# and a bearer key, answered with {"clean": true|false}. clamd listens only on
# loopback; the HTTP server on 8080 is the only way in.
FROM clamav/clamav-debian:1.4

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i -E '/^[[:space:]]*(TCPSocket|TCPAddr|StreamMaxLength|MaxFileSize|MaxScanSize|ConcurrentDatabaseReload)([[:space:]]|$)/d' /etc/clamav/clamd.conf \
  && printf '%s\n' \
    'TCPSocket 3310' \
    'TCPAddr 127.0.0.1' \
    'StreamMaxLength 50M' \
    'MaxFileSize 50M' \
    'MaxScanSize 200M' \
    'ConcurrentDatabaseReload no' \
    >> /etc/clamav/clamd.conf

COPY server.py entrypoint.sh /app/
RUN chmod 0755 /app/server.py /app/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
