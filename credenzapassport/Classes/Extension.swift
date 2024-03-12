//
//  Extension.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 11/03/24.
//

import Foundation
import CryptoKit
import CommonCrypto

extension String {
    
    func hashSha256() -> Data {
        if let data = self.data(using: .utf8) {
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            _ = data.withUnsafeBytes {
                CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
            }
            return Data(digest)
        }
        return Data()
    }

}

extension Data {
    
    func base64urlencode() -> String {
        let base64Encoded = self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64Encoded
    }
}
