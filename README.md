# Dockerによる環境構築とmakeコマンドの使い方

このリポジトリは、ETロボコン向けにリポジトリルートをアプリ配置として開発し、
ルートの独自 `Makefile` から `asp.bin` を生成できるようにした構成です。

`spike-rt` 本体は `Dockerfile` のビルド時に自動で clone されます。

## 1) 環境構築

### 初回セットアップ

```bash
docker compose build
```

### 二回目以降

```bash
docker compose up -d
```

### Dockerの構成を変更した時、ついでに起動したいとき

```
docker compose up --build
```

## 2) プロジェクトのビルド(asp.binの生成)

```bash
docker compose run --rm builder make build
```

または、コンテナの中に入って仮想ターミナルでビルドをする方法もあります。

```bash
# コンテナの仮想ターミナルに入る
docker exec -it builder bash

# ビルドする
make build
```

Docker Desktopを使っている場合は
Container > etrobo2026_etrobo_workspace > builder > Exec
でコンテナのターミナルを使えます。
その場合も同様に`make build`を実行する。

既定では出力を簡略化しており、`building...` のような最小表示になります。
詳細ログを見たい場合は、以下を使ってください。

```bash
QUIET=0 make build
```

`make build` は内部でコンテナ内の `spike-rt` ビルドを実行し、
`asp.bin` をコンテナ内 `workspace` に生成します。

- `Makefile.inc` を読み込み
- ルート配下のすべての `*.cpp` をコンパイル
- `asp.bin` をコンテナ内 `workspace` に生成

## 3) 実機にasp.binをアップロード

実機へのアップロードを行う前に必ず`usb-setup.bat`を実行してください。
実行には以下のコマンドか、直接バッチファイルをダブルクリックで実行してください。

```bash
cmd /c ./usb-setup.sh
```

`make upload` はコンテナ内で `build` と `upload` を連続実行します。

```bash
docker compose run --rm builder make upload
```

`make upload-nobuild` は `asp.bin` が既に生成済みのときに、
ビルドを省略して `upload` だけを実行します。
`/opt/spike-rt/sdk/workspace/asp.bin` が無い場合は即エラー終了します。

```bash
docker compose run --rm builder make upload-nobuild
```

Windows + Docker Desktop の場合、USB デバイスを Linux 側へアタッチしていないと コンテナからは見えません。  
そのため、WindowsからDockerコンテナ(WSL)へのUSBのアタッチは、`usb-setup.bat`を利用します。  
