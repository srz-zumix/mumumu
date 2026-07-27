# mumumu

静かに撮れるカメラアプリ **mumumu** の実装リポジトリです。
仕様は [docs/specification.md](docs/specification.md) を参照してください。

## 特徴

- ビデオフレームからの切り出しによる静音撮影（iOS: AVFoundation / Android: Camera2）
- 前面 / 背面カメラ切替、ピンチズームと倍率プリセット、タップフォーカス、AE/AF ロック、露出補正
- フラッシュ（OFF / AUTO / ON / トーチ）、3 分割グリッド、セルフタイマー
- フォトライブラリの `mumumu` アルバムへ保存（iOS: PHPhotoLibrary / Android: `Pictures/mumumu`）
- 完全オフライン動作。広告・課金・アナリティクスは一切なし

## 構成

```
lib/
├── main.dart
├── app/            # テーマ・ルーティング
├── core/           # 権限・設定の永続化
└── features/       # camera / viewer / settings / onboarding
packages/
└── silent_camera/  # 無音キャプチャ用の自作プラグイン（Dart + Swift + Kotlin）
test/               # ユニット / ウィジェットテスト
```

## セットアップ

このリポジトリには Flutter が生成する `ios/` `android/` のランナープロジェクトを含めていません。
クローン後に一度だけ次を実行して生成してください。

```sh
flutter create --platforms=ios,android --org dev.srzzumix .
flutter pub get
```

生成後、以下の権限説明を追記します。

- iOS (`ios/Runner/Info.plist`): `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`
- Android (`android/app/src/main/AndroidManifest.xml`): `android.permission.CAMERA`

## 開発コマンド

```sh
flutter analyze                          # 静的解析
flutter test                             # アプリのテスト
flutter test packages/silent_camera      # プラグインのテスト
flutter run                              # 実機での実行
```

## 実装状況

フェーズ 1（MVP）の範囲を実装しています。動画撮影・連写などフェーズ 2 以降の機能は未実装です。
HEIC 保存は iOS のみ対応し、Android では JPEG にフォールバックします。

## ご利用にあたって

盗撮など違法・迷惑行為への利用を固く禁止します。撮影対象のプライバシーを尊重してご利用ください。
