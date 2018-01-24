Pod::Spec.new do |s|
  s.name         = 'ios-ntp'
  s.version      = '1.1.7'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.homepage     = 'https://github.com/jbenet/ios-ntp'
  s.author       = { 'Gavin Eadie' => 'https://github.com/gavineadie' }
  s.summary      = 'SNTP implementation for iOS.'
  s.source       = { :git => 'https://github.com/jbenet/ios-ntp.git', :tag => '1.1.6' }
  s.source_files = 'ios-ntp-lib/*.{h,m}'
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
end
