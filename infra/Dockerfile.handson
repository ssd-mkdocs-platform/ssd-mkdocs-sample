FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# システムパッケージ（フォント・ブラウザ・レンダリング）
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

# code-server（ブラウザ版 VS Code）
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

USER vscode

# uv（Python パッケージマネージャー）
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/vscode/.local/bin:${PATH}"

# プロジェクトファイルのコピー（WORKDIR はディレクトリを root 所有で作成するため、先に mkdir する）
RUN mkdir -p /home/vscode/workspace
WORKDIR /home/vscode/workspace
COPY --chown=vscode:vscode . .

# Python 依存関係
RUN uv sync --frozen

# Node.js 依存関係
RUN corepack prepare pnpm@10.27.0 --activate \
    && pnpm install --frozen-lockfile

# VS Code 拡張機能（code-server 用）
RUN code-server --install-extension ms-python.python \
    && code-server --install-extension yzhang.markdown-all-in-one \
    && code-server --install-extension davidanson.vscode-markdownlint

EXPOSE 8080
ENTRYPOINT ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password", "/home/vscode/workspace"]
