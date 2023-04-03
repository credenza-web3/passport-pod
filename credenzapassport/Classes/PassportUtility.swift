//
//  PassportUtility.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 10/31/22.
//


// TO DO:  PostEvent

//Docs,

import NFCReaderWriter
import MagicSDK
import MagicSDK_Web3
import Foundation

public protocol PassportDelegate {
    // Define expected delegate functions
    func loginComplete(address: String)
    func nfcScanComplete(address: String)
}

open class PassportUtility: NSObject, NFCReaderDelegate {
    
    // MARK: Local Variables
    fileprivate var authenticationTokenC = ""
    fileprivate var NFTContractAddressC = ""
    fileprivate var storedValueContractAddressC = ""
    fileprivate var connectedContractAddressC = ""
    
    public let readerWriter = NFCReaderWriter.sharedInstance()
    let magic = Magic.shared
    fileprivate var delegation: PassportDelegate
    
    public init(delegate: PassportDelegate) {
        delegation = delegate
    }
    
    // MARK: - Helper methods
    public func initializeCredentials(authenticationToken: String, NFTContractAddress: String, storedValueContractAddress: String, connectedContractAddress: String) {
        self.authenticationTokenC = "https://deep-index.moralis.io/api/v2/\(authenticationToken)/logs?chain=rinkeby" // moralisURL
        self.NFTContractAddressC = NFTContractAddress
        self.storedValueContractAddressC = storedValueContractAddress
        self.connectedContractAddressC = connectedContractAddress
    }
    
    // MARK: - Actions
    // iOS 13 NFC Tag Reader: Tag Info and NFCNDEFMessage
    public func readNFC() {
        readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Scan Your Passport-Enabled Tag")
        readerWriter.begin()
    }
    
    public func getVersion() async {
        let versionNumber = await checkVersion("0x61ff3d77ab2befece7b1c8e0764ac973ad85a9ef", "LoyaltyContract")
        print (versionNumber)
    }
    
    public func authN() {
        do {
            guard let url = NSURL(string: authenticationTokenC) else { return }
            let request = NSMutableURLRequest(url: url as URL,
                                              cachePolicy: .useProtocolCachePolicy,
                                              timeoutInterval: 10.0)
            request.httpMethod = "GET"
            //request.httpBody = postData as Datad
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
                if (error != nil) {
                    print(error as Any)
                } else {
                }
            })
            dataTask.resume()
        }
    }
    
    public func handleSignIn(_ emailAddress: String) {
        
        let magic = Magic.shared

        guard let magic = magic else { return }
        let configuration = LoginWithMagicLinkConfiguration(email: emailAddress)
        magic.auth.loginWithMagicLink(configuration, eventLog: true).once(eventName: AuthModule.LoginWithMagicLinkEvent.emailSent.rawValue){
            print("email-sent")
        }.done { token -> Void in
            let defaults = UserDefaults.standard
            defaults.set(token, forKey: "Token")
            self.getAccount();
        }.catch { error in
            print("Error", error)
        }
        
    }
    
    public func getAccount() {
        
        let web3 = Web3.init(provider: Magic.shared.rpcProvider)
        
        firstly {
            // Get user's Ethereum public address
            web3.eth.accounts()
        }.done { accounts -> Void in
            if let account = accounts.first {
                // Set to UILa
                self.delegation.loginComplete(address: account.hex(eip55: false))
            } else {
                print("No Account Found")
            }
        }.catch { error in
            print("Error loading accounts and balance: \(error)")
        }
    }
    
    
    public func nftCheck(_ contractAddress: String, _ userAddress: String) async -> BigUInt {
        
        let contractABI = await getContractABI("OzzieContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            return await withCheckedContinuation { continuation in
                
                contract["balanceOfBatch"]?([add2],[2]).call(){ response, error in
                    if let response = response {
                        //continuation.resume(returning: response[""][0] as! BigUInt)
                        // return response;
                        debugPrint(response)
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return BigUInt()
        
    }
    
    public func checkNFTOwnership(_ address: String) {
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            /// Construct contract instance
            guard let contractABI = """
                        [{
                              "inputs": [
                                  {
                                    "internalType": "address[]",
                                    "name": "accounts",
                                    "type": "address[]"
                                  },
                                  {
                                    "internalType": "uint256[]",
                                    "name": "ids",
                                    "type": "uint256[]"
                                  }
                                ],
                              "name": "balanceOfBatch",
                              "outputs": [
                                {
                                  "internalType": "uint256[]",
                                  "name": "",
                                  "type": "uint256[]"
                                }
                              ],
                              "stateMutability": "view",
                              "type": "function"
                            }]
                    """.data(using: .utf8) else { return }
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: NFTContractAddressC))
            
            /// contract call
            contract["balanceOfBatch"]?(["0xfb28530d9d065ec81e826fa61baa51748c1ee775"],[2]).call() { response, error in
                if let response = response, let message = response[""] as? String {
                    print(message.description)
                } else {
                    print(error?.localizedDescription ?? "Failed to get response")
                }
            }
        } catch {
            /// Error handling
            print(error.localizedDescription)
        }
        
    }
    
    public func checkVersion(_ contractAddress: String, _ contractType: String) async -> String {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            return await withCheckedContinuation { continuation in
                contract["getVersion"]?().call() { response, error in
                    if let response = response {
                        continuation.resume(returning: response["version"] as? String ?? "")
                        //return response;
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return "NONE"
        
    }
    
    public func addMembership(_ contractAddress: String, _ userAddress: String, _ metadata: String) async {
        
        let contractABI = await getContractABI("MetadataMembershipContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["addMembership"]?(add2, metadata).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: 80001) else { return }
                    let result = web3.eth.sendRawTransaction(transaction: signedTx)
                    debugPrint(result)
                }.done { txHash in
                    print(txHash)
                }.catch { error in
                    print(error)
                }
        } catch {
            print(error.localizedDescription)
        }
        return
        
    }
    
    public func removeMembership(_ contractAddress: String, _ userAddress: String) async {
        
        let contractABI = await getContractABI("MetadataMembershipContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["removeMembership"]?(add2).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: 80001) else { return }
                    let result = web3.eth.sendRawTransaction(transaction: signedTx)
                    debugPrint(result)
                }.done { txHash in
                    print(txHash)
                }.catch { error in
                    print(error)
                }
        } catch {
            print(error.localizedDescription)
        }
        return
    }
    
    public func checkMembership(_ contractAddress: String, _ ownerAddress: String, _ userAddress: String) async -> Bool {
        
        let contractABI = await getContractABI("MetadataMembershipContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add1 = try? EthereumAddress(hex: ownerAddress,eip55: false) else { return Bool() }
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return Bool() }
            
            return await withCheckedContinuation { continuation in
                contract["confirmMembership"]?(add1,add2).call() { response, error in
                    if let response = response {
                        continuation.resume(returning: (response[""] as? Bool) ?? Bool())
                        //return response;
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return false
    }
    
    public func loyaltyCheck(_ contractAddress: String, _ userAddress: String) async -> BigUInt {
        
        let contractABI = await getContractABI("LoyaltyContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            return await withCheckedContinuation { continuation in
                contract["checkPoints"]?(add2).call() { response, error in
                    if let response = response {
                        continuation.resume(returning: (response[""] as? BigUInt) ?? BigUInt())
                        //return response;
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return BigUInt()
        
    }
    
    public func loyaltyAdd(_ contractAddress: String, _ userAddress: String, _ points: UInt) async {
        
        let contractABI = await getContractABI("LoyaltyContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["addPoints"]?(add2, points).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: 80001) else { return }
                    let result = web3.eth.sendRawTransaction(transaction: signedTx)
                     debugPrint(result)
                }.done { txHash in
                    print(txHash)
                }.catch { error in
                    print(error)
                }
        } catch {
            print(error.localizedDescription)
        }
        return
        
    }
    
    public func svCheck(_ contractAddress: String, _ userAddress: String) async -> BigUInt {
        
        let contractABI = await getContractABI("ERC20TestContract");
        let contractAddress = storedValueContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            return await withCheckedContinuation { continuation in
                contract["balanceOf1"]?(add2).call() { response, error in
                    if let response = response {
                        continuation.resume(returning: (response[""] as? BigUInt) ?? BigUInt())
                        //return response;
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return BigUInt()
    }
    
    public func connectedPackageQuery(serialNumber: String) async -> String {
        
        let contractABI = await getContractABI("ConnectedPackagingContract");
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            //let add2=try? EthereumAddress(hex: userAddress,eip55: false)
            
            return await withCheckedContinuation { continuation in
                contract["retrieveConnection"]?(serialNumber).call() { response, error in
                    if let response = response {
                        let eth = response[""] as? EthereumAddress
                        continuation.resume(returning: eth?.hex(eip55: false) ?? "")
                        //return response;
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return "ERROR"
    }
    
    public func connectedPackagePublish(userAddress: String, serialNumber: String) async {
        
        let contractABI = await getContractABI("ConnectedPackagingContract");
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{nonce in
                    let transaction = contract["claimConnection"]?(serialNumber,add2).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: 80001) else { return }
                    let result = web3.eth.sendRawTransaction(transaction: signedTx)
                     debugPrint(result)
                }.done { txHash in
                    print(txHash)
                }.catch { error in
                    print(error)
                }
        } catch {
            print(error.localizedDescription)
        }
        return
    }
    
    public func connectedPackagePurge(serialNumber: String) async {
        
        let contractABI = await getContractABI("ConnectedPackagingContract");
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{nonce in
                    let transaction = contract["revokeConnection"]?(serialNumber).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: 80001) else { return }
                    let result = web3.eth.sendRawTransaction(transaction: signedTx)
                    debugPrint(result)
                }.done { txHash in
                    print(txHash)
                }.catch { error in
                    print(error)
                }
        } catch {
            print(error.localizedDescription)
        }
        return
    }
    
    //TODO: convert NONEs to THROWS
    func getContractABI(_ contractName: String) async -> Data {
        //TODO: cache the contract ABIs
        guard let thisurl = URL(string: "https://unpkg.com/@credenza-web3/contracts/artifacts/"+contractName+".json")
        else{ return Data(count:2) }
        
        let request = URLRequest(url: thisurl)
        do {
            let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { fatalError("Error while fetching data") }
            
            if let string = String(data: data, encoding: .utf8) {
                var dictonary:NSDictionary?
                
                if let data = string.data(using: String.Encoding.utf8) {
                    do {
                        dictonary = try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject] as NSDictionary?
                        
                        if let myDictionary = dictonary{
                            guard let data = try? JSONSerialization.data(withJSONObject: myDictionary["abi"] as Any, options: []) else{ return Data(count: 0)}
                            guard let Jase = String(data: data, encoding: String.Encoding.utf8) else { return Data(count: 0) }
                            guard let contractABI = Jase.data(using: .utf8) else { return Data(count: 0)}
                            
                            return contractABI
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                }
            }
        } catch let err {
            debugPrint(err)
        }
        
        return Data(count: 0)
    }
    
    // MARK: - Utilities
    public func contentsForMessages(_ messages: [NFCNDEFMessage]) -> String {
        var recordInfos = ""
        
        for message in messages {
            for (i, record) in message.records.enumerated() {
                recordInfos += "Record(\(i + 1)):\n"
                recordInfos += "Type name format: \(record.typeNameFormat.rawValue)\n"
                recordInfos += "Type: \(record.type as NSData)\n"
                recordInfos += "Identifier: \(record.identifier)\n"
                recordInfos += "Length: \(message.length)\n"
                
                if let string = String(data: record.payload, encoding: .ascii) {
                    recordInfos += "Payload content:\(string)\n"
                }
                recordInfos += "Payload raw data: \(record.payload as NSData)\n\n"
            }
        }
        
        return recordInfos
    }
    
    public func getTagInfos(_ tag: __NFCTag) -> [String: Any] {
        var infos: [String: Any] = [:]
        
        switch tag.type {
        case .miFare:
            if let miFareTag = tag.asNFCMiFareTag() {
                switch miFareTag.mifareFamily {
                case .desfire:
                    infos["TagType"] = "MiFare DESFire"
                case .ultralight:
                    infos["TagType"] = "MiFare Ultralight"
                case .plus:
                    infos["TagType"] = "MiFare Plus"
                case .unknown:
                    infos["TagType"] = "MiFare compatible ISO14443 Type A"
                @unknown default:
                    infos["TagType"] = "MiFare unknown"
                }
                if let bytes = miFareTag.historicalBytes {
                    infos["HistoricalBytes"] = bytes.hexadecimal
                }
                infos["Identifier"] = miFareTag.identifier.hexadecimal
            }
        case .iso7816Compatible:
            if let compatibleTag = tag.asNFCISO7816Tag() {
                infos["TagType"] = "ISO7816"
                infos["InitialSelectedAID"] = compatibleTag.initialSelectedAID
                infos["Identifier"] = compatibleTag.identifier.hexadecimal
                if let bytes = compatibleTag.historicalBytes {
                    infos["HistoricalBytes"] = bytes.hexadecimal
                }
                if let data = compatibleTag.applicationData {
                    infos["ApplicationData"] = data.hexadecimal
                }
                infos["OroprietaryApplicationDataCoding"] = compatibleTag.proprietaryApplicationDataCoding
            }
        case .ISO15693:
            if let iso15693Tag = tag.asNFCISO15693Tag() {
                infos["TagType"] = "ISO15693"
                infos["Identifier"] = iso15693Tag.identifier
                infos["ICSerialNumber"] = iso15693Tag.icSerialNumber.hexadecimal
                infos["ICManufacturerCode"] = iso15693Tag.icManufacturerCode
            }
            
        case .feliCa:
            if let feliCaTag = tag.asNFCFeliCaTag() {
                infos["TagType"] = "FeliCa"
                infos["Identifier"] = feliCaTag.currentIDm
                infos["SystemCode"] = feliCaTag.currentSystemCode.hexadecimal
            }
        default:
            break
        }
        return infos
    }
    
    public func readerDidBecomeActive(_ session: NFCReader) {
        print("Reader did become")
    }
    
    public func reader(_ session: NFCReader, didInvalidateWithError error: Error) {
        print("ERROR:\(error)")
        readerWriter.end()
    }
    /// --------------------------------
    // MARK: - 3. NFC Tag Reader(iOS 13)
    /// --------------------------------
    public func reader(_ session: NFCReader, didDetect tag: __NFCTag, didDetectNDEF message: NFCNDEFMessage) {
        //let thisTagId = readerWriter.tagIdentifier(with: tag)
        //let content = contentsForMessages([message])
        
        let tagInfos = getTagInfos(tag)
        var tagInfosDetail = ""
        var serialID = ""
        tagInfos.forEach { (item) in
            tagInfosDetail = tagInfosDetail + "\(item.key): \(item.value)\n"
            if (item.key == "Identifier") {
                serialID = ((item.value) as? String) ?? ""
            }
        }
        DispatchQueue.main.async {
            self.delegation.nfcScanComplete(address: serialID)
            //self.loadContent(firstCheck);
        }
        //self.readerWriter. = "NFC Tag Info detected"
        self.readerWriter.end()
    }
    
    public func reader(_ session: NFCReader, didDetect tags: [NFCNDEFTag]) {
        print("BOBOBO")
    }
    
    // MARK: - NFCTagReaderSessionDelegate
    
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("tagReaderSessionDidBecomeActive")
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print( "tagReaderSession:didInvalidateWithError - \(error)" )
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        
        //let tag = tags.first!
        guard let tag = tags.first else { return }
        var nfcTag7816: NFCISO7816Tag
        switch tag {
        case let .iso7816(tag):
            nfcTag7816 = tag
        default :
            session.invalidate(errorMessage: "Tag not valid.")
            return
        }
        
        session.connect(to: tag) { (error: Error?) in
            if error != nil {
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            else {
                let myAPDU = NFCISO7816APDU(instructionClass:0, instructionCode:0xB0, p1Parameter:0, p2Parameter:0, data: Data(), expectedResponseLength:16)
                nfcTag7816.sendCommand(apdu: myAPDU) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?)
                    in
                    
                    guard error != nil && !(sw1 == 0x90 && sw2 == 0) else {
                        session.invalidate(errorMessage: "Applicationfailure")
                        return
                    }
                }
            }
        }
    }
    
}

extension Data {
    /// Hexadecimal string representation of `Data` object.
    var hexadecimal: String {
        return map { String(format: "%02x", $0) }
        .joined()
    }
}




