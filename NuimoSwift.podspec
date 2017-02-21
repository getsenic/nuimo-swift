Pod::Spec.new do |s|
  s.name         = "NuimoSwift"
  s.version      = "0.8.0"
  s.summary      = "Swift library for connecting and communicating with Senic's Nuimo controllers"
  s.description  = <<-DESC
                     Swift library for connecting and communicating with Senic's Nuimo controllers
                     * Discover and connect Nuimo controllers via bluetooth low energy or websockets
                     * Receive user gestures from Nuimo controllers
                     * Send LED matrices to Nuimo controllers
                   DESC
  s.documentation_url = 'https://github.com/getSenic/nuimo-swift'
  s.homepage     = "http://senic.com"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Lars Blumberg (Senic GmbH)" => "lars@senic.com" }
  s.social_media_url   = "http://twitter.com/heysenic"
  s.ios.deployment_target  = "8.0"
  s.osx.deployment_target  = "10.10"
  s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/getSenic/nuimo-swift.git", :tag => "#{s.version}" }
  s.source_files = "SDK/*.swift"
  s.framework    = 'CoreBluetooth'
end
