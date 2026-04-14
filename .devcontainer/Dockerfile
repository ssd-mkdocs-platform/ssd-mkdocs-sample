FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

RUN rm -f /etc/apt/sources.list.d/yarn.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        chromium \
        libpango-1.0-0 \
        libpangoft2-1.0-0 \
        libpangocairo-1.0-0 \
        libcairo2 \
        libgdk-pixbuf2.0-0 \
        libharfbuzz0b \
        libfontconfig1 \
        libffi8 \
        shared-mime-info \
        fonts-noto-cjk \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

USER vscode

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH=/home/vscode/.local/bin:${PATH}
