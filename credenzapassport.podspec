#
# Be sure to run `pod lib lint credenzapassport.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'credenzapassport'
  s.version          = '1.1.5'
  s.summary          = 'The PassportUtility class is used to handle NFC tag reading and writing for a passport-enabled tag.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  'It includes various methods for initializing credentials, reading NFC tags, interacting with smart contracts, and performing authentication.'
                       DESC

  s.homepage         = 'https://github.com/credenza-web3/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Sandy' => 'sandy@macrodemic.com' }
  s.source           = { :git => 'https://github.com/credenza-web3/passport-pod.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '15.0'

  s.source_files = 'credenzapassport/Classes/**/*'
  
  # s.resource_bundles = {
  #   'credenzapassport' => ['credenzapassport/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.dependency 'NFCReaderWriter'
  s.dependency 'MagicSDK', '8.0.0'
  s.dependency 'QRCodeSwiftScanner'
#  s.dependency 'MagicExt-OAuth', '~> 2.0.0'
  s.dependency 'MagicSDK-Web3'
  s.swift_version = "5.0.0"
end
