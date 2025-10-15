# Knotty

ニッティングパターンのためのドメイン特化言語 (Domain Specific Language)

[![Coverage Status](https://coveralls.io/repos/github/t0mpr1c3/knotty/badge.svg?branch=main)](https://coveralls.io/github/t0mpr1c3/knotty?branch=main)

[ドキュメント](https://t0mpr1c3.github.io/knotty/index.html)

## 概要

Knotty は格子状の配色デザインと、レース編みで多用されるテキストベースの記述を統合することを目的にしたツールです。テクスチャのある編み目と複数色の糸を併用するパターンを、読みやすく・加工しやすい形式で記述できます。

## 特長

- パターンは人間が手で書きやすく、かつ機械で正確に解析できる形式で保存されます。
- インタラクティブな編み図と文章化された手順を含む HTML として表示・保存が可能です。
- Knitspeak 形式のインポート／エクスポートや、画像からのフェアアイルパターン生成をサポートしています。
- 実装は [Typed Racket](https://docs.racket-lang.org/ts-guide/) 上のモジュール群として構成されており、詳細は [マニュアル](https://t0mpr1c3.github.io/knotty/index.html) を参照できます。
- コマンドライン実行可能ファイル ([リリースページ](https://github.com/t0mpr1c3/knotty/releases)) から各形式の変換が行えます。最新版では HTML / XML に加え、静的な PNG チャートも書き出せます。
- `--export-bundle` フラグを使うと HTML / XML / テキスト指示 / PNG をまとめて生成できます。

例: XML を読み込み、チャートを PNG として出力する

```
racket knotty-lib/cli.rkt \
  --import-xml --export-png \
  --output lattice-chart \
  knotty-lib/resources/example/lattice
```

実行すると `lattice-chart.png` と、必要な CSS / JS アセットがカレントディレクトリにコピーされます。

複数形式をまとめて書き出す場合は `--export-bundle` を利用します。

```
racket knotty-lib/cli.rkt \
  --import-xml --export-bundle --force \
  --output exports/lattice \
  knotty-lib/resources/example/lattice
```

`exports/` 配下に `lattice.html / lattice.xml / lattice.txt / lattice.png` が生成され、HTML に必要なアセットも同じディレクトリに複製されます。

## Racket からの変換例

Racket スクリプトから直接変換処理を呼び出すこともできます。以下は `knotty-lib/resources/example/lattice.xml` を利用した例です。

```racket
#lang racket
(require knotty-lib)

(define pattern
  (import-xml "knotty-lib/resources/example/lattice.xml"))

;; 元の XML を別名で保存
(export-xml pattern "lattice-copy.xml")

;; 編み図と指示文を含む HTML を出力
(export-html pattern "lattice.html" 1 1)

;; PNG チャートを出力（横 2 × 縦 2 の繰り返し）
(export-png pattern "lattice.png" #:h-repeats 2 #:v-repeats 2)

;; 4 形式をまとめて出力（HTML / XML / テキスト / PNG）
(export-pattern-bundle pattern "output"
                       #:basename "lattice"
                       #:overwrite? #t
                       #:h-repeats 2
                       #:v-repeats 2)
```

## はじめ方

1. [リポジトリ](https://github.com/t0mpr1c3/knotty) をクローンします。
2. [Racket](https://download.racket-lang.org/) の最新版をインストールします（GUI 版には DrRacket が同梱されています）。
3. DrRacket を開き、メニューから「File > Install Package」を選択し、`knotty` を入力して「Install」を押します。
4. リポジトリ内 `knotty-lib` ディレクトリにある `demo.rkt` を開き、右上の「Run」を押します。短いサンプルパターンと、独自のパターンを作る際の手順を説明したコメントが含まれています。

これで、自分のパターンを HTML / XML / PNG として自由に出力できる環境が整います。
