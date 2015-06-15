Pod::Spec.new do |s|
  s.name         = 'ios-ntp'
  s.version      = '1.1'
  s.summary      = 'SNTP implementation for iOS.'
  s.homepage     = 'https://github.com/jbenet/ios-ntp'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => 'https://github.com/jbenet/ios-ntp.git', :tag => '1.1' }
  s.author       = { 'Gavin Eadie' => 'https://github.com/gavineadie' }
  s.ios.deployment_target = '7.0'
  s.source_files = 'ios-ntp-lib/*.{h,m}'
  s.resources = 'ios-ntp-rez/*.hosts',
  s.framework = 'CFNetwork'
  s.dependency 'CocoaAsyncSocket', '~>7.4.1'
  s.requires_arc = true
end
