# DL-078 document converter: LibreOffice, headless, behind a small
# authenticated HTTP server (server.py) that speaks the HttpDocumentConverter
# contract (packages/infrastructure/src/documentConverter.ts): POST /convert
# with the raw bytes and a bearer key, answered with the converted bytes.
# Private network only (fly.converter.test.toml); the server and LibreOffice
# run as the unprivileged `converter` user.
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Writer, Calc and Impress without the GUI and without Java (no
# recommends). Fonts: Noto (Latin, Arabic - Naskh, Sans, Kufi - and more),
# Amiri for Arabic documents, and the metric-compatible stand-ins for the
# Office fonts (Liberation for Arial/Times/Courier, Carlito for Calibri,
# Caladea for Cambria) so pages break where they did in Office.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libreoffice-writer-nogui \
    libreoffice-calc-nogui \
    libreoffice-impress-nogui \
    python3 \
    fonts-noto-core \
    fonts-noto-ui-core \
    fonts-hosny-amiri \
    fonts-liberation2 \
    fonts-crosextra-carlito \
    fonts-crosextra-caladea \
    fonts-dejavu-core \
    iptables \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --system --create-home --home-dir /home/converter \
    --shell /usr/sbin/nologin converter

# The build context is the repository root (fly.converter.test.toml lives
# there): docker build -f infra/converter/Dockerfile .
COPY infra/converter/server.py infra/converter/entrypoint.sh /app/
RUN chmod 0755 /app/server.py /app/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
