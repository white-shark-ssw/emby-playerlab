platform :ios, '16.0'

install! 'cocoapods', :deterministic_uuids => true

project 'EmbyPlayerLab.xcodeproj'

target 'EmbyPlayerLab' do
  use_frameworks! :linkage => :static
  pod 'KTVHTTPCache', '3.1.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end
