# Knotty コード徹底解説

## 1. プロジェクト全体像
- ランタイムの Typed Racket 実装は `knotty-lib/` に集約され、チャート生成・DSL・入出力・GUI まで同一言語で統一されています。モジュール公開は `knotty-lib/main.rkt` から行われており、利用側は単一 `require` で主要 API を取得できます。
- パターンデータは "ステッチ列"→"行仕様"→"パターン"→"チャート/テキスト出力" という層構造で保持され、各層にガード関数が挿入されています。これにより構築時点で編み物特有の制約違反を捕捉し、後段の描画や解析を安全にします。
- ドキュメントは `knotty/scribblings/` にまとめられ、Scribble により HTML マニュアルを生成します。特に `knotty/scribblings/io.scrbl:1` では各フォーマットの入出力制約と Knitspeak 変換時の仕様差分が整理されています。

## 2. 編み物制約のモデル化
### 2.1 ステッチ辞書と互換性フラグ
- ステッチ種別は `knotty-lib/stitch.rkt:31` の `Stitchtype` 構造体で表現され、目の幅・ケーブル有無・入出力本数・減目/増目のオフセット・反復可否に加え、手編み/機械編み互換フラグを保持します。`stitch-list` には 200 以上のステッチ定義が並び、各ステッチに対して適法チェックを可能にするメタデータを付与しています。
- 実際のパターンで参照されるステッチは `Stitch` 構造体（`knotty-lib/stitch.rkt:57`）により `Stitchtype` シンボルと使用糸 ID がペアになって保持されます。

### 2.2 ステッチ木構造（Tree）
- 1 行内のステッチ並びは `knotty-lib/tree.rkt:30` の木構造 `Tree` として保持されます。葉ノードは「回数×ステッチ」、節ノードは「回数×子ツリー」です。
- 制約として「可変回数（repeat count 0）は同時に 1 箇所のみ」「可変回数はネスト不可」を `tree-count-var` や `tree-nested-var?` 経由で判定し、`rowspec` ガードで例外化します。
- `leaf-stitches-in/out`（`knotty-lib/tree.rkt:78`）はステッチごとの消費/生成本数を抽象化し、後段の行整合性チェックで利用されます。

### 2.3 行仕様 Rowspec と短行制約
- 各行の仕様は `Rowspec`（`knotty-lib/rowspec.rkt:40`）に格納され、ガードで編成ルールを強制します。
  - 短行（wrap & turn）は行末の単一ステッチにしか置けない（`rowspec-guard-turns`、`knotty-lib/rowspec.rkt:78`）。
  - 可変リピートは 1 箇所のみ、かつノード直下に現れてはならない（`rowspec-guard-vars`、`knotty-lib/rowspec.rkt:115`）。
  - 行で使用する糸セットを自動カウントし、未定義糸の使用を防ぎます。

### 2.4 行番号とマッピング
- `Rows`（`knotty-lib/rows.rkt:40`）は複数行への適用を許容しますが、行番号はユニークかつソート済みでなければならず、欠番の行を組み立てられません。
- `Rowmap`（`knotty-lib/rowmap.rkt:34`）は行番号から `Rowspec` インデックスへの逆引きを生成し、行番号が 1 から連番であることを `rowmap-guard`（`knotty-lib/rowmap.rkt:48`）で確認します。フラット編みでの奇数/偶数行再利用も `rowmap-odd&even` で検出されます。

### 2.5 パターンガードによる総合チェック
- `Pattern` 構造体のガード（`knotty-lib/pattern.rkt:45`）は複数の compose された検証関数からなり、構築時に編み図全体の妥当性を検査します。
  - テクニック別制約: 手編み以外で短行を含むとエラー（`pattern-guard-options`、`knotty-lib/pattern.rkt:99`）。
  - 行 1 の短行禁止（`pattern-guard-turns`、`knotty-lib/pattern.rkt:137`）。
  - 糸定義・本数検証とゲージ vs 糸太さの警告出力（`pattern-guard-yarns`、`knotty-lib/pattern.rkt:170`）。
  - テクニック互換性: 行のステッチが手編み／機械編み指定に合致するかをチェック（`pattern-guard-stitch-compatibility`、`knotty-lib/pattern.rkt:241`）。
  - リピート行の範囲整合性（`pattern-guard-row-repeats`、`knotty-lib/pattern.rkt:403`）。
  - 行マップのソート・再構築（`pattern-guard-sort-rowmap`、`knotty-lib/pattern.rkt:461`）。
- パターン組み立て時には `pattern` 関数（`knotty-lib/pattern.rkt:499`）で `Rows` と `Yarn` を分類、`Rowspec` の bind-off シーケンス挿入や `Rowmap` 生成、`Rowcount` 計算が自動的に実行されます。

### 2.6 ステッチ本数整合と Diophantine 解法
- `Rowcount`（`knotty-lib/rowcount.rkt:38`）は各行の消費・産出本数、短行前後の固定領域を集約します。
- `make-rowcounts`（`knotty-lib/rowcount.rkt:78`）内では、行ごとの最少キャストオン数や短行調整量を計算するために線形 Diophantine 方程式を解きます。方程式ソルバは `knotty-lib/diophantine.rkt:25` の `diophantine` 系関数で実装され、最小の整数解を計算して可変リピート回数を導出します。
- これにより増減目や短行が混在しても、各行で必要なステッチ数が矛盾しないことを型安全に保証できます。

### 2.7 編み方向・面・側の一貫性
- `Options` 構造体（`knotty-lib/options.rkt:28`）は技法・編み方・編み始め位置を保持し、手編みでの左右逆転禁止などを `options-guard` で検出します。
- `options-row-rs?` や `options-row-r2l?`（`knotty-lib/options.rkt:74`）が行番号から自動的に RS/WS・編み方向を導出し、チャート生成とテキスト出力を統一します。

### 2.8 糸定義・色数
- 糸は `Yarn` 構造体（`knotty-lib/yarn.rkt:32`）で管理され、RGB 24bit・CYC 太さ・繊維などのメタデータとともに、色範囲と太さの妥当性をガードします。
- `pattern-guard-yarns` により、`Rowspec` が使用する糸番号が `Pattern` に登録済みか確認され、最大 256 色に制限されます。

### 2.9 リピート情報と短行展開
- `Repeats`（`knotty-lib/repeats.rkt:27`）は縦横リピートとキャストオン長を保持し、`pattern-make-repeats` と `pattern-expand-repeats` が `Pattern` を複製します。短行を含む場合の元行インデックス計算は `original-row-index`（`knotty-lib/repeats.rkt:41`）で処理されます。

### 2.10 チャート配置と短行アライン
- `pattern->chart`（`knotty-lib/chart.rkt:224`）は `Pattern` から `Chart` 行列を生成し、`chart-align-rows` で短行を含む複雑なケースにも対応した位置調整を行います。生産側・消費側のステッチ配列をスプライスしながらオフセットを半目単位で算出し、グラフィカルなズレを最小化しています。
- `Chart-row`（`knotty-lib/chart-row.rkt:31`）は行ごとのデフォルト糸・向き・アライン情報を保持し、PNG/HTML 出力で共通利用されます。

### 2.11 トポロジ表現（Knitgraph）
- 3D トポロジを扱う `Knitgraph` 系モジュール（`knotty-lib/knitgraph.rkt:31`）はループ・エッジ・糸のグラフ表現を提供します。ループの親子関係や引き方向、ケーブル深度を保持し、将来的な解析やシミュレーションの基盤となっています。

## 3. 処理フロー
### 3.1 DSL・マクロ層
- DSL の基本ステッチマクロは `knotty-lib/macros.rkt:1` で生成され、`Stitchtype` から Typed Racket マクロに展開することで記述ミスを防ぎます。可変リピートと固定リピートの両方をマクロ段階で区別し、型レベルで再利用可能な `Tree` フラグメントを返します。
- Knitspeak 文字列解析は `knitspeak-parser.rkt`（`knotty-lib/knitspeak-parser.rkt:1`）の Brag 文法とレキサにより AST を生成し、`interpret-pattern` 系マクロが Typed Racket の `pattern` 呼び出しへ変換します。
- Typed/Untyped 境界を扱うため、`knotty-lib/knitspeak.rkt:43` の shallow サブモジュールで `eval` を行い、型付きコンテキストへキャストしています。

### 3.2 パターン組み立て
- ユーザ入力（DSL, Knitspeak, PNG 変換）から得た `Rows` と `Yarn` は `pattern` 関数（`knotty-lib/pattern.rkt:499`）で標準化され、`Rowspec` へ BO* 挿入、`Rowmap` と `Rowcount` へ展開されます。この段階で全ガードが発火します。
- 短行やリピートの変換は `pattern-flat<->circular` 等の変換関数（`knotty-lib/pattern.rkt:665`）が担い、視覚チャートとテキスト指示の両方に反映されます。

### 3.3 チャート・テキスト・HTML
- `pattern->chart` で `Chart` を作成後、`knotty-lib/html.rkt:1` がテンプレートにパターン情報・チャート行列・糸情報を流し込み、インタラクティブな HTML を生成します。手順テキストは `stitch-instructions` ハッシュ（`knotty-lib/stitch-instructions.rkt:24` 以降）から取得します。
- PNG 出力は `knotty-lib/png.rkt:44` のフォント登録と描画パイプラインで行われ、Stitchmastery フォントを使ってチャートをビットマップ化します。

### 3.4 外部フォーマットとの橋渡し
- Knitspeak 変換は `pattern->ks` / `ks->pattern`（`knotty-lib/knitspeak.rkt:1`）で双方向を提供し、Knitspeak が許容しない構造とのギャップは文書化された制約差分に従います。
- XML やバンドル出力は `xml.rkt`, `export-bundle.rkt` で処理され、CLI (`knotty-lib/cli.rkt`) や GUI (`knotty-lib/gui.rkt`) から利用されます。

## 4. 実装上の難所と工夫
1. **短行を含むチャート整列** — `chart-align-rows`（`knotty-lib/chart.rkt:224`）は半目単位でのオフセット計算や反復展開を行い、短行列の折返し位置を視覚的に揃える複雑なヒューリスティクスを実装しています。
2. **可変リピートの整合性保証** — `Rowcount` と `diophantine` の組み合わせ（`knotty-lib/rowcount.rkt:78`、`knotty-lib/diophantine.rkt:25`）により、増減目を含む複雑な列でも最小解を探索しつつ安全なステッチ数を導出しています。
3. **Typed/Untyped 境界の取り扱い** — Knitspeak パーサは untyped Racket で定義されますが、`knitspeak.rkt` の shallow モジュールで型付き世界へ戻し、`Pattern` 型へキャストすることで型安全性と柔軟性を両立しています。
4. **ゲージと糸太さの現実的警告** — `pattern-guard-yarns`（`knotty-lib/pattern.rkt:170`）は Craft Yarn Council の基準を参照し、ゲージ情報との矛盾を警告レベルで通知します。完璧な自動判定は困難な領域をヒューリスティックで補っています。
5. **立体構造の表現** — `Knitgraph`（`knotty-lib/knitgraph.rkt:31`）と `Loop`（`knotty-lib/loop.rkt:25`）はループ同士の親子関係・引っ張り方向・ケーブル深さといった情報を明示的に持たせており、チャート記号の背後にある物理的構造を追跡できる点が高度です。

## 5. 追加リソースと読み進め方
- 入出力や制約の背景は `knotty/scribblings/io.scrbl:1` に詳細があります。Knitspeak との互換性が完全でない理由や、推奨ワークフローが整理されています。
- DSL を拡張したい場合は `knotty-lib/stitch.rkt:70` のステッチ辞書に追記し、`macros.rkt` のマクロ生成を更新するのが基本パターンです。
- 新しい輸出フォーマットを追加する際は、`pattern->chart` および `Rowcount` が提供する構造を再利用するのが最も安全であり、行アラインと糸情報を正しく扱うことが肝要です。

以上が、Knotty における編み物制約の表現方法、処理フロー、そして実装上の難所に関する徹底的な解説です。
