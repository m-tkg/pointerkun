# CLAUDE.md — pointerkun

このリポジトリで作業する際のガイド。

**メニューバー常駐アプリ（kun シリーズ）共通の方針は上位ディレクトリの [`../kun-template/CLAUDE_base.md`](../kun-template/CLAUDE_base.md) を参照**
（Swift Package 構成・日英ローカライズ・アップデート・kunkit 連携・リリース手順・ブランチ運用など）。
共通方針を変えるときは `CLAUDE_base.md`（[kun-template](https://github.com/m-tkg/kun-template) が canonical）を編集する。
本ファイルには pointerkun 固有の事項のみを記す。

---

# pointerkun 固有事項

マウスポインタの位置を見つけやすくする macOS メニューバー常駐ツール。
共通方針は本ファイル後半の「CLAUDE_base.md」を踏襲する。以下は pointerkun 固有の事項。

## 機能
1. **ロケーター（リップル）**: ホットキーを押すと、マウスカーソルを中心に円が広がるエフェクトを表示しポインタ位置を可視化する。ホットキーは設定で変更可能。
2. **ハイライト円**: ポインタの周りに半透明の円を常時表示する（デモ・プレゼン向け）。設定で有効/無効。
3. **見た目のカスタマイズ**: ハイライト円・リップルの色／大きさ／不透明度を設定で変える。

## 設計上の要点
- **アクセシビリティ権限は不要**。ホットキーは Carbon `RegisterEventHotKey`（権限不要）、ポインタ追従は `Timer` で `NSEvent.mouseLocation` をポーリング（権限不要）。keykun の CGEventTap は使わない。
- オーバーレイは透明・最前面・クリックスルーの borderless `NSWindow`（`level = .statusBar`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`, `backgroundColor = .clear`, `isOpaque = false`）。keykun の `HUDController` が雛形。
- 円の描画は `CAShapeLayer` + `CABasicAnimation`（リップル）。マルチディスプレイは `NSEvent.mouseLocation` のグローバル座標で自然対応。
- 真の「システムカーソルそのものの色・サイズ変更」は公開 API では全画面に渡って実現困難。本アプリはハイライト円でそれを代替する。
- bundle ID は `com.mtkg.pointerkun`。Core モジュールは `PointerkunCore`、リソースバンドルは `Pointerkun_Pointerkun.bundle`。
- **アップデートの定期監視＋赤バッジ**（CLAUDE_base.md 「### 4」のバッジ実装方針を踏襲）:
  - 監視は `AppDelegate` に集約。起動時の `startUpdateCheck(interactive:false)` に加え、`startUpdateMonitoring()` で
    `Timer`（既定 6 時間・`tolerance` 10%、`MainActor.assumeIsolated` でチェック呼び出し）＋
    `NSWorkspace.didWakeNotification`（復帰時に即チェック）を配線する。間隔は GitHub 未認証 API の 60回/時 を踏まえる。
  - 赤バッジは `StatusBarController.setupBadge(on:)` で `statusItem.button` に `NSView`＋`CALayer` の赤丸を
    オーバーレイ。ベースアイコンは `isTemplate = true` のまま維持し、Auto Layout で**アイコン画像の幅基準**の右下に固定
    （`leading = button.leading + (iconWidth - badgeSize)`, `bottom = button.bottom`、白の細い縁取り付き）。
  - 表示/非表示は更新有無の集約点 `setUpdateAvailable`（→表示）/ `clearUpdateAvailable`（→非表示）に
    `badgeView.isHidden` トグルとして置き、起動・定期・手動の全チェック経路で同期させる。
  - 既知の制約: kuntraykun に集約され `setManagedHidden(true)` で自分のアイコンを隠している間はバッジも見えない
    （集約先への伝搬は連携プロトコルの拡張が必要）。

## Core（TDD 対象）に置くもの
- `Settings` / `SettingsStore`（JSON 永続化、欠損キー補完）
- `RGBAColor`（色の Codable 表現）、`HighlightSettings` / `RippleSettings`
- `HotKeyConfig`（keyCode + Carbon modifiers + 表示ラベル、`modifierSymbols` は純粋関数）
- `OverlayGeometry`（点を中心にウィンドウ原点を算出）
- `ReleaseInfo` / `VersionComparator`（アップデート用）

---

## Kuntraykun 連携（実装済み・kunkit 利用）

本アプリは kuntraykun（`com.mtkg.kuntraykun`）にメニューバーアイコンを集約させる連携（v1〜v4:
アイコン集約・実アイコン書き出し・アップデート集約・サブメニュー表示）に対応している。
- **実装は共有ライブラリ [kunkit](https://github.com/m-tkg/kunkit)**（SPM 依存、`KunIntegrationBridge` プロダクト）。
  `KuntraykunBridge` / `KuntraykunIconExport` / `KuntraykunMenuExport` を提供し、アプリ側に連携ロジックの複製は持たない。
- 配線: `StatusBarController.makeKuntraykunBridge()`（`KuntraykunBridge(statusItem:menu:)` の標準配線）を
  `AppDelegate` が `bridge.start()` する。start() が観測開始・`appLaunched` 送信・初回メニュー書き出しまで行う。
  アイコン書き出し（v2）は `StatusBarController` init の `KuntraykunIconExport.export(_:)`、
  アップデート報告（v3）は `kuntraykunBridge?.reportUpdate(_:)`、
  メニュー文言の変化（v4）は `statusBar.onMenuContentChanged` → `bridge.exportMenuSnapshot()`（表示中は自動保留）。
- 仕様: kuntraykun リポジトリ `docs/kun-integration-protocol.md`、共通方針は `../kun-template/CLAUDE_base.md`「Kuntraykun 連携」。
- 管理対象フラグは kunkit が `UserDefaults`（キー `KuntraykunManaged`）に永続化する。
- **kunkit 由来の共通実装**: 自己更新（`SelfUpdater`）・ログイン項目（`LoginItemController`）・多重起動防止（`KunAppLaunch`、`main.swift`）・設定永続化（`KunSettingsStore`）・外部プロセス実行（`ProcessRunner`）・更新チェック（`GitHubReleaseFetcher` / `ReleaseInfo` / `VersionComparator` / `KunUpdateSchedule` / `ReleaseDownloader`）は kunkit（`KunAppKit` / `KunSupport` / `KunUpdateKit`）が提供する。アプリ側に複製は持たず、アプリ名・文言・repo は注入する。
- **kunkit の更新運用**: 連携プロトコルの変更・修正は kunkit 側（TDD）で行って semver タグを発行し、
  各アプリは `swift package update kunkit` で追従する（`from: "1.0.0"` 指定のため 1.x は自動追従、
  破壊的変更はメジャーを上げる）。本リポジトリは `Package.resolved` を追跡しているので、
  更新時は resolved の変更もコミットする。
- **連携のデバッグ**: まず `~/Library/Application Support/Kuntraykun/Menus/<基底ID>.json` の中身
  （空なら書き出し側の問題）と、Console の subsystem `com.mtkg.pointerkun` / category `kuntraykun` の
  ログを確認する。
