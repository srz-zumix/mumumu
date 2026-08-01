import 'package:flutter/material.dart';

/// 利用規約・プライバシーポリシーなどの静的文書を表示する画面。
///
/// 仕様書 1.2 / 8 に対応する。
class LegalPage extends StatelessWidget {
  /// 静的文書の画面を生成する。
  const LegalPage({required this.title, required this.body, super.key});

  /// 画面タイトル。
  final String title;

  /// 本文。
  final String body;

  /// 利用規約。
  static const LegalPage terms = LegalPage(
    title: '利用規約',
    body: '''
本規約は、無音（静音）カメラアプリ「mumumu」（以下「本アプリ」）の利用条件を定めるものです。

1. 禁止事項
   利用者は、本アプリを用いて次の行為を行ってはなりません。
   ・盗撮その他、撮影対象者の同意を得ない撮影
   ・法令または公序良俗に反する行為
   ・第三者のプライバシー、肖像権その他の権利を侵害する行為
   ・撮影が禁止されている場所・状況での撮影

2. 撮影対象への配慮
   利用者は、撮影対象のプライバシーを尊重し、必要な場合には必ず事前に同意を得るものとします。

3. 無音化について
   シャッター音の有無は端末および販売地域によって異なります。
   本アプリは無音での撮影を保証するものではありません。

4. 免責
   本アプリの利用により生じた損害について、開発者は一切の責任を負いません。
   利用者は自己の責任において本アプリを利用するものとします。

5. 料金
   本アプリは無料で提供され、広告・アプリ内課金・サブスクリプションはありません。
''',
  );

  /// プライバシーポリシー。
  static const LegalPage privacy = LegalPage(
    title: 'プライバシーポリシー',
    body: '''
本アプリは、利用者のプライバシーを最大限尊重します。

1. 撮影データの取り扱い
   撮影した画像・動画を端末外へ一切送信しません。
   本アプリはネットワーク通信を行わず、完全にオフラインで動作します。

2. 個人情報の収集
   本アプリは個人情報を収集しません。
   アナリティクスやクラッシュレポートの送信も行いません。

3. 権限の用途
   ・カメラ: 写真を撮影するために使用します。
   ・写真ライブラリ: 撮影した写真を端末に保存するために使用します。
   ・位置情報: 設定で「位置情報を付与する」を有効にした場合に限り、
     撮影した写真の Exif へ記録するために使用します。初期状態では無効です。
   ・マイク: 動画撮影機能を利用する場合にのみ使用します。

4. 保存先
   撮影した写真は端末のフォトライブラリ（iOS: mumumu アルバム、
   Android: Pictures/mumumu）に保存されます。本アプリ内には保持しません。

5. お問い合わせ
   本ポリシーに関するお問い合わせは、配布元のサポート窓口までご連絡ください。
''',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
