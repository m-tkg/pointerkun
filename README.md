<div align="center">
  <img src="Resources/AppIcon.png" alt="Pointerkun" width="128" height="128">

  # Pointerkun

  **マウスポインタの位置を見つけやすくする macOS メニューバー常駐ツール**
</div>

Pointerkun は、ホットキーひとつでポインタ位置にリップル（広がる円）を表示したり、ポインタの周りに半透明のハイライト円を常時重ねたりして、「いまカーソルどこ？」を解消する小さなメニューバーアプリです。デモ・プレゼン・大画面・マルチディスプレイ環境で特に役立ちます。

> **アクセシビリティ権限は不要**です。ホットキーは Carbon の `RegisterEventHotKey`、ポインタ追従は `NSEvent.mouseLocation` のポーリングで実現しており、入力監視の権限付与なしに動きます。

## 主な機能

- **ロケーター（リップル）** — ホットキー（既定 `⌃⌘P`）を押すと、カーソルを中心に円が広がるエフェクトを表示してポインタ位置を一瞬で示します。リップルはカーソル移動に追従します。
- **ハイライト円** — ホットキー（既定 `⌃⌘H`）でオン/オフ。ポインタの周りに半透明の円を常時表示します（デモ・プレゼン向け）。
- **見た目のカスタマイズ** — リップル／ハイライト円の色・大きさ・線の太さ・継続時間・不透明度を設定で変更できます。
- **マルチディスプレイ対応** — グローバル座標で扱うため、複数ディスプレイでも自然に表示されます。
- **自動アップデート** — GitHub Releases を起動時・定期・スリープ復帰時にチェックし、新版があればメニューバーアイコンの右下に赤バッジを表示。メニューからその場で自己更新できます。
- **ログイン時に自動起動**（設定の「一般」タブで切替）。
- **日英対応** — OS の優先言語に追従（en/ja、既定は en）。

## 動作環境

- macOS 13 (Ventura) 以降

## インストール

### リリース版を使う

1. [Releases](https://github.com/m-tkg/pointerkun/releases/latest) から `Pointerkun.zip` をダウンロードして展開します。
2. `Pointerkun.app` を `/Applications` に移動して起動します。
3. メニューバーに ◎ 風のアイコンが出れば常駐成功です（Dock アイコンは出ません）。

リリースビルドは Developer ID 署名＋公証済みです。万一 Gatekeeper に阻まれる場合は、Finder で `.app` を右クリック →「開く」を一度行ってください。

### 自分でビルドする

[ビルド](#ビルド) を参照してください。

## 使い方

| 操作 | 既定のホットキー | 内容 |
| --- | --- | --- |
| リップル表示 | `⌃⌘P` | カーソル位置に広がる円を表示 |
| ハイライト円 ON/OFF | `⌃⌘H` | ポインタ追従の半透明円を切替 |

メニューバーのアイコンをクリックすると、次のメニューが開きます。

- 先頭にバージョン表示（操作不可）
- **設定…**（`⌘,`）
- **アップデートを確認…**（新版があれば「アップデート v… をインストール…」に変化）
- **Pointerkun を終了**（`⌘Q`）

### 設定

設定はメニューの「設定…」から開くダイアログに集約されています（タブ構成）。各コントロールの変更は**即時反映**されます。

- **一般** — ログイン時の自動起動トグル、バージョン表示。
- **ハイライト円** — 有効/無効、表示切替ホットキー、色、直径。
- **ロケーター** — 発火ホットキー、リップルの色、最大直径、線の太さ、継続時間。

ホットキーは各タブの「キーを押してください…」ボタンを押してから、修飾キー付きのキーを入力して登録します（`Esc` でキャンセル）。

## アップデートのしくみ

- 起動時に加えて、`Timer` による定期サイレントチェック（GitHub 未認証 API のレート制限 60 回/時を踏まえた間隔）と、`NSWorkspace.didWakeNotification` による**スリープ復帰時の即チェック**を行います。
- 新版を検知すると、メニュー文言が変わるとともに**メニューバーアイコン右下に赤バッジ（小さな赤丸）**が出ます。最新になると消えます。
- メニューから自己更新を選ぶと、zip をダウンロード → 展開 → バンドル ID 検証 → 旧プロセス終了待ち → 入替 → 再起動まで自動で行います。

## ビルド

[Swift Package Manager](https://www.swift.org/package-manager/) ベースで、Xcode プロジェクトは持ちません。

```sh
# ビルド
swift build

# テスト（純粋ロジック PointerkunCore）
swift test

# .app バンドルを作る（既定: release・Developer ID 署名）
bash Scripts/bundle.sh release

# ローカル検証ビルド（本番と TCC 権限が衝突しないよう別バンドルID/表示名）
LOCAL=1 bash Scripts/bundle.sh debug

# 証明書が無い環境はアドホック署名にフォールバック
AD_HOC=1 bash Scripts/bundle.sh release
```

- ローカル検証ビルドは bundle ID が `com.mtkg.pointerkun.local`、表示名が `Pointerkun (Local)` になり、メニューバーに「ローカル」と併記されます。
- ローカルビルドは**署名はされるが公証はされません**（公証は CI のリリースビルドのみ）。

## アーキテクチャ

純粋ロジックとプラットフォーム依存を 2 ターゲットに分離しています。

- **`PointerkunCore`**（ライブラリ／テスト対象） — AppKit/Carbon に依存しないモデルとロジック。
  - `Settings` / `SettingsStore`（JSON 永続化、欠損キーを既定値で補完）
  - `RGBAColor` / `HighlightSettings` / `RippleSettings`
  - `HotKeyConfig`（キーコード＋Carbon 修飾＋表示ラベル）
  - `OverlayGeometry`（点を中心にウィンドウ原点を算出）
  - `ReleaseInfo` / `VersionComparator`（アップデート用）
- **`Pointerkun`**（実行ファイル） — メニューバー常駐 UI、オーバーレイ描画、ホットキー、ポインタ追従、設定 UI、自己更新。
  - オーバーレイは透明・最前面・クリックスルーの borderless `NSWindow`、円の描画は `CAShapeLayer` + `CABasicAnimation`。
  - メニューバー常駐（`LSUIElement`）で Dock アイコンなし。同じ bundle ID の多重起動を防止します。

純粋ロジックは TDD（テスト先行）、UI/OS 連携は実機で手動確認する方針です。

## kuntraykun 連携

複数の「〜kun」アプリのメニューバーアイコンを 1 つに集約するハブ [kuntraykun](https://github.com/m-tkg/kuntraykun) に対応しています。kuntraykun に管理対象として選ばれている間は自分のアイコンを隠し、kuntraykun のアイコンから本アプリのメニューを開けます（分散通知で連携）。

## リリース

`Resources/Info.plist` の `CFBundleShortVersionString` を上げて `main` に push すると、GitHub Actions が `v<version>` のタグとリリース（署名＋公証済み zip）を自動作成します（同名リリースがあればスキップ）。

## コントリビューション

変更は必ず `main` から切ったブランチで行い、Pull Request 経由でマージします（`main` への直接 push は禁止）。

---

<div align="center">
  <sub>Pointerkun — find your cursor, instantly.</sub>
</div>
