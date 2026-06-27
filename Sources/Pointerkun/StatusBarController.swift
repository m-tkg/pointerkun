import AppKit

/// メニューバー常駐アイコンとメニューを管理する。
/// 設定項目自体は設定ダイアログに集約し、メニューは入口だけを提供する。
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    /// ステータスメニュー本体。kuntraykun 連携時はこのメニューを指定座標へ popUp する。
    private let menu = NSMenu()

    private let openSettings: () -> Void
    private let checkForUpdate: () -> Void
    private let quitApp: () -> Void
    private var updateItem: NSMenuItem!

    /// 新バージョンが利用可能なとき、アイコン右下に出す赤バッジ（小さな赤丸）。
    /// 更新有無の集約点（`setUpdateAvailable`/`clearUpdateAvailable`）で表示/非表示を切り替える。
    private var badgeView: NSView?
    /// 赤バッジの直径（pt）。アイコン（高さ 18pt）に対する「小さな赤丸」。
    private static let badgeSize: CGFloat = 7

    private static var checkUpdateTitle: String { L.string("menu.check_update") }

    /// ローカル検証ビルド（バンドルID が `.local` で終わる）かどうか。
    private var isLocalBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".local")
    }

    init(
        openSettings: @escaping () -> Void,
        checkForUpdate: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.openSettings = openSettings
        self.checkForUpdate = checkForUpdate
        self.quitApp = quit
        super.init()

        if let button = statusItem.button {
            if let template = Self.menuBarImage() {
                button.image = template
            } else if let symbol = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Pointerkun") {
                symbol.isTemplate = true
                button.image = symbol
            } else {
                button.title = "◎"
            }
            // ローカルビルドは「ローカル」を併記して本番と区別する。
            if isLocalBuild {
                button.title = " " + L.string("menu_bar.local")
                button.imagePosition = .imageLeading
            }
            setupBadge(on: button)
        }
        // kuntraykun 一覧用に、現在のメニューバーアイコンを共有場所へ書き出す（連携 v2）。
        KuntraykunIconExport.export(statusItem.button?.image)

        // 先頭にバージョン情報（操作不可）。ローカルビルドは併記する。
        var versionTitle = L.format("menu.version", UpdateService.currentVersion)
        if isLocalBuild { versionTitle += " (" + L.string("menu_bar.local") + ")" }
        let versionItem = NSMenuItem(title: versionTitle, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(menuItem(title: L.string("menu.settings"), action: #selector(handleOpenSettings), key: ","))
        updateItem = menuItem(title: Self.checkUpdateTitle, action: #selector(handleCheckForUpdate), key: "")
        menu.addItem(updateItem)
        menu.addItem(.separator())
        menu.addItem(menuItem(title: L.string("menu.quit"), action: #selector(handleQuit), key: "q"))
        statusItem.menu = menu
    }

    /// 新バージョンが利用可能なときにメニュー文言を変更し、アイコンに赤バッジを出す。
    func setUpdateAvailable(tag: String) {
        updateItem.title = L.format("menu.install_update", tag)
        badgeView?.isHidden = false
    }

    /// 最新（更新なし）状態に戻し、赤バッジを消す。
    func clearUpdateAvailable() {
        updateItem.title = Self.checkUpdateTitle
        badgeView?.isHidden = true
    }

    // MARK: - kuntraykun 連携

    /// kuntraykun に集約されている間、自分のメニューバーアイコンを隠す/戻す。
    func setManagedHidden(_ hidden: Bool) {
        statusItem.isVisible = !hidden
    }

    /// 自分のステータスメニューを指定スクリーン座標（左下原点）に表示する。
    func popUpMenu(at point: NSPoint) {
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    private func menuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func handleOpenSettings() { openSettings() }
    @objc private func handleCheckForUpdate() { checkForUpdate() }
    @objc private func handleQuit() { quitApp() }

    /// アイコン右下に赤バッジ（小さな赤丸）をオーバーレイする。初期状態は非表示。
    ///
    /// ベースアイコンは template（明暗に自動着色）のまま維持したいので、画像に焼き込まず
    /// 別 view（`wantsLayer` の `CALayer`）として `button` に重ねる。位置は **trailing ではなく
    /// アイコン画像の幅基準**で固定し（`leading = button.leading + (iconWidth - badgeSize)`,
    /// `bottom = button.bottom`）、「ローカル」テキスト併記時（`imagePosition = .imageLeading`）でも
    /// 常にアイコングリフの右下に乗るようにする。手動 frame は bounds 確定タイミングに依存して
    /// 不安定なため Auto Layout を使う。
    private func setupBadge(on button: NSStatusBarButton) {
        // アイコン画像の幅（テンプレート画像は高さ 18pt に正規化済み）。画像が無い場合の保険に既定値。
        let iconWidth = button.image?.size.width ?? Self.badgeSize

        let badge = NSView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        if let layer = badge.layer {
            layer.backgroundColor = NSColor.systemRed.cgColor
            layer.cornerRadius = Self.badgeSize / 2
            layer.masksToBounds = true
            // メニューバー背景（明暗どちらでも）に溶けないよう細い白の縁取りを付ける。
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.cgColor
        }
        badge.isHidden = true
        button.addSubview(badge)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            badge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
            badge.leadingAnchor.constraint(
                equalTo: button.leadingAnchor, constant: iconWidth - Self.badgeSize),
            badge.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        badgeView = badge
    }

    /// メニューバー用のテンプレート（モノクロ）画像を返す。
    /// `Resources/MenuBarIcon.png` を読み込み、テンプレート指定で明暗に追従させる。
    /// 見つからなければ nil（呼び出し側が SF Symbol にフォールバック）。
    private static func menuBarImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        let height: CGFloat = 18
        let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        image.size = NSSize(width: height * aspect, height: height)
        image.isTemplate = true
        return image
    }
}
