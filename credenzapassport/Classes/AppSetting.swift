//
//  AppSetting.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 28/12/23.
//

import Foundation

final class AppSettings: NSObject {
    
    let contractType = "ConnectedPackagingContract"
    
    class var authToken: String? {
        get { UserDefaults.standard.string(forKey: "Token") }
        set { UserDefaults.standard.set(newValue, forKey: "Token") }
    }
    
    class var loginCode: String? {
        get { UserDefaults.standard.string(forKey: "LOGINCODE") }
        set { UserDefaults.standard.set(newValue, forKey: "LOGINCODE") }
    }
    
    class var ethAddress: String? {
        get { UserDefaults.standard.string(forKey: "ETHEREAUMADDRESS") }
        set { UserDefaults.standard.set(newValue, forKey: "ETHEREAUMADDRESS") }
    }
    
    class var signature: String? {
        get { UserDefaults.standard.string(forKey: "SIGNEDSIGNATURE") }
        set { UserDefaults.standard.set(newValue, forKey: "SIGNEDSIGNATURE") }
    }

    class var chainId: String {
        return (Bundle.main.infoDictionary?["CHAINID"] as? String) ?? ""
    }
    
    class var passCodeBaseUrl: String {
        return (Bundle.main.infoDictionary?["PASSCODEBASEURL"] as? String) ?? ""
    }
    
    class var accountBaseUrl: String {
        return (Bundle.main.infoDictionary?["ACCOUNTBASEURL"] as? String) ?? ""
    }
    
    class var evmBaseUrl: String {
        return (Bundle.main.infoDictionary?["EVMBASEURL"] as? String) ?? ""
    }
    
    class var rpcUrl: String {
        return (Bundle.main.infoDictionary?["RPCURL"] as? String) ?? ""
    }
    
    class var connectedPackagingContract: String {
        return (Bundle.main.infoDictionary?["CONNECTEDCONTRACTADDRESSC"] as? String) ?? ""
    }
    
    class var kryPTKey: String {
        return (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
    }
    
    class var clientID: String {
        return (Bundle.main.infoDictionary?["CLIENTID"] as? String) ?? ""
    }
    
    class var clientSecret: String {
        return (Bundle.main.infoDictionary?["CLIENTSECRET"] as? String) ?? ""
    }
    
    class var nftContractAddressC: String {
            return (Bundle.main.infoDictionary?["NFTCONTRACTADDRESSC"] as? String) ?? ""
        }

    class var storedValueContractAddressC: String {
            return (Bundle.main.infoDictionary?["STOREDVALUECONTRACTADDRESSC"] as? String) ?? ""
        }

    class var connectedContractAddressC: String {
            return (Bundle.main.infoDictionary?["CONNECTEDCONTRACTADDRESSC"] as? String) ?? ""
        }
    
}
