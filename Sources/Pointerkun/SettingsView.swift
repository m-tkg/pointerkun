import SwiftUI
import AppKit
import Carbon.HIToolbox
import KunAppKit
import PointerkunCore

/// 設定ダイアログの編集状態。変更は即時反映する（Apply/OK は持たない）。
/// `settings` が変わるたびに `onChange` を呼び、保存と各機能への反映を行う。
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: PointerkunCore.Settings {
        didSet {
            // 外部同期中（ホットキーでのトグル反映など）は保存し直さない（二重保存・ループ防止）。
            guard !isSuppressingChange else { return }
            guard settings != oldValue else { return }
            onChange(settings)
        }
    }
    private let onChange: (PointerkunCore.Settings) -> Void
    private var isSuppressingChange = false

    init(settings: PointerkunCore.Settings, onChange: @escaping (PointerkunCore.Settings) -> Void) {
        self.settings = settings
        self.onChange = onChange
    }

    /// アプリ側で変わった設定を表示へ反映する（onChange は発火させない）。
    func externalUpdate(_ newSettings: PointerkunCore.Settings) {
        isSuppressingChange = true
        settings = newSettings
        isSuppressingChange = false
    }
}

/// 設定ダイアログ本体。タブで機能ごとの設定を切り替える。
/// 各コントロールの変更は即座に反映・保存される（確定ボタンは無し、閉じるボタンで閉じる）。
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var loginItem: LoginItemController

    @State private var loginItemError: String?

    var body: some View {
        TabView {
            GeneralSettingsTab(loginItem: loginItem, errorMessage: $loginItemError)
                .tabItem { Text(L.string("tab.general")) }

            HighlightSettingsTab(
                settings: $viewModel.settings.highlight,
                hotKey: $viewModel.settings.highlightHotKey
            )
            .tabItem { Text(L.string("tab.highlight")) }

            LocatorSettingsTab(
                hotKey: $viewModel.settings.locatorHotKey,
                ripple: $viewModel.settings.ripple
            )
            .tabItem { Text(L.string("tab.locator")) }
        }
        .padding()
        .frame(width: 520, height: 420)
        .alert(L.string("alert.error.title"), isPresented: Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }
}

/// 「一般」タブ。ログイン時の自動起動とバージョン表示。
struct GeneralSettingsTab: View {
    @ObservedObject var loginItem: LoginItemController
    @SwiftUI.Binding var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(L.string("settings.launch_at_login"), isOn: Binding(
                get: { loginItem.isEnabled },
                set: { newValue in
                    if let message = loginItem.setEnabled(newValue) {
                        errorMessage = message
                    }
                }
            ))

            Text(L.format("settings.version", UpdateService.currentVersion))
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 「ハイライト円」タブ（機能2＋3）。常時表示する半透明円の有効化・表示切替ホットキー・色・大きさ。
struct HighlightSettingsTab: View {
    @SwiftUI.Binding var settings: HighlightSettings
    @SwiftUI.Binding var hotKey: HotKeyConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(isOn: $settings.isEnabled) {
                Text(L.string("highlight.enabled"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(L.string("highlight.hotkey"))
                Spacer(minLength: 12)
                HotKeyRecorderView(config: $hotKey)
            }

            ColorPicker(L.string("highlight.color"), selection: colorBinding($settings.color))
                .disabled(!settings.isEnabled)

            HStack(alignment: .firstTextBaseline) {
                Text(L.string("highlight.diameter"))
                Slider(value: $settings.diameter, in: 20...240, step: 2)
                Text(L.format("common.points", settings.diameter))
                    .font(.caption).monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            .disabled(!settings.isEnabled)

            Text(L.string("highlight.description"))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 「ロケーター」タブ（機能1＋3）。発火ホットキーと、広がる円の色・大きさ・速さ。
struct LocatorSettingsTab: View {
    @SwiftUI.Binding var hotKey: HotKeyConfig
    @SwiftUI.Binding var ripple: RippleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(L.string("locator.hotkey"))
                Spacer(minLength: 12)
                HotKeyRecorderView(config: $hotKey)
            }

            ColorPicker(L.string("locator.color"), selection: colorBinding($ripple.color))

            HStack(alignment: .firstTextBaseline) {
                Text(L.string("locator.max_diameter"))
                Slider(value: $ripple.maxDiameter, in: 80...500, step: 10)
                Text(L.format("common.points", ripple.maxDiameter))
                    .font(.caption).monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(L.string("locator.line_width"))
                Slider(value: $ripple.lineWidth, in: 1...16, step: 1)
                Text(L.format("common.points", ripple.lineWidth))
                    .font(.caption).monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(L.string("locator.duration"))
                Slider(value: $ripple.duration, in: 0.2...1.5, step: 0.1)
                Text(L.format("common.seconds", ripple.duration))
                    .font(.caption).monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }

            Text(L.string("locator.description"))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// `RGBAColor` の Binding を SwiftUI の `Color` Binding に橋渡しする（ColorPicker 用）。
private func colorBinding(_ binding: SwiftUI.Binding<RGBAColor>) -> SwiftUI.Binding<Color> {
    SwiftUI.Binding(
        get: { Color(binding.wrappedValue.nsColor) },
        set: { binding.wrappedValue = RGBAColor(NSColor($0)) }
    )
}

/// ホットキーを記録するボタン。押下後に次のキー入力（修飾キー必須）を取り込む。
struct HotKeyRecorderView: View {
    @SwiftUI.Binding var config: HotKeyConfig
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? L.string("hotkey.recording") : config.displayString)
                .frame(minWidth: 120)
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        if isRecording { stop() } else { start() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc（修飾なし）で記録をキャンセル。
            if event.keyCode == UInt16(kVK_Escape),
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                stop()
                return nil
            }
            // 修飾キーが付いていれば確定。無ければ記録継続（誤爆防止）。
            if let newConfig = HotKeyTranslation.config(from: event) {
                config = newConfig
                stop()
            }
            return nil // 記録中はイベントを消費する。
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
