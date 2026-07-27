import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../core/settings/settings_controller.dart';

/// 設定画面。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const String routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('撮影'),
          ListTile(
            title: const Text('撮影方式'),
            subtitle: Text(
              settings.captureMode == CaptureMode.silent
                  ? '無音（フレーム切り出し）: 音は鳴りませんが画質は写真モードに劣ります'
                  : '写真モード: 高画質ですが地域・端末によってはシャッター音が鳴ります',
            ),
            trailing: DropdownButton<CaptureMode>(
              value: settings.captureMode,
              onChanged: (CaptureMode? value) {
                if (value != null) {
                  controller.setCaptureMode(value);
                }
              },
              items: const <DropdownMenuItem<CaptureMode>>[
                DropdownMenuItem<CaptureMode>(
                  value: CaptureMode.silent,
                  child: Text('無音'),
                ),
                DropdownMenuItem<CaptureMode>(
                  value: CaptureMode.photo,
                  child: Text('写真'),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('アスペクト比'),
            trailing: DropdownButton<AspectRatioPreset>(
              value: settings.aspectRatio,
              onChanged: (AspectRatioPreset? value) {
                if (value != null) {
                  controller.setAspectRatio(value);
                }
              },
              items: const <DropdownMenuItem<AspectRatioPreset>>[
                DropdownMenuItem<AspectRatioPreset>(
                  value: AspectRatioPreset.ratio4x3,
                  child: Text('4:3'),
                ),
                DropdownMenuItem<AspectRatioPreset>(
                  value: AspectRatioPreset.ratio16x9,
                  child: Text('16:9'),
                ),
                DropdownMenuItem<AspectRatioPreset>(
                  value: AspectRatioPreset.ratio1x1,
                  child: Text('1:1'),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('保存形式'),
            trailing: DropdownButton<PhotoFormat>(
              value: settings.photoFormat,
              onChanged: (PhotoFormat? value) {
                if (value != null) {
                  controller.setPhotoFormat(value);
                }
              },
              items: const <DropdownMenuItem<PhotoFormat>>[
                DropdownMenuItem<PhotoFormat>(
                  value: PhotoFormat.jpeg,
                  child: Text('JPEG'),
                ),
                DropdownMenuItem<PhotoFormat>(
                  value: PhotoFormat.heic,
                  child: Text('HEIC'),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('JPEG 品質'),
            subtitle: Slider(
              value: settings.jpegQuality.toDouble(),
              min: 50,
              max: 100,
              divisions: 10,
              label: '${settings.jpegQuality}',
              onChanged: (double value) =>
                  controller.setJpegQuality(value.round()),
            ),
          ),
          SwitchListTile(
            title: const Text('前面カメラをミラー保存'),
            value: settings.mirrorFrontCamera,
            onChanged: (bool value) =>
                controller.setMirrorFrontCamera(enabled: value),
          ),
          SwitchListTile(
            title: const Text('画面タップで撮影'),
            subtitle: const Text('OFF のときはタップでフォーカスと露出を合わせます'),
            value: settings.tapToShoot,
            onChanged: (bool value) => controller.setTapToShoot(enabled: value),
          ),
          const _SectionHeader('表示'),
          ListTile(
            title: const Text('テーマ'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  controller.setThemeMode(value);
                }
              },
              items: const <DropdownMenuItem<ThemeMode>>[
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.system,
                  child: Text('端末に合わせる'),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.light,
                  child: Text('ライト'),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.dark,
                  child: Text('ダーク'),
                ),
              ],
            ),
          ),
          const _SectionHeader('このアプリについて'),
          const ListTile(
            title: Text('利用規約'),
            subtitle: Text(
              '盗撮など違法・迷惑行為への利用を禁止します。'
              '撮影対象のプライバシーを尊重してご利用ください。',
            ),
          ),
          const ListTile(
            title: Text('プライバシーポリシー'),
            subtitle: Text(
              '撮影した画像を端末外へ送信しません。個人情報も収集しません。'
              'ネットワーク通信は一切行いません。',
            ),
          ),
          ListTile(
            title: const Text('オープンソースライセンス'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'mumumu',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
