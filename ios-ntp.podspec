Pod::Spec.new do |s|
  s.name         = 'ios-ntp'
  s.version      = '1.1.6'
  s.summary      = 'SNTP implementation for iOS.'
  s.homepage     = 'https://github.com/jbenet/ios-ntp'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => 'https://github.com/jbenet/ios-ntp.git', :tag => '1.1.6' }
  s.author       = { 'Gavin Eadie' => 'https://github.com/gavineadie' }
  s.ios.deployment_target = '7.0'
  s.tvos.deployment_target = '9.0'
  s.source_files = 'ios-ntp-lib/*.{h,m}', 'network-udp/*.{h,m}'
  s.framework = 'CFNetwork'
  s.requires_arc = true
end
