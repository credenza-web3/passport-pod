//
//  PassportUtility.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 10/31/22.
//


// TO DO:  ConnectedContract (Solidity), CheckOwnership Function, WriteOwnership Function, PostEvent, Mirror for Credit Lib, ReadContract

import NFCReaderWriter
import WebKit
import MagicSDK
import MagicSDK_Web3
import Foundation

public protocol PassportDelegate {
    // Define expected delegate functions
    func loginComplete(address: String)
    func nfcScanComplete(address: String)
}

open class PassportUtility:NSObject,NFCReaderDelegate {

    public let readerWriter = NFCReaderWriter.sharedInstance()

    let magic = Magic.shared
    
    var delegation:PassportDelegate
    
    public init(delegate: PassportDelegate){
        delegation=delegate
    }

    // MARK: - Actions
    
    // iOS 13 NFC Tag Reader: Tag Info and NFCNDEFMessage
    public func readNFC()  {
        //checkMembershipOwnership("a","b")
         callChain("LoyaltyContract");

        readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Scan Your Passport-Enabled Tag")
        readerWriter.begin()
        //readerWriter.detectedMessage = "detected Tag info"
    }

    struct Album: Codable, Hashable {
        let collectionId: Int
        let collectionName: String
        let collectionPrice: Double
    }

    
    public func authN(){
        
        var postData : Data;
        let headers = [
          "accept": "application/json",
          "content-type": "application/json",
          "X-API-Key": "4ouieBFuLE1J5icxWwsYiOY1VzPNxwQiQX4FfjWm9sTtjlFFm9sFbefxB83iNf2C"
        ]
        let parameters = ["timeout": 15, "address":"0x56bafed9ba9f918594505d93f283b26700ae1d9f"] as [String : Any]

        
        do {
            try postData = JSONSerialization.data(withJSONObject: parameters, options: []);
            let request = NSMutableURLRequest(url: NSURL(string:"https://deep-index.moralis.io/api/v2/0x56bafed9ba9f918594505d93f283b26700ae1d9f/logs?chain=rinkeby")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                                timeoutInterval: 10.0)
            request.httpMethod = "GET"
            request.allHTTPHeaderFields = headers
            //request.httpBody = postData as Datad

            let session = URLSession.shared
            let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
              if (error != nil) {
                print(error as Any)
              } else {
                let httpResponse = response as? HTTPURLResponse
                let new1 = String(decoding: data!, as: UTF8.self)
                //print(new1)
              }
            })
            dataTask.resume()

        } catch {
            print(error)
        }

        
    }

    //MARK: - Email Login with PromiEvents
    public func handleSignIn(_ emailAddress: String) {
        let magic = Magic.shared
        guard let magic = magic else { return }
        //var web3 = Web3.init(provider: Magic.shared.rpcProvider)

        let configuration = LoginWithMagicLinkConfiguration(email: emailAddress)
        magic.auth.loginWithMagicLink(configuration, eventLog: true).once(eventName: AuthModule.LoginWithMagicLinkEvent.emailSent.rawValue){
            print("email-sent")
        }.done { token -> Void in

            let defaults = UserDefaults.standard
            defaults.set(token, forKey: "Token")
            //defaults.set(self.emailInput.text, forKey: "Email")

            //print(token)
            self.getAccount();

        }.catch { error in
            print("Error", error)
        }
    }

    public func getAccount() {

        var web3 = Web3.init(provider: Magic.shared.rpcProvider)

        firstly {
            // Get user's Ethereum public address
            web3.eth.accounts()
        }.done { accounts -> Void in
            if let account = accounts.first {
                // Set to UILa
                //print(account.hex(eip55: false))
                self.delegation.nfcScanComplete(address: account.hex(eip55: false))
                
                //self.checkOwnership(account.hex(eip55: false))
            } else {
                print("No Account Found")
            }
        }.catch { error in
            print("Error loading accounts and balance: \(error)")
        }
    }
    
    public func checkNFTOwnership(_ address:String) {

            do {
                var web3 = Web3.init(provider: Magic.shared.rpcProvider)

                /// Construct contract instance
                let contractABI = """
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
                    """.data(using: .utf8)!
                let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: "0x4d20968f609bf10e06495529590623d5d858c5c7"))

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
    
    public func checkMembershipOwnership (_ contractAddress:String, _ contractType:String, _ contractABI:Data) async {
        
        //callAPI("https://unpkg.com/@credenza-web3/contracts/artifacts/LoyaltyContract.json");
        do {
            var web3 = Web3.init(provider: Magic.shared.rpcProvider)
            
            /// Construct contract instance
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: "0x61ff3d77ab2befece7b1c8e0764ac973ad85a9ef"))
            
            /// contract call
            contract["getVersion"]?().call() { response, error in
                if let response = response {
                    print(response)
                } else {
                    print(error?.localizedDescription ?? "Failed to get response")
                }
            }
        } catch {
            /// Error handling
            print(error.localizedDescription)
        }
    }

    func callChain(_ contractName:String) async {
        guard let url = URL(string: "https://unpkg.com/@credenza-web3/contracts/artifacts/"+contractName+".json")
            else{
                return
            }

        let task = URLSession.shared.dataTask(with: url){ [self]
            data, response, error in
            
            if let data = data, let string = String(data: data, encoding: .utf8){
                //print(string)
                var dictonary:NSDictionary?
                
                if let data = string.data(using: String.Encoding.utf8) {
                    
                    do {
                        dictonary = try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject] as NSDictionary?
                    
                        if let myDictionary = dictonary
                        {
                            
                            guard let data = try? JSONSerialization.data(withJSONObject: myDictionary["abi"], options: []) else{ return }
                            let Jase = String(data: data, encoding: String.Encoding.utf8)
                            let abby = Jase!.data(using: .utf8)! as! Data
                            checkMembershipOwnership("",contractName, abby)
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                }
            }
        }

        task.resume()
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
    
    public func getTandefgInfos(_ tag: __NFCTag) -> [String: Any] {
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
            if (item.key=="Identifier"){
                serialID=item.value as! String;
            }
        }
        DispatchQueue.main.async {
            self.delegation.nfcScanComplete(address: serialID)
            //self.loadContent(firstCheck);
        }
        //self.readerWriter. = "NFC Tag Info detected"
        self.readerWriter.end()
    }
    
    // MARK: - NFCTagReaderSessionDelegate

    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("tagReaderSessionDidBecomeActive")
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print( "tagReaderSession:didInvalidateWithError - \(error)" )
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {

        let tag = tags.first!
        var nfcTag7816: NFCISO7816Tag
        switch tags.first! {
          case let .iso7816(tag):
             nfcTag7816 = tag
           @unknown default :
                session.invalidate(errorMessage: "Tag not valid.")
                     return
           }

     session.connect(to: tags.first!) { (error: Error?) in
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




