//
//  AppSetting.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 28/12/23.
//

import Foundation

final class AppSettings: NSObject {
    
    
    class var authToken: String {
        get { UserDefaults.standard.string(forKey: "Token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "Token") }
    }
    
    class var chainId: String {
        return (Bundle.main.infoDictionary?["CHAINID"] as? String) ?? ""
    }
    
    class var baseUrl: String {
        return (Bundle.main.infoDictionary?["BASEURL"] as? String) ?? ""
    }
    
    class var kryPTKey: String {
        return (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
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