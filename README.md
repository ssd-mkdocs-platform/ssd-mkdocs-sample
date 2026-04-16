# 生成AI時代のドキュメント基盤

生成AI時代におけるドキュメント基盤テンプレート。

人が書きやすく読みやすい Markdown を中心に、`MkDocs`、Mermaid、Draw.io、Marp、PDF 出力を組み合わせた文書基盤のサンプルである。主役はサンプル本体であり、`.devcontainer/` や `infra/` 配下にはこのリポジトリ専用の開発・配布環境を同居させている。

- デモサイト
  - [GitHub Pages](https://genai-docs.github.io/genai-mkdocs-sample/)
  - [Azure Static Web Apps](https://white-stone-0b8d2c100.4.azurestaticapps.net/)

## 最短セットアップ

ローカル開発では `mise` を共通のエントリポイントとして利用する。初回セットアップは次の通り。

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
exec "$SHELL"
mise install
mise run setup
```

主なコマンド:

```bash
mise run mkdocs
mise run mkdocs:build
mise run mkdocs:build:svg
mise run mkdocs:pdf
mise run lint:text
mise run infra:test
mise run infra:deploy-handson-env -- -UserCount 20
```

## リポジトリ構成

- サンプル本体: `docs/`, `mkdocs.yml`, `pyproject.toml`, `package.json`, `mise.toml`
- ローカル開発環境: `.devcontainer/`, `infra/docker/`
- ハンズオン運用: `infra/azure/`, `infra/scripts/`, `settings.template.json`

## 詳細ドキュメント

- [ドキュメントサイトのホーム](docs/index.md)
- [利用方法](docs/usage-guide.md)
- [ユーザー環境構築](docs/user-environment-setup.md)
- [実行環境の概要](docs/実行環境/index.md)
- [ハンズオン環境設計](docs/実行環境/handson.md)
- [ハンズオン環境情報](docs/実行環境/environment.md)

## 補足

ビルド済みイメージをローカルで実行する場合は、以下のように `docker run` を利用する。

```bash
docker run --rm -it \
  -p 8080:8080 \
  -e PASSWORD=changeme \
  spec-driven-docs-infra:latest
```

起動後は `http://localhost:8080` にアクセスし、指定したパスワードで `code-server` にログインする。
