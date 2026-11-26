# Same UI assets as the venv route, packaged without state or tooling.
# syntax=docker/dockerfile:1
# Same reviewed Python base and OS security patch levels as OpsBoard.
FROM python:3.14-slim@sha256:22eafb370920ad8b429e0aec3fff433e0669968519f5d60469d83729c138b28b

# Upgrade zlib1g to the Debian security-fixed package.
RUN apt-get update \
    && apt-get install -y --no-install-recommends --only-upgrade zlib1g

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get -o Acquire::Retries=0 update \
    && apt-get -o Acquire::Retries=0 install -y --no-install-recommends --only-upgrade \
       apt \
       libapt-pkg7.0 \
       gzip \
       libpcre2-8-0 \
       libsqlite3-0 \
       perl-base \
       libzstd1 \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' apt)" ge 3.0.4 \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libapt-pkg7.0)" ge 3.0.4 \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libzstd1)" ge 1.5.7+dfsg-1+deb13u1

# Studio is standard-library only; do not retain the installer and its vendored libraries.
RUN python -m pip uninstall --yes pip
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 INFRA_STUDIO_CONTAINER=1
WORKDIR /app
COPY engineering-lab/serve.py engineering-lab/index.html engineering-lab/app.js engineering-lab/style.css engineering-lab/missions.json /app/
USER 65532:65532
EXPOSE 8765
ENTRYPOINT ["python3", "-B", "/app/serve.py", "--bind", "0.0.0.0", "--port", "8765"]
