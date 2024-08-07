Pod::Spec.new do |s|
  s.name             = 'credenzapassport'
  s.version          = '1.2.3'
  s.summary          = 'The PassportUtility class is used to handle NFC tag reading and writing for a passport-enabled tag.'

  s.description      = <<-DESC
  'It includes various methods for initializing credentials, reading NFC tags, interacting with smart contracts, and performing authentication.'
                       DESC

  s.homepage         = 'https://github.com/credenza-web3/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Credenza' => 'developer@credenza3.com' }
  s.source           = { :git => 'https://github.com/credenza-web3/passport-pod.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.source_files = 'credenzapassport/Classes/**/*'
  s.dependency 'NFCReaderWriter'
  s.dependency 'QRCodeSwiftScanner'
  s.dependency 'CWeb3', '~> 1.0.0'
  s.dependency 'CWeb3/ContractABI'
  s.dependency 'CWeb3/PromiseKit'
  s.swift_version = "5.0.0"
  
  s.xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end
