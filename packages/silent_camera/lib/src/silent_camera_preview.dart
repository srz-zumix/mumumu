import 'package:flutter/widgets.dart';

import 'models.dart';

/// 無音カメラのライブプレビュー。
///
/// ネイティブ側のテクスチャをそのまま描画し、指定されたアスペクト比に
/// 応じてレターボックス表示する。
class SilentCameraPreview extends StatelessWidget {
  const SilentCameraPreview({
    required this.session,
    this.aspectRatio,
    super.key,
  });

  final SilentCameraSession session;

  /// 表示に用いるアスペクト比。未指定時はプレビュー本来の比率を用いる。
  final AspectRatioPreset? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final targetRatio = aspectRatio?.value ?? session.previewSize.aspectRatio;
    return AspectRatio(
      aspectRatio: targetRatio,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: session.previewSize.width,
            height: session.previewSize.height,
            child: Texture(textureId: session.textureId),
          ),
        ),
      ),
    );
  }
}
