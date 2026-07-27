import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions.dart';
import '../../core/settings/settings_controller.dart';
import '../camera/camera_page.dart';

/// 初回起動時のオンボーディング。
///
/// 用途説明・法令遵守の注意喚起・権限の用途説明を行ってから権限をリクエストする。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  static const String routeName = '/onboarding';

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _requesting = false;

  Future<void> _acceptAndContinue() async {
    setState(() => _requesting = true);
    final permissions = ref.read(permissionServiceProvider);
    final outcome = await permissions.requestCapturePermissions();
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (!mounted) {
      return;
    }
    setState(() => _requesting = false);
    if (outcome == PermissionOutcome.permanentlyDenied) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('権限が拒否されています。設定アプリから許可してください。'),
          action: SnackBarAction(
            label: '設定を開く',
            onPressed: () => permissions.openSettings(),
          ),
        ),
      );
    }
    await Navigator.of(context)
        .pushReplacementNamed(CameraPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 16),
              Text('mumumu へようこそ', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: const <Widget>[
                    _OnboardingItem(
                      icon: Icons.volume_off,
                      title: '静かに撮れるカメラ',
                      description: '図書館や病院、寝ているお子さま・ペットの撮影など、'
                          '静粛性が求められる場面のためのカメラです。'
                          '無音化の可否は端末や地域により異なります。',
                    ),
                    _OnboardingItem(
                      icon: Icons.gavel,
                      title: '法令とマナーを守ってください',
                      description: '盗撮など違法・迷惑行為への利用は固く禁止します。'
                          '撮影対象のプライバシーを尊重してください。',
                    ),
                    _OnboardingItem(
                      icon: Icons.perm_camera_mic,
                      title: '権限の用途',
                      description: 'カメラ: 写真の撮影に使用します。\n'
                          'フォトライブラリ: 撮影した写真の保存に使用します。\n'
                          'マイク: 動画撮影時のみ使用します。',
                    ),
                    _OnboardingItem(
                      icon: Icons.wifi_off,
                      title: '完全オフライン',
                      description: '撮影した画像を端末外へ送信しません。'
                          '広告・課金・アナリティクスも導入していません。',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _requesting ? null : _acceptAndContinue,
                child: const Text('同意して始める'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem extends StatelessWidget {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
