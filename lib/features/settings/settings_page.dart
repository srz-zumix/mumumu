import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../core/permissions/permission_service.dart';
import '../../core/preferences/app_settings.dart';
import '../../core/preferences/settings_controller.dart';
import '../../platform/silent_camera_providers.dart';
import 'legal_page.dart';

/// アプリのバージョン情報を供給する。
final FutureProvider<PackageInfo> packageInfoProvider =
    FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

/// 設定画面。仕様書 6-4 に対応する。
class SettingsPage extends ConsumerWidget {
  /// 設定画面を生成する。
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('撮影'),
          ListTile(
            title: const Text('撮影方式'),
            subtitle: Text(_captureModeLabel(settings.captureMode)),
            trailing: DropdownButton<CaptureMode>(
              value: settings.captureMode,
              onChanged: (CaptureMode? mode) => mode == null
                  ? null
                  : unawaited(controller.setCaptureMode(mode)),
              items: CaptureMode.values
                  .map(
                    (CaptureMode mode) => DropdownMenuItem<CaptureMode>(
                      value: mode,
                      child: Text(_captureModeShortLabel(mode)),
                    ),
                  )
                  .toList(),
            ),
          ),
          ListTile(
            title: const Text('解像度'),
            trailing: DropdownButton<CaptureResolution>(
              value: settings.resolution,
              onChanged: (CaptureResolution? value) => value == null
                  ? null
                  : unawaited(controller.setResolution(value)),
              items: CaptureResolution.values
                  .map(
                    (CaptureResolution value) =>
                        DropdownMenuItem<CaptureResolution>(
                          value: value,
                          child: Text(_resolutionLabel(value)),
                        ),
                  )
                  .toList(),
            ),
          ),
          ListTile(
            title: const Text('アスペクト比'),
            trailing: DropdownButton<CaptureAspectRatio>(
              value: settings.aspectRatio,
              onChanged: (CaptureAspectRatio? value) => value == null
                  ? null
                  : unawaited(controller.setAspectRatio(value)),
              items: CaptureAspectRatio.values
                  .map(
                    (CaptureAspectRatio value) =>
                        DropdownMenuItem<CaptureAspectRatio>(
                          value: value,
                          child: Text(value.label),
                        ),
                  )
                  .toList(),
            ),
          ),

          const _SectionHeader('保存'),
          if (Platform.isIOS)
            ListTile(
              title: const Text('保存形式'),
              trailing: DropdownButton<CaptureFormat>(
                value: settings.format,
                onChanged: (CaptureFormat? value) => value == null
                    ? null
                    : unawaited(controller.setFormat(value)),
                items: CaptureFormat.values
                    .map(
                      (CaptureFormat value) => DropdownMenuItem<CaptureFormat>(
                        value: value,
                        child: Text(value.name.toUpperCase()),
                      ),
                    )
                    .toList(),
              ),
            )
          else
            const ListTile(
              title: Text('保存形式'),
              subtitle: Text('この端末では JPEG で保存します。'),
              trailing: Text('JPEG'),
            ),
          ListTile(
            title: const Text('JPEG 品質'),
            subtitle: Slider(
              value: settings.jpegQuality.toDouble(),
              min: 60,
              max: 100,
              divisions: 8,
              label: '${settings.jpegQuality}',
              onChanged: (double value) =>
                  unawaited(controller.setJpegQuality(value.round())),
            ),
          ),
          SwitchListTile(
            title: const Text('前面カメラをミラーで保存'),
            subtitle: const Text('プレビューと同じ左右反転で保存します。'),
            value: settings.mirrorFrontCamera,
            onChanged: (bool value) =>
                unawaited(controller.setMirrorFrontCamera(enabled: value)),
          ),
          SwitchListTile(
            title: const Text('位置情報を付与する'),
            subtitle: const Text('Exif に撮影場所を記録します。既定は無効です。'),
            value: settings.includeLocation,
            onChanged: (bool value) =>
                unawaited(_setIncludeLocation(ref, controller, enabled: value)),
          ),

          const _SectionHeader('操作'),
          ListTile(
            title: const Text('シャッター操作'),
            subtitle: Text(settings.shutterMethod.label),
            trailing: DropdownButton<ShutterMethod>(
              value: settings.shutterMethod,
              onChanged: (ShutterMethod? value) => value == null
                  ? null
                  : unawaited(controller.setShutterMethod(value)),
              items: ShutterMethod.values
                  .map(
                    (ShutterMethod value) => DropdownMenuItem<ShutterMethod>(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          ListTile(
            title: const Text('セルフタイマー'),
            trailing: DropdownButton<SelfTimer>(
              value: settings.selfTimer,
              onChanged: (SelfTimer? value) => value == null
                  ? null
                  : unawaited(controller.setSelfTimer(value)),
              items: SelfTimer.values
                  .map(
                    (SelfTimer value) => DropdownMenuItem<SelfTimer>(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          SwitchListTile(
            title: const Text('グリッドを表示'),
            value: settings.gridEnabled,
            onChanged: (bool value) =>
                unawaited(controller.setGridEnabled(enabled: value)),
          ),

          const _SectionHeader('表示'),
          ListTile(
            title: const Text('テーマ'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (ThemeMode? value) => value == null
                  ? null
                  : unawaited(controller.setThemeMode(value)),
              items: ThemeMode.values
                  .map(
                    (ThemeMode value) => DropdownMenuItem<ThemeMode>(
                      value: value,
                      child: Text(_themeLabel(value)),
                    ),
                  )
                  .toList(),
            ),
          ),

          const _SectionHeader('この端末について'),
          const _SilenceCapabilityTile(),

          const _SectionHeader('アプリについて'),
          ListTile(
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_openLegal(context, LegalPage.terms)),
          ),
          ListTile(
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_openLegal(context, LegalPage.privacy)),
          ),
          const _LicensesTile(),
          const _VersionTile(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 位置情報の付与を切り替える。
  ///
  /// 有効化時のみ位置情報の権限をリクエストする。
  Future<void> _setIncludeLocation(
    WidgetRef ref,
    SettingsController controller, {
    required bool enabled,
  }) async {
    if (!enabled) {
      await controller.setIncludeLocation(enabled: false);
      return;
    }
    final AppPermissionStatus status = await ref
        .read(permissionServiceProvider)
        .requestLocation();
    await controller.setIncludeLocation(
      enabled: status == AppPermissionStatus.granted,
    );
  }

  Future<void> _openLegal(BuildContext context, LegalPage page) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));
  }

  static String _captureModeLabel(CaptureMode mode) => switch (mode) {
    CaptureMode.silentVideoFrame => 'ビデオのフレームから切り出すため無音ですが、画質は控えめです。',
    CaptureMode.photo => '高画質ですが、端末によってはシャッター音が鳴ります。',
  };

  static String _captureModeShortLabel(CaptureMode mode) => switch (mode) {
    CaptureMode.silentVideoFrame => '静音優先',
    CaptureMode.photo => '画質優先',
  };

  static String _resolutionLabel(CaptureResolution value) => switch (value) {
    CaptureResolution.low => '低',
    CaptureResolution.medium => '中',
    CaptureResolution.high => '高',
    CaptureResolution.max => '最大',
  };

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '端末に合わせる',
    ThemeMode.light => 'ライト',
    ThemeMode.dark => 'ダーク',
  };
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

/// 端末の無音撮影対応状況を表示する。仕様書 2.3 に対応する。
class _SilenceCapabilityTile extends ConsumerWidget {
  const _SilenceCapabilityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SilenceCapability> capability = ref.watch(
      silenceCapabilityProvider,
    );

    return capability.when(
      loading: () => const ListTile(title: Text('確認中...')),
      error: (Object error, StackTrace stack) =>
          const ListTile(title: Text('対応状況を確認できませんでした。')),
      data: (SilenceCapability value) => ListTile(
        title: Text(value.deviceModel.isEmpty ? '端末情報' : value.deviceModel),
        subtitle: Text(
          <String>[
            value.isSilentCaptureSupported ? '静音撮影に対応しています。' : '静音撮影に対応していません。',
            if (value.isShutterSoundEnforcedByOs)
              'この地域の端末では、写真モードのシャッター音を抑止できません。',
            if (value.note.isNotEmpty) value.note,
          ].join('\n'),
        ),
        isThreeLine: value.note.isNotEmpty,
      ),
    );
  }
}

class _LicensesTile extends ConsumerWidget {
  const _LicensesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PackageInfo> info = ref.watch(packageInfoProvider);
    return ListTile(
      title: const Text('OSS ライセンス'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLicensePage(
        context: context,
        applicationName: 'mumumu',
        applicationVersion: info.valueOrNull?.version,
      ),
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PackageInfo> info = ref.watch(packageInfoProvider);
    return ListTile(
      title: const Text('バージョン'),
      subtitle: Text(
        info.valueOrNull == null
            ? '-'
            : '${info.valueOrNull!.version} (${info.valueOrNull!.buildNumber})',
      ),
    );
  }
}
