# Lightweight SPIKE-RT Build Environment

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

下記のコマンドは 2 と同じようにコンテナの中で実行しますが、`uploader`というserviceを使います。

また、実機へのアップロードを行う前に必ず`usb-setup.sh`を実行してください。

```bash
sh ./usb-setup.sh
```

`make upload` は Windows ホスト時に USB attach を自動実行した後、
コンテナ内で `build` と `upload` を連続実行します。

```bash
docker compose run --rm uploader make upload
```

`make upload-nobuild` は `asp.bin` が既に生成済みのときに、
ビルドを省略して `upload` だけを実行します。
`/opt/spike-rt/sdk/workspace/asp.bin` が無い場合は即エラー終了します。

```bash
docker compose run --rm uploader make upload-nobuild
```

`make upload` 実行時は、通常の `builder` ではなく USB パススルー有効な
`uploader` service を使います（`privileged` + `/dev/bus/usb` マウント）。  

このリポジトリでは `builder` と `uploader` を分離したまま運用します。  
理由は、通常ビルドに `privileged` と USB マウントを持ち込まないためです。  

Windows + Docker Desktop の場合、USB デバイスを Linux 側へアタッチしていないと コンテナからは見えません。  
WindowsからDockerコンテナ(WSL)へのUSBのアタッチは、`usb-setup.sh`を利用します。  

`usbipd state` から Description に `LEGO` を含むデバイスを自動選択して、bind/attach した後、コンテナ内アップロードを実行します。

## make img

例:

```bash
APP_IMG=myapp make build
```
