Pod::Spec.new do |s|
  s.name             = "Freshpaint"
  s.module_name      = "Freshpaint"
  s.version          = "1.0.0"
  s.summary          = "The hassle-free way to add analytics to your iOS app."

  s.description      = <<-DESC
                       The Freshpaint iOS SDK for sending data from your iOS
                       app into Freshpaint.
                       DESC

  s.homepage         = "https://freshpaint.io/"
  s.author           = { "Freshpaint" => "michael@freshpaint.io" }
  s.license          = "No License"
  s.source           = { "git" => "" }

  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '9.0'

  s.ios.frameworks = 'CoreTelephony'
  s.frameworks = 'Security', 'StoreKit', 'SystemConfiguration', 'UIKit'

  s.preserve_paths = 'freshpaint.a'

  s.source_files = [
    'Freshpaint/Classes/**/*.h',
    'Freshpaint/Internal/**/*.h'
  ]
  s.vendored_libraries = 'freshpaint.a'
end
