# Lightweight SPIKE-RT Build Environment

このリポジトリは、ETロボコン向けに `app/` を中心に開発し、
ルートの独自 `Makefile` から `asp.bin` を生成できるようにした構成です。

`spike-rt` 本体は `Dockerfile` のビルド時に自動で clone されます。

## 1) Build Docker image

```bash
docker compose build
```

## 2) Build (`asp.bin` generation)

```bash
make build
```

既定では出力を簡略化しており、`building...` のような最小表示になります。
詳細ログを見たい場合は、以下を使ってください。

```bash
QUIET=0 make build
```

`make build` は内部でコンテナ内の `spike-rt` ビルドを実行し、
`asp.bin` をコンテナ内 `workspace` に生成します。

ホストに `make` が無い場合は、以下で `spike-rt` の標準ビルドを直接実行できます。

```bash
docker compose run --rm builder make img=kait-etrobocon2026
```

この場合も、`asp.bin` はコンテナ内 `workspace` に生成されます。

- `app/Makefile.inc` を読み込み
- `app/` 直下のすべての `*.cpp` をコンパイル
- `asp.bin` をコンテナ内 `workspace` に生成

## 3) Clean

```bash
make clean
make realclean
make distclean
```

## 4) Upload (optional)

```bash
make upload
```

## Variables

- `APP_IMG`:
  - コンテナ内で `app/` をマウントする `sdk/workspace` 配下のフォルダ名
  - デフォルトは `kait-etrobocon2026`

例:

```bash
APP_IMG=myapp make build
```
