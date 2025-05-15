Pod::Spec.new do |s|
  s.name             = "Freshpaint"
  s.module_name      = "FreshpaintSDK"
  s.version          = "0.2.3"
  s.summary          = "Integrate Freshpaint with your iOS App."

  s.description      = <<-DESC
                       The Freshpaint iOS SDK for sending data from your iOS
                       app into Freshpaint.
                       DESC

  s.homepage         = "https://freshpaint.io/"
  s.author           = { "Freshpaint" => "michael@freshpaint.io" }
  s.license          = "MIT"
  s.source           = { "git" => "https://github.com/freshpaint-io/freshpaint-ios.git", "tag" => "0.2.3" }

  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '9.0'

  s.ios.frameworks = 'CoreTelephony'
  s.frameworks = 'Security', 'StoreKit', 'SystemConfiguration', 'UIKit'

  s.source_files = [
    'Freshpaint/Classes/**/*',
    'Freshpaint/Internal/**/*'
  ]
end
