import AppKit
import OSLog
import PointerkunCore

private let log = Logger(subsystem: "com.mtkg.pointerkun", category: "app")

/// アプリ本体。設定の読込・反映、各機能コントローラとステータスバー UI・設定ウィンドウの配線を担う。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore(url: SettingsStore.defaultURL())

    // 機能コントローラ。
    private let highlight = HighlightController()
    private let ripple = RippleController()
    private let hotKey = HotKeyManager()

    private var statusBar: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var settings = Settings.default

    // 機能ごとの安定したホットキー ID。
    private enum HotKeyID {
        static let locator: UInt32 = 1
        static let highlight: UInt32 = 2
    }
    // 直近に登録済みのホットキー構成（変化時のみ再登録するため保持）。
    private var appliedLocatorHotKey: HotKeyConfig?
    private var appliedHighlightHotKey: HotKeyConfig?

    // アップデート関連。
    private let updateService = UpdateService()
    private lazy var selfUpdater = SelfUpdater(service: updateService)
    private var availableRelease: ReleaseInfo?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = store.load()
        applySettings(settings)

        statusBar = StatusBarController(
            openSettings: { [weak self] in self?.openSettings() },
            checkForUpdate: { [weak self] in self?.startUpdateCheck(interactive: true) },
            quit: { NSApp.terminate(nil) }
        )

        // 起動時にサイレントで更新チェック（あればメニュー文言を変更）。
        startUpdateCheck(interactive: false)
    }

    /// 設定を各コントローラに反映する。
    /// ホットキーは構成が変わったときだけ登録し直す（スライダー操作などでの無駄な再登録を避ける）。
    private func applySettings(_ settings: Settings) {
        highlight.update(settings.highlight)
        ripple.update(settings.ripple)

        if appliedLocatorHotKey != settings.locatorHotKey {
            hotKey.register(id: HotKeyID.locator, config: settings.locatorHotKey) { [weak self] in
                self?.ripple.fire()
            }
            appliedLocatorHotKey = settings.locatorHotKey
        }
        if appliedHighlightHotKey != settings.highlightHotKey {
            hotKey.register(id: HotKeyID.highlight, config: settings.highlightHotKey) { [weak self] in
                self?.toggleHighlight()
            }
            appliedHighlightHotKey = settings.highlightHotKey
        }
    }

    /// ハイライト円の表示/非表示をホットキーで切り替える。
    /// 状態を保存し、設定ウィンドウが開いていれば表示も同期する。
    private func toggleHighlight() {
        settings.highlight.isEnabled.toggle()
        highlight.update(settings.highlight)
        try? store.save(settings)
        settingsWindowController?.syncExternally(settings)
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                initialSettings: settings,
                onChange: { [weak self] newSettings in
                    guard let self else { return }
                    // 変更は即時反映する: 各機能へ反映してから保存する。
                    self.settings = newSettings
                    self.applySettings(newSettings)
                    try? self.store.save(newSettings)
                }
            )
        }
        settingsWindowController?.show()
    }

    // MARK: - アップデート

    /// 最新リリースを取得してバージョン比較する。
    /// interactive=false: 起動時のサイレントチェック（結果はメニュー文言に反映するのみ）。
    /// interactive=true : メニューからの手動チェック（結果をダイアログで提示）。
    private func startUpdateCheck(interactive: Bool) {
        Task { @MainActor in
            do {
                let release = try await updateService.fetchLatestRelease()
                let isNewer = VersionComparator.isNewer(
                    tag: release.tagName, than: UpdateService.currentVersion)
                if isNewer {
                    availableRelease = release
                    statusBar?.setUpdateAvailable(tag: release.tagName)
                } else {
                    availableRelease = nil
                    statusBar?.clearUpdateAvailable()
                }
                if interactive {
                    if isNewer {
                        promptInstall(release)
                    } else {
                        showInfo(L.format("update.latest", UpdateService.currentVersion))
                    }
                }
            } catch {
                log.error("update check failed: \(error.localizedDescription, privacy: .public)")
                if interactive {
                    showError(L.format("update.check_failed", error.localizedDescription))
                }
            }
        }
    }

    private func promptInstall(_ release: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L.format("update.available.title", release.tagName)
        alert.informativeText = L.format("update.available.body", UpdateService.currentVersion)
        alert.addButton(withTitle: L.string("update.button.update"))
        alert.addButton(withTitle: L.string("update.button.open_release"))
        alert.addButton(withTitle: L.string("button.cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            performUpdate(release)
        case .alertSecondButtonReturn:
            if let url = URL(string: release.htmlUrl) { NSWorkspace.shared.open(url) }
        default:
            break
        }
    }

    private func performUpdate(_ release: ReleaseInfo) {
        Task { @MainActor in
            do {
                try await selfUpdater.performUpdate(to: release)
                // 成功時はアプリが終了するためここには戻らない。
            } catch {
                log.error("self-update failed: \(error.localizedDescription, privacy: .public)")
                showError(L.format("update.failed", error.localizedDescription))
            }
        }
    }

    private func showInfo(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Pointerkun"
        alert.informativeText = text
        alert.runModal()
    }

    private func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.string("alert.error.title")
        alert.informativeText = text
        alert.runModal()
    }
}
