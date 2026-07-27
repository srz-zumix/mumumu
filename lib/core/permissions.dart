import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// 権限リクエストの結果。
enum PermissionOutcome { granted, denied, permanentlyDenied }

/// 権限まわりの処理をまとめたサービス。
final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

/// カメラ / フォトライブラリ / マイクの権限を扱う。
class PermissionService {
  const PermissionService();

  /// 撮影に必要な権限（カメラ・フォトライブラリ）をまとめてリクエストする。
  ///
  /// アプリは保存のみを行い既存の写真を読み取らないため、
  /// `photos` ではなく追加専用の `photosAddOnly` を要求する。
  Future<PermissionOutcome> requestCapturePermissions() async {
    final statuses = await <Permission>[
      Permission.camera,
      Permission.photosAddOnly,
    ].request();
    return _reduce(statuses.values);
  }

  /// 動画撮影時に必要なマイク権限をリクエストする。
  Future<PermissionOutcome> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return _toOutcome(status);
  }

  /// 現在の権限状態を確認する（リクエストは行わない）。
  Future<bool> hasCapturePermissions() async {
    final camera = await Permission.camera.status;
    return camera.isGranted;
  }

  /// 端末の設定画面を開く。
  Future<bool> openSettings() => openAppSettings();

  static PermissionOutcome _reduce(Iterable<PermissionStatus> statuses) {
    var outcome = PermissionOutcome.granted;
    for (final status in statuses) {
      final current = _toOutcome(status);
      if (current == PermissionOutcome.permanentlyDenied) {
        return PermissionOutcome.permanentlyDenied;
      }
      if (current == PermissionOutcome.denied) {
        outcome = PermissionOutcome.denied;
      }
    }
    return outcome;
  }

  static PermissionOutcome _toOutcome(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }
}
