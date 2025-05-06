# Shiritolua

Discord 上でしりとりを管轄する Bot です。

## Requirements

+ [luvit/luvit](https://luvit.io/)
+ [SinisterRectus/discordia](https://github.com/SinisterRectus/Discordia)


## Quick Start

```bash
git clone git@github.com:plageoj/shiritolua.git
cd shiritolua
cp config.lua.sample config.lua
vim config.lua # See below
curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh
./lit install
./luvit boot.lua
```

## Deploy to Heroku

```bash
heroku create [YOUR_APP_NAME] --buildpack https://github.com/squeek502/heroku-buildpack-luvit.git
heroku config:set SHIRITOLUA_CONFIG=`cat config.lua`
git push heroku master
```

## Configurations

`config.lua.sample` が設定ファイルのテンプレートです。
`config.lua` にリネームして使用してください。

Heroku では環境変数 `SHIRITOLUA_CONFIG` に記述してください。

### `yomiApiId` (string)

[Yahoo! JAPAN Web API](https://e.developer.yahoo.co.jp/dashboard/) のアプリケーション ID を記述します。

### `discordBotToken` (string)

[Discord Applications](https://discordapp.com/developers/applications/) → Bot から Token を取得して記述します。

Bot の設定から Message Content Intent を有効にしてください。

### `reactChannels` { (string)... }

チャンネルIDを指定します。指定以外のチャンネルには反応しません。
チャンネルIDはブラウザ版 [Discord](https://discordapp.com) を開き、チャンネルにアクセスしたときのURL末尾の数字です。

### `maxWords` (number)

受け付ける最大文節数です。
これより多くの文節になると「長すぎです。」と返答します。

### `historyLength` (number)

過去の出現語句をこの件数まで記憶します。この件数を超えたら重複を許します。

### `shibariThreshold` (number)

文字縛り・音数縛りの閾値を設定します。
同じ文字/同じ音数がこの回数を超えて続くと縛りが発生します。

### `shibariLasts` (number)

縛りの持続時間を設定します。単位は分ですが、小数も使用できます。
