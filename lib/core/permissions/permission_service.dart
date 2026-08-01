import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// アプリが必要とする権限の状態。
enum AppPermissionStatus {
  /// 未リクエスト。
  notDetermined,

  /// 許可済み。
  granted,

  /// 拒否（再リクエスト可能）。
  denied,

  /// 恒久的に拒否（設定アプリでの変更が必要）。
  permanentlyDenied,
}

/// カメラ／写真ライブラリ権限の集約状態。
class PermissionSnapshot {
  /// 権限状態のスナップショットを生成する。
  const PermissionSnapshot({required this.camera, required this.photoLibrary});

  /// カメラ権限。
  final AppPermissionStatus camera;

  /// 写真ライブラリ（保存）権限。
  final AppPermissionStatus photoLibrary;

  /// 撮影が可能な状態かどうか。
  bool get canCapture => camera == AppPermissionStatus.granted;

  /// ギャラリーへ保存できる状態かどうか。
  bool get canSaveToGallery => photoLibrary == AppPermissionStatus.granted;
}

/// 権限リクエストとその状態取得を担当する。
///
/// 仕様書 5.1「権限フロー」および 6-1「オンボーディング」に対応する。
class PermissionService {
  /// 権限サービスを生成する。
  const PermissionService();

  /// 現在の権限状態を取得する。
  Future<PermissionSnapshot> check() async {
    return PermissionSnapshot(
      camera: _convert(await Permission.camera.status),
      photoLibrary: _convert(await _photoPermission.status),
    );
  }

  /// カメラ権限をリクエストする。
  Future<AppPermissionStatus> requestCamera() async =>
      _convert(await Permission.camera.request());

  /// 写真ライブラリへの保存権限をリクエストする。
  Future<AppPermissionStatus> requestPhotoLibrary() async =>
      _convert(await _photoPermission.request());

  /// 位置情報の権限をリクエストする。
  ///
  /// 仕様書 5.2 の「位置情報を Exif に付与する」設定を有効化するときのみ呼ぶ。
  Future<AppPermissionStatus> requestLocation() async =>
      _convert(await Permission.locationWhenInUse.request());

  /// 動画撮影用のマイク権限をリクエストする（フェーズ 2）。
  Future<AppPermissionStatus> requestMicrophone() async =>
      _convert(await Permission.microphone.request());

  /// 端末の設定アプリを開く。
  Future<bool> openSettings() => openAppSettings();

  /// iOS は「追加のみ」の権限で足りるため、保存に必要な最小権限を選ぶ。
  Permission get _photoPermission =>
      Platform.isIOS ? Permission.photosAddOnly : Permission.photos;

  static AppPermissionStatus _convert(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (status.isDenied) {
      return AppPermissionStatus.denied;
    }
    return AppPermissionStatus.notDetermined;
  }
}

/// [PermissionService] を供給する。
final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

/// 現在の権限状態を取得する。
final FutureProvider<PermissionSnapshot> permissionSnapshotProvider =
    FutureProvider<PermissionSnapshot>(
      (Ref ref) => ref.watch(permissionServiceProvider).check(),
    );
