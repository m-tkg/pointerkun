import AppKit
import Carbon.HIToolbox
import OSLog
import PointerkunCore

private let log = Logger(subsystem: "com.mtkg.pointerkun", category: "hotkey")

/// Carbon `RegisterEventHotKey` を使った複数のグローバルホットキー管理。
///
/// CGEventTap と違い**アクセシビリティ権限が不要**で、押下イベントだけを受け取れる。
/// 機能ごとに安定した ID で登録し、押下時は `EventHotKeyID` を見て該当アクションへ振り分ける
/// （Carbon のホットキーハンドラはイベントターゲット単位で全ホットキーに対し呼ばれるため）。
@MainActor
final class HotKeyManager {
    private struct Entry {
        var ref: EventHotKeyRef?
        var action: () -> Void
    }

    /// id -> 登録内容。
    private var entries: [UInt32: Entry] = [:]
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x504B_4E21 // 'PKN!'

    /// 指定 ID のホットキーを（あれば置き換えて）登録する。
    /// `id` は機能ごとに一意な安定値（例: ロケーター=1, ハイライト=2）。
    func register(id: UInt32, config: HotKeyConfig, action: @escaping () -> Void) {
        unregister(id: id)
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            entries[id] = Entry(ref: ref, action: action)
            log.info("hotkey \(id) registered: \(config.displayString, privacy: .public)")
        } else {
            // 同じ組み合わせの二重登録などで失敗しうる。アクションだけは保持しない。
            log.error("RegisterEventHotKey failed for id \(id): \(status)")
        }
    }

    /// 指定 ID の登録を解除する（イベントハンドラは常駐させたままにする）。
    func unregister(id: UInt32) {
        if let entry = entries[id], let ref = entry.ref {
            UnregisterEventHotKey(ref)
        }
        entries[id] = nil
    }

    /// 押下された ID に対応するアクションを実行する（ハンドラから呼ばれる）。
    fileprivate func handle(id: UInt32) {
        entries[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // C コールバックはキャプチャを持てないため、userData 経由で self を受け取る。
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                // 押下されたホットキーの ID を取り出す。
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                let id = hotKeyID.id
                // Carbon のホットキーイベントはメインスレッドのランループで配送される。
                MainActor.assumeIsolated { manager.handle(id: id) }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &handlerRef
        )
    }
}
