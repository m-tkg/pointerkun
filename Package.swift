// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pointerkun",
    // ローカライズ済みリソース（en/ja）を持つため既定言語を指定する。
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // kuntraykun 連携（プロトコル定数・Bridge・アイコン/メニュー書き出し）の共有ライブラリ。
        .package(url: "https://github.com/m-tkg/kunkit.git", from: "1.3.0")
    ],
    targets: [
        // 純粋ロジック（テスト対象）: AppKit/Carbon に依存しない設定モデル・座標計算
        .target(
            name: "PointerkunCore",
            dependencies: [
                // ReleaseInfo / VersionComparator は kunkit（KunUpdateKit）へ移設した。
                .product(name: "KunUpdateKit", package: "kunkit"),
            ]
        ),
        // 実行ファイル本体: メニューバー常駐・オーバーレイ描画・ホットキー・ポインタ追従・設定UI
        .executableTarget(
            name: "Pointerkun",
            dependencies: [
                "PointerkunCore",
                .product(name: "KunIntegrationBridge", package: "kunkit"),
                .product(name: "KunUpdateKit", package: "kunkit"),
                .product(name: "KunSupport", package: "kunkit"),
                .product(name: "KunAppKit", package: "kunkit"),
            ],
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
