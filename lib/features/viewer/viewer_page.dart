import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../platform/silent_camera_providers.dart';
import '../camera/camera_screen_controller.dart';

/// ビューア画面。仕様書 6-3 に対応する。
///
/// 撮影画像の確認・共有・削除・システムギャラリーで開く操作を提供する。
class ViewerPage extends ConsumerWidget {
  /// ビューア画面を生成する。
  const ViewerPage({required this.capture, super.key});

  /// 表示対象の撮影結果。
  final CaptureResult capture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? galleryUri = capture.galleryUri;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(capture.fileName ?? '撮影結果'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(capture.filePath),
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) =>
                    const Text(
                      '画像を表示できませんでした。',
                      style: TextStyle(color: Colors.white),
                    ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
              tooltip: '共有',
              color: Colors.white,
              icon: const Icon(Icons.share),
              onPressed: () => unawaited(_share(context)),
            ),
            IconButton(
              tooltip: 'ギャラリーで開く',
              color: Colors.white,
              icon: const Icon(Icons.photo_library),
              onPressed: galleryUri == null
                  ? null
                  : () => unawaited(_openInGallery(ref, galleryUri)),
            ),
            IconButton(
              tooltip: '削除',
              color: Colors.white,
              icon: const Icon(Icons.delete_outline),
              onPressed: galleryUri == null
                  ? null
                  : () => unawaited(_confirmDelete(context, ref, galleryUri)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(<XFile>[XFile(capture.filePath)]);
    } on Exception {
      messenger.showSnackBar(const SnackBar(content: Text('共有できませんでした。')));
    }
  }

  Future<void> _openInGallery(WidgetRef ref, String galleryUri) async {
    await ref.read(silentCameraControllerProvider).openInGallery(galleryUri);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String galleryUri,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この写真を端末から削除します。この操作は取り消せません。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final bool deleted = await ref
          .read(silentCameraControllerProvider)
          .deleteFromGallery(galleryUri);
      if (deleted) {
        ref.read(cameraScreenProvider.notifier).clearLastCapture();
        navigator.pop();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('削除できませんでした。')));
      }
    } on SilentCameraException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
