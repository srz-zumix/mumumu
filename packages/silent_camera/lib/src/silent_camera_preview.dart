import 'package:flutter/widgets.dart';

import 'silent_camera_controller.dart';

/// ライブプレビューを描画するウィジェット。
///
/// 仕様書 6-2 のとおり、指定アスペクト比に応じたレターボックス表示を行う。
/// プラットフォームごとに異なるテクスチャの向き・鏡像はここで吸収する。
class SilentCameraPreview extends StatelessWidget {
  /// ライブプレビューを描画するウィジェットを生成する。
  const SilentCameraPreview({
    required this.controller,
    this.aspectRatio,
    super.key,
  });

  /// 表示対象のコントローラ。
  final SilentCameraController controller;

  /// 表示するアスペクト比（横 / 縦）。null の場合はプレビュー本来の比率を使う。
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SilentCameraValue>(
      valueListenable: controller,
      builder: (BuildContext context, SilentCameraValue value, Widget? _) {
        final int? textureId = value.textureId;
        final Size? previewSize = value.previewSize;
        if (!value.isInitialized || textureId == null || previewSize == null) {
          return const SizedBox.expand();
        }

        Widget preview = Texture(textureId: textureId);

        if (value.previewQuarterTurns != 0) {
          preview = RotatedBox(
            quarterTurns: value.previewQuarterTurns,
            child: preview,
          );
        }

        if (value.previewFlipHorizontally) {
          preview = Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),
            child: preview,
          );
        }

        final double nativeRatio = previewSize.height == 0
            ? 1
            : previewSize.width / previewSize.height;

        return ClipRect(
          child: AspectRatio(
            aspectRatio: aspectRatio ?? nativeRatio,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: preview,
              ),
            ),
          ),
        );
      },
    );
  }
}
