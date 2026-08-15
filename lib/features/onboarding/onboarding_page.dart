import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/preferences/settings_controller.dart';

/// オンボーディング画面。仕様書 6-1 に対応する。
///
/// 用途説明・法令遵守の注意喚起・権限の用途説明を行ったうえで権限を要求する。
class OnboardingPage extends ConsumerStatefulWidget {
  /// オンボーディング画面を生成する。
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();

  int _pageIndex = 0;
  bool _isRequesting = false;

  static const List<_OnboardingStep> _steps = <_OnboardingStep>[
    _OnboardingStep(
      icon: Icons.volume_off,
      title: '静かに撮れるカメラ',
      body:
          '図書館や病院、寝ているお子さま・ペットの撮影など、'
          '静粛性が求められる場面のためのカメラアプリです。\n'
          'ビデオのフレームから静止画を切り出す方式のため、'
          '写真モードに比べて解像度・画質は控えめになります。',
    ),
    _OnboardingStep(
      icon: Icons.gavel,
      title: 'ご利用にあたって',
      body:
          '盗撮をはじめとする違法・迷惑行為への利用は固く禁止します。\n'
          '撮影対象のプライバシーを尊重し、必要な場合は必ず相手の同意を得てください。\n'
          '本アプリは画面を暗転させたまま撮影する「ステルスモード」を搭載していません。',
    ),
    _OnboardingStep(
      icon: Icons.privacy_tip,
      title: '権限について',
      body:
          '撮影のためにカメラの権限、保存のために写真ライブラリの権限を使用します。\n'
          '撮影した画像は端末外へ一切送信しません。ネットワークも使用しません。',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _pageIndex == _steps.length - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (int index) =>
                    setState(() => _pageIndex = index),
                itemBuilder: (BuildContext context, int index) =>
                    _StepView(step: _steps[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _steps.length,
                (int index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _pageIndex
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isRequesting ? null : _onPrimaryPressed,
                  child: Text(_isLastPage ? '同意して権限を許可する' : '次へ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPrimaryPressed() async {
    if (!_isLastPage) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    setState(() => _isRequesting = true);

    final PermissionService permissions = ref.read(permissionServiceProvider);
    await permissions.requestCamera();
    await permissions.requestPhotoLibrary();
    await ref
        .read(settingsProvider.notifier)
        .setOnboardingCompleted(completed: true);

    if (!mounted) {
      return;
    }
    unawaited(Navigator.of(context).pushReplacementNamed(AppRoutes.camera));
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            step.icon,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(step.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
