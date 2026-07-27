Pod::Spec.new do |s|
  s.name             = 'silent_camera'
  s.version          = '0.1.0'
  s.summary          = 'mumumu 向けの無音（静音）キャプチャプラグイン。'
  s.description      = <<-DESC
AVCaptureVideoDataOutput のフレームから静止画を生成し、シャッター音を鳴らさずに撮影する。
                       DESC
  s.homepage         = 'https://github.com/srz-zumix/mumumu'
  s.license          = { :file => '../../../LICENSE' }
  s.author           = { 'srz-zumix' => 'https://github.com/srz-zumix' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
