Pod::Spec.new do |s|
  s.name             = 'credenzapassport'
  s.version          = '1.2.1'
  s.summary          = 'The PassportUtility class is used to handle NFC tag reading and writing for a passport-enabled tag.'

  s.description      = <<-DESC
  'It includes various methods for initializing credentials, reading NFC tags, interacting with smart contracts, and performing authentication.'
                       DESC

  s.homepage         = 'https://github.com/credenza-web3/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Sandy' => 'sandy@macrodemic.com' }
  s.source           = { :git => 'https://github.com/credenza-web3/passport-pod.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.source_files = 'credenzapassport/Classes/**/*'
  
  s.dependency 'NFCReaderWriter'
  s.dependency 'QRCodeSwiftScanner'
  s.dependency 'Web3', '~> 0.4'
  s.dependency 'Web3/ContractABI'
  s.dependency 'Web3/PromiseKit'
  s.swift_version = "5.0.0"
end
