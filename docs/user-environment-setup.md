# ユーザー環境構築

本ドキュメントでは、ローカル開発環境の構築手順を説明する。

## システム要件

事前に以下のソフトウェアが利用可能な状態にしておくこと。

- `mise`
- PowerShell 7 (`pwsh`) ただし `infra/scripts` を実行する場合のみ必須

## 環境構築

### GTK+ Runtimeのインストール

weasyprintのPDF生成に必要なGTK+ Runtimeをインストールする。ローカルでPDFをビルドしないなら不要。

#### Windows

```pwsh
winget install --id tschoonj.GTKForWindows
```

#### Linux

```bash
sudo apt-get update
sudo apt-get install -y libpango-1.0-0 libpangoft2-1.0-0 libpangocairo-1.0-0 libcairo2 libgdk-pixbuf-2.0-0 libffi-dev fonts-noto-cjk fonts-noto-cjk-extra
```

#### macOS

```bash
brew install python pango libffi
```

### mise の導入

#### Linux / macOS

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
exec "$SHELL"
```

#### Windows

```pwsh
winget install jdx.mise
```

### Node.js & Pythonパッケージの導入

```shell
mise install
mise run setup
```

`mise.toml` では以下のツールバージョンを固定している。

- Python 3.13
- uv 0.9.17
- Node.js 24.12.0
- pnpm 10.27.0

### VS Code拡張

CIと同一ルールでリアルタイム校正を行う。

```shell
code --install-extension 3w36zj6.textlint
```
