// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pointerkun",
    // ローカライズ済みリソース（en/ja）を持つため既定言語を指定する。
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // 純粋ロジック（テスト対象）: AppKit/Carbon に依存しない設定モデル・座標計算・バージョン比較
        .target(
            name: "PointerkunCore"
        ),
        // 実行ファイル本体: メニューバー常駐・オーバーレイ描画・ホットキー・ポインタ追従・設定UI
        .executableTarget(
            name: "Pointerkun",
            dependencies: ["PointerkunCore"],
            // en.lproj / ja.lproj の Localizable.strings をリソースバンドルに含める。
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PointerkunCoreTests",
            dependencies: ["PointerkunCore"]
        ),
    ]
)
