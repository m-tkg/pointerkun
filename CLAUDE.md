# pointerkun — プロジェクト固有メモ

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

# CLAUDE_base.md — メニューバー常駐アプリ作成の共通ガイド

snapperkun / whisperkun / keykun の知見をまとめた、macOS タスクトレイ（メニューバー常駐）
アプリを新規作成する際の共通方針。新規プロジェクトの `CLAUDE.md` はこれをベースに、
プロジェクト固有の事項を足して作る。

## 基本構成

- **Swift Package Manager** の 2 ターゲット構成。**純粋ロジックとプラットフォーム依存を分離**する。
  - `<Name>Core`（ライブラリ / テスト対象）: AppKit/Carbon/AX/CGEventTap に依存しないロジックとモデル。
    判定ロジックは時刻などを注入する純粋関数/状態機械にして **TDD（テスト先行）** で実装する。
  - `<Name>`（実行ファイル）: AppKit/SwiftUI/各種 OS 連携と UI。
- **メニューバー常駐**（Dock アイコンなし）。`Info.plist` に `LSUIElement = true`、
  `main.swift` で `NSApplication` を `.accessory` 起動（`MainActor.assumeIsolated`）。
- **多重起動防止**: 起動時に同じ bundle ID の他インスタンスがあれば、それを前面化して自分は `exit(0)`。
- `.app` 化は `Scripts/bundle.sh`（`swift build` → バンドル組み立て → 署名）。Xcode プロジェクトは持たない。
- リリースは GitHub Actions（`.github/workflows/release.yml`）。`Info.plist` の
  `CFBundleShortVersionString` を上げて `main` にマージした後、`make release-tag` で
  `v<version>` タグを作成・push すると CI がビルド・署名・公証してリリースを自動作成する
  （`main` へのマージだけではリリースされない。同名リリースがあればスキップ）。

---

## 必須チェックリスト

### 1. Secrets は `setup-release-secrets.sh` で登録する
配布用の署名＋公証の Secrets（計6つ）は、上位ディレクトリの **`setup-release-secrets.sh`** で一括登録する。
```sh
~/git/github.com/m-tkg/setup-release-secrets.sh -r m-tkg/<repo>
```
- 署名: `SIGNING_IDENTITY` / `SIGNING_CERTIFICATE_PASSWORD` / `SIGNING_CERTIFICATE_P12_BASE64`
- 公証: `NOTARY_APPLE_ID` / `NOTARY_PASSWORD` / `NOTARY_TEAM_ID`
- 署名は Developer ID Application（Team ID `G72M73C546`）。**安定署名でアクセシビリティ権限(TCC)が
  アップデート越しに保持される**（ad-hoc は毎回変わり無効化される）。
- ワークフローは Secrets が無ければ ad-hoc 署名／公証スキップにフォールバックする。
- `setup-release-secrets.sh` は秘密鍵(.p12)を含むので**リポジトリにコミットしない**（上位ディレクトリは git 管理外）。

### 2. すべての UI を日英対応にする
GUI 文字列は **日本語・英語の 2 言語**に対応し、OS の優先言語に追従する（既定 `en`）。
- 文字列リテラルを `Text`/`Button`/`NSMenuItem`/`NSAlert`/ウィンドウタイトル/HUD 等に直接渡さない。
  `Resources/{en,ja}.lproj/Localizable.strings` の**両方**にキーと対訳を足し、
  コードは `L.string("キー")` / `L.format("キー", 値…)` で参照する（`Localization.swift` の `L`）。
- `Package.swift` に `defaultLocalization: "en"` と `resources: [.process("Resources")]`。
- **`Info.plist` に `CFBundleLocalizations`（en, ja）が必須**。無いと macOS がアプリ言語を
  開発リージョン(en)に固定し、ネスト文字列バンドルも en にフォールバックして日本語が一切出ない。
  ```xml
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
  ```
- `L` は SwiftPM 生成のリソースバンドル（`<Name>_<Name>.bundle`）を自前探索で解決し、
  見つからなければ `.main` にフォールバック（`Bundle.module` はクラッシュしうるので使わない）。
  `bundle.sh` がこのバンドルを `Contents/Resources/` にコピーする。

### 3. bundle ID は `com.mtkg.****` にする
本番の bundle ID は **`com.mtkg.<appname>`**（例: `com.mtkg.keykun` / `com.mtkg.snapperkun`）。
`Info.plist` の `CFBundleIdentifier`、各 `Logger(subsystem:)`、`UpdateService` 等で一貫させる。

### 4. アップデート機能を入れる
GitHub Releases から最新版を取得して自己更新する。
- `Core`: `ReleaseInfo`（`/releases/latest` の Decodable）と `VersionComparator`（タグの数値比較・純粋・テスト）。
- `App`: `UpdateService`（公開 GitHub API を URLSession で取得・zip DL。キャッシュ無効の ephemeral セッション）、
  `SelfUpdater`（zip を `ditto` 展開 → bundle ID 検証 → 旧プロセス終了待ち→入替の切り離しスクリプト→再起動）。
- メニューに「アップデートを確認…」を置き、起動時にサイレントチェック。新版があればメニュー文言を
  「アップデート v… をインストール…」に変える。
- 自己更新の bundle ID 検証は**基底ID（`.local` を除去）で比較**し、ローカルビルドからも本番へ更新できるようにする。
- **定期監視＋スリープ復帰チェック**: 起動時1回だけでなく、`Timer.scheduledTimer(withTimeInterval:repeats:)` で
  定期的にサイレントチェックする（間隔は GitHub 未認証 API のレート制限 **60回/時** を踏まえ 1〜数時間程度。
  `timer.tolerance` を間隔の 10% ほど付けて省電力のためコアレッシングを許可）。`Timer` はスリープ中に発火しないため、
  `NSWorkspace.didWakeNotification` を購読し**復帰時にも即チェック**する（ノート PC で「閉じている間に新版」に対応）。
  タイマーのコールバックはメインスレッドで `MainActor.assumeIsolated` を使って `@MainActor` のチェック処理を呼ぶ。
- **新版が見つかったらメニューバーアイコンの右下に赤バッジ（小さな赤丸）を出す**（最新なら消す）。実装の要点:
  - ベースアイコンは `isTemplate = true`（メニューバーの明暗で自動着色）の**まま維持**する。バッジは色付きなので、
    画像に焼き込む（非 template 化）と自動着色が壊れ、外観変化を監視して描き分ける手間が増える。
  - 代わりに**赤丸を別 view（`NSView` ＋ `wantsLayer` の `CALayer`）として `statusItem.button` にオーバーレイ**し、
    Auto Layout 制約で位置を固定する（手動 frame だと bounds 確定タイミングに依存して不安定）。メニューバー背景に
    溶けないよう細い白の縁取り（`borderWidth`/`borderColor`）を付ける。
  - 位置は **trailing 基準ではなくアイコン画像の幅基準**で固定する
    （`leading = button.leading + (iconWidth - badgeSize)`、`bottom = button.bottom`）。
    こうすると「ローカル」テキスト併記時（`imagePosition = .imageLeading`）でも常にアイコングリフの右下に乗る。
  - バッジの表示/非表示は、更新有無を集約する `setUpdateAvailable`/`clearUpdateAvailable`（メニュー文言変更と同じ箇所）に
    `badgeView?.isHidden` のトグルとして置き、起動時・定期・手動の**全チェック経路で自動同期**させる。
  - 注意: kuntraykun にアイコンを集約させて隠している間（`setManagedHidden(true)`）は自分のアイコンが非表示のため
    バッジも見えない（集約先へのバッジ伝搬は別途プロトコル拡張が必要）。

### 5. 自動起動（ログイン項目）機能を入れる
- `LoginItemController` で `SMAppService.mainApp`（macOS 13+）を register/unregister。
- **状態はシステム側が source of truth**。`Settings`/JSON には保存しない。表示時に `refresh()` で同期する。
- `.requiresApproval`（システム設定でログイン項目が無効）時は案内文を出す。
- トグルは設定の Apply/Cancel とは独立に**即時反映**する。

### 6. 設定は「設定」メニュー/ダイアログに集約する
- メニューバーのメニューは入口だけ（設定… / 権限確認 / アップデート確認 / 終了 など）。
  設定項目そのものはメニューに展開せず、**設定ダイアログ**に集約する。
- 設定ダイアログは SwiftUI を `NSWindow` にホストし、**タブ**で機能ごとに分割（機能追加はタブを足す）。
  「一般」タブ（自動起動・バージョン等）は**左端**に置く。
- **設定ダイアログ表示中は Dock アイコンを出す**。`SettingsWindowController` が表示時に
  `NSApp.setActivationPolicy(.regular)`、クローズ時に `.accessory` へ戻す。
- 設定の永続化は `Core` の `Settings`（機能ごとにサブ構造体）＋ `SettingsStore`（JSON、読込失敗で既定にフォールバック）。
  Codable は `decodeIfPresent ?? 既定値` で欠損キーを補完し前方/後方互換にする。
- SwiftUI を import するファイルでは `Settings`/`Binding` が SwiftUI と名前衝突するため
  `<Name>Core.Settings` / `@SwiftUI.Binding` と明示する。

### 7. ローカルビルドは「ローカル」表示で本番と区別する
- `bundle.sh` に `LOCAL=1` モードを設ける: bundle ID を `com.mtkg.<app>.local`、表示名を `<App> (Local)` にする。
- アプリは bundle ID が `.local` で終わるかで `isLocalBuild` を判定し、**メニューバーアイコンに「ローカル」を併記**、
  メニューのバージョン項目にも「(ローカル)」を付ける。
- 本番と bundle ID が違うので **TCC 権限が別エントリになり衝突しない**（独立して許可できる）。

### 8. ローカルの公証に気をつける
- 公証(notarization)は **CI のリリースビルドのみ**。ローカルビルド（`LOCAL=1` / `bundle.sh` 手元実行）は
  **署名はされるが公証されない**。配布物と取り違えない。
- ローカルビルドは bundle ID が `.local` で**別アプリ扱い**のため、**アクセシビリティ権限を別途付与**する必要がある。
- ローカルは未公証なので Gatekeeper の quarantine が付くと起動を阻まれることがある。必要なら
  `xattr -dr com.apple.quarantine <App>.app`（自己更新の入替スクリプトでも実施している）。
- ローカルでも Developer ID 署名（`SIGN_IDENTITY` 既定）にしておくと、再ビルドで TCC 権限が保持され検証が楽。

### 9. メニューにバージョン情報を入れる
- メニューバーのメニュー**先頭に操作不可のバージョン項目**（例: `Keykun 1.1.1`）を置き、区切り線を続ける。
- 文言は `Bundle.main` の `CFBundleShortVersionString`（`UpdateService.currentVersion`）から生成し、ローカルは「(ローカル)」を付す。
- 設定ダイアログ「一般」タブにもバージョンを表示する。

---

## イベントタップ系（keykun のような CGEventTap を使う場合）

- **イベントタップは1つを共有**し、機能ごとにハンドラを登録する（別タップを作らない）。
- **コールバック内で重い処理や再入しうる post を同期実行しない**。重い処理は `tapDisabledByTimeout` を招き
  イベントを取りこぼして状態が固着する。副作用は `DispatchQueue.main.async` でコールバック復帰後に逃がす。
- **タップ無効化時はハンドラ状態をリセット**して取りこぼし後の固着を防ぐ。
- **合成キーイベントは `.cghidEventTap`（HID 相当）に post**する（`.cgSessionEventTap` だと IME 等に届かない）。
- 入力モード切替は **英数/かなキー送出**が確実（`TISSelectInputSource` は「選択中の再選択が no-op」で
  複数モード IME では切り替わらない）。

## Kuntraykun 連携（メニューバーアイコンの集約）

`kuntraykun`（`com.mtkg.kuntraykun`）は、複数の kun アプリのメニューバーアイコンを**1つに集約**するハブ。
各 kun アプリはこの「連携の口」を実装すると、kuntraykun に**まとめられる**ようになる
（自分のアイコンを隠し、kuntraykun のアイコンから自分のメニューを開かせる）。新規 kun アプリは初めから対応しておく。

- **正式仕様**: kuntraykun リポジトリの `docs/kun-integration-protocol.md`（連携プロトコル v1）。
- **参照実装**: `clipkun` の `Sources/Clipkun/KuntraykunBridge.swift`、`StatusBarController.swift`、`AppDelegate.swift`。
  実装はこの3点をコピーしてアプリ名を置換するのが最短。

### 通信方式
- `DistributedNotificationCenter.default()` を使う。**userInfo の値は文字列のみ**（分散通知はプロパティリスト型のみ／
  非サンドボックス前提。kun シリーズは全て非サンドボックスなので userInfo 付きで届く）。
- kuntraykun とは別アプリなので `KuntraykunCore` は import せず、**通知名・キーを各アプリに自前定数化**する
  （プロトコル変更時は双方を一致させる）。

### 通知（3種）
- `com.mtkg.kuntraykun.sync`（kuntraykun→全アプリ・ブロードキャスト）: userInfo `{"managed": "<カンマ区切りの対象 bundleID>"}`。
  自分の基底 bundleID が含まれるかで**管理対象フラグ**を更新・永続化し、アイコン表示を再計算（冪等）。
- `com.mtkg.kuntraykun.showMenu`（kuntraykun→対象1アプリ）: userInfo `{"target": "<bundleID>", "x": "<screenX>", "y": "<screenY>"}`。
  `target` が自分の基底 bundleID のときだけ、自分のステータスメニューを
  `menu.popUp(positioning: nil, at: NSPoint(x, y), in: nil)` で表示（座標は Cocoa スクリーン座標＝左下原点）。
- `com.mtkg.kun.appLaunched`（アプリ→kuntraykun）: userInfo `{"bundleID": "<id>", "protocol": "1"}`。
  起動完了時に送る（kuntraykun が最新の `sync` を返す）。

### 実装の要点
- **`StatusBarController` に口を2つ足す**（既存ロジックは不変）。`NSMenu` をローカル変数からプロパティに昇格し:
  - `setManagedHidden(_:)` → `statusItem.isVisible = !hidden`（`NSStatusItem` は破棄せず保持し再利用）。
  - `popUpMenu(at:)` → 保持した `menu` を指定座標に `popUp`。
- **`KuntraykunBridge.swift`（1ファイル・自己完結）** を追加し、`AppDelegate` の起動処理で `bridge.start()` を配線する。
- **アイコン表示規則**: `隠す = (管理対象フラグ) かつ (kuntraykun 起動中)`。kuntraykun 未起動なら**隠さない**
  （操作不能を防ぐフォールバック）。kuntraykun 起動中かは `NSRunningApplication` ＋ `NSWorkspace` の
  `didLaunch/didTerminateApplicationNotification` 観測で判定し、変化時に再計算する。
- **基底 bundleID で突合**: 比較前に末尾 `.local`（ローカル検証ビルド）を除去する。kuntraykun 起動判定は
  **本番 `com.mtkg.kuntraykun` とローカル `com.mtkg.kuntraykun.local` の両方**を対象にする（ローカル検証が通るように）。
- **管理対象フラグの永続化**は `UserDefaults`（例: キー `KuntraykunManaged`）で十分。アプリの `Settings`（JSON）スキーマは汚さない。
- メニュー本体・各項目のアクションは**各アプリのプロセスのまま**なので、表示位置が変わるだけで挙動はネイティブ。

### 検出条件（kuntraykun 側の前提）
- kuntraykun が集約対象とみなすのは、bundleID が `com.mtkg.` で始まり**末尾が `kun`** のアプリ（例 `com.mtkg.clipkun`）。
  同じ `com.mtkg.*` でも非 kun（例 `com.mtkg.gogai`）は対象外。**新規アプリは命名規則どおり `<name>kun` にする**こと。

## ブランチ運用（必須）

- **`main` ブランチへ直接コミット/push しない**。変更は必ず **Pull Request 経由**で行う。
- 作業ブランチは**必ずその時点の最新の `main` から切る**。ブランチ作成前に
  `git fetch origin && git switch main && git pull --ff-only`（または `git fetch && git switch -c <branch> origin/main`）
  で main を最新化してから分岐する。
- PR は `gh pr create` で作成し、マージはレビュー後に行う。
- **PR 作成後に追加の修正を行うときは、まずその PR が既にマージされていないか確認する**
  （`gh pr view <番号> --json state,mergedAt`）。マージ済みの場合、その PR の作業ブランチへ
  push しても main には反映されない（孤立コミットになる）。マージ済みなら**最新 `main` から
  新しいブランチを切り直し**、必要な修正と（リリースが要るなら）バージョン更新を入れて別 PR を出す。
- リリース用 Actions は `push: tags: ["v*"]` で発火する。`main` へのマージ自体はリリースを
  起こさず、`make release-tag` で明示的に `v<version>` タグを作成・push したときだけリリースされる。
  事故防止のためにも main 直 push は避け、PR マージ経由にする。

## 開発の進め方

- 純粋ロジック（`Core`）は **TDD**（テスト先行）。UI/OS 連携は手動確認（実機で権限付与が必要）。
- 新機能の追加手順: ①判定ロジックを `Core` に純粋実装＋テスト → ②`Settings` にサブ構造体を足す →
  ③設定 UI にタブを足す → ④GUI 文字列を en/ja 両方に対訳追加。
- リリースは `Info.plist` の `CFBundleShortVersionString` を上げて `main` にマージし、
  `make release-tag` でタグを作成・push する（署名＋公証は CI が実施）。

## Kuntraykun 連携（実装済み）

本アプリは kuntraykun（`com.mtkg.kuntraykun`）にメニューバーアイコンを集約させる連携に対応している。
- 実装: `Sources/Pointerkun/KuntraykunBridge.swift`（分散通知の送受信・アイコン表示制御）、
  `StatusBarController.swift`（`setManagedHidden(_:)` / `popUpMenu(at:)` と `menu` のプロパティ化）、
  `AppDelegate.swift`（`bridge.start()` の配線）。
- 仕様: kuntraykun リポジトリ `docs/kun-integration-protocol.md`、共通方針は `../CLAUDE_base.md`「Kuntraykun 連携」。
- 管理対象フラグは `UserDefaults`（キー `KuntraykunManaged`）に永続化する。
- **実アイコンのライブ書き出し（v2）**: `KuntraykunIconExport.export(_:)`（`Sources/Pointerkun/KuntraykunIconExport.swift`）で、
  `StatusBarController` がメニューバーアイコンを設定する箇所で現在アイコンを
  `~/Library/Application Support/Kuntraykun/MenuBarIcons/<基底ID>.png` に書き出す（テンプレートは `.template` マーカー併記）。
  kuntraykun はこれを優先して一覧に表示する。
