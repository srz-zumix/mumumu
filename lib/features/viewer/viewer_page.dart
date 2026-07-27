import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:silent_camera/silent_camera.dart';

import '../camera/camera_controller.dart';

/// 撮影結果を確認するビューア。
class ViewerPage extends ConsumerWidget {
  const ViewerPage({required this.capture, super.key});

  static const String routeName = '/viewer';

  final CaptureResult capture;

  Future<void> _share() async {
    final path = capture.filePath;
    if (path == null) {
      return;
    }
    await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(path)]));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この写真をフォトライブラリから削除します。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(silentCameraProvider).deleteCapture(capture.uri);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除できませんでした: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = capture.filePath;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('プレビュー')),
      body: Center(
        child: path == null
            ? const Text(
                '表示できる画像がありません',
                style: TextStyle(color: Colors.white),
              )
            : InteractiveViewer(child: Image.file(File(path))),
      ),
      bottomNavigationBar: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
              tooltip: '共有',
              onPressed: path == null ? null : _share,
              icon: const Icon(Icons.share, color: Colors.white),
            ),
            IconButton(
              tooltip: 'ギャラリーで開く',
              onPressed: () =>
                  ref.read(silentCameraProvider).openInGallery(capture.uri),
              icon: const Icon(Icons.photo_library, color: Colors.white),
            ),
            IconButton(
              tooltip: '削除',
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
