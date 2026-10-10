Pod::Spec.new do |s|
  s.name = 'foldable_info'
  s.version = '0.1.0'
  s.summary = 'Native fold, angle and view information for Flutter.'
  s.description = s.summary
  s.homepage = 'https://github.com/ViUniverse/foldable_info'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = 'Vi Universe'
  s.source = { :path => '.' }
  s.source_files = 'foldable_info/Sources/foldable_info/**/*.{h,m}'
  s.public_header_files = 'foldable_info/Sources/foldable_info/include/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
