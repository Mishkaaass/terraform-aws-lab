# Same UI assets as the venv route, packaged without state or tooling.
# Official Python 3.14.10 slim bookworm, verified multi-platform OCI index.
FROM python:3.14.10-slim-bookworm@sha256:3fe1a0b6c2d6b2ebb572906cdabeca75aeb558c0c17db5ffefbcf8094871c32b
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 INFRA_STUDIO_CONTAINER=1
WORKDIR /app
COPY engineering-lab/serve.py engineering-lab/index.html engineering-lab/app.js engineering-lab/style.css engineering-lab/missions.json /app/
USER 65532:65532
EXPOSE 8765
ENTRYPOINT ["python3", "-B", "/app/serve.py", "--bind", "0.0.0.0", "--port", "8765"]
