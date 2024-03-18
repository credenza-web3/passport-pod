//
//  PassportUtility.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 10/31/22.
//

import NFCReaderWriter
import Web3
import Foundation
import QRCodeSwiftScanner
import PassKit
import UIKit
import WebKit
import CryptoKit
import CommonCrypto

public protocol PassportDelegate {
    func loginComplete(address: String)
    func nfcScanComplete(address: String)
    func qrScannerSuccess(result: String)
    func qrScannerDidFail(error: Error)
    func qrScannerDidCancel()
    func passScanComplete(response: String)
}

/**
 The PassportUtility class is used to handle NFC tag reading and writing for a passport-enabled tag.
 It includes various methods for initializing credentials, reading NFC tags, interacting with smart contracts, and performing authentication.
 */
open class PassportUtility: NSObject, NFCReaderDelegate {
    
    // MARK: Local Variables
    fileprivate var address: String = ""
    fileprivate var token: String = ""
    fileprivate var signature: String = ""
    fileprivate var loginCode: String = ""
    fileprivate var accessToken: String = ""
    fileprivate var clientId: String = ""
    fileprivate var clientSecretId: String = ""
    fileprivate var IdToken: String = ""
    fileprivate var refreshToken: String = ""
    fileprivate let codeVerifier = UUID().uuidString
    fileprivate var codeChallenge: String = ""
    
    /// CompletionHandler to return address on readNFCAddress method
    private var NFCAddressCompletionHandler: ((String) -> Void)?
    
    /// The address of the NFT smart contract.
    fileprivate var nftContractAddressC = AppSettings.nftContractAddressC
    
    /// The address of the stored value smart contract.
    fileprivate var storedValueContractAddressC = AppSettings.storedValueContractAddressC
    
    /// The address of the connected smart contract.
    fileprivate var connectedContractAddressC = AppSettings.connectedContractAddressC
    
    /// An instance of the NFCReaderWriter class.
    public let readerWriter = NFCReaderWriter.sharedInstance()
    
    /// The PassportDelegate object used for delegation.
    fileprivate var delegation: PassportDelegate
    
    fileprivate var shouldMakeStringCheck = false
    
    
    private enum Errors: Error {
        case notLoggedIn
        case tokenUnavailable
        case qrCodeGenerationError
        case networkRequestFailed
        case missingParameters
        case invalidResponse
        case apiCalling(Error)
        case jsonParsing(Error)
        case invalidScanType
        case unknownError
        case invalidVersion
        case nullAddress
        case emptyAccessToken
        case FailedToPresentViewController
    }
    
    private enum ScanType: String {
        case AirDrop = "AIR_DROP"
        case RequestLoyaltyPoints = "REQUEST_LOYALTY_POINTS"
    }
    
    /**
     Initializes a new instance of the PassportUtility class.
     - Parameter delegate: The PassportDelegate object used for delegation.
     */
    public init(delegate: PassportDelegate) {
        delegation = delegate
    }
    
    // MARK: - Helper methods
    
    /**
     Scans a QR code using the device's camera and presents the scanner view controller.
     - Parameters:
     - viewController: The view controller from which to present the scanner.
     */
    public func scanQR(_ viewController: UIViewController) {
        let scanner = QRCodeScannerController()
        scanner.delegate = self
        viewController.present(scanner, animated: true, completion: nil)
    }
    
    /**
     Initializes the credentials needed for API calls and smart contract interaction.
     - Parameters:
     - authenticationToken: The authentication token to be used for API calls.
     - nftContractAddress: The address of the NFT smart contract.
     - storedValueContractAddress: The address of the stored value smart contract.
     - connectedContractAddress: The address of the connected smart contract.
     */
    public func initializeCredentials(authenticationToken: String, nftContractAddress: String, storedValueContractAddress: String, connectedContractAddress: String) {
        self.nftContractAddressC = nftContractAddress
        self.storedValueContractAddressC = storedValueContractAddress
        self.connectedContractAddressC = connectedContractAddress
    }
    
    // MARK: - Actions
    
    ///Initiates a new NFC reader/writer session for reading from the passport-enabled tag.
    public func readNFCAddress(completion: @escaping (String) -> Void) {
        readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Scan Your Passport-Enabled Tag")
        readerWriter.begin()
        self.NFCAddressCompletionHandler = completion
    }
    
    ///Initiates a new NFC reader/writer session for reading from the passport-enabled tag and then calling passScanProtocolRouter.
    public func readNFCPass() async {
        let address = await withCheckedContinuation { continuation in
            readNFCAddress { address in
                continuation.resume(returning: address)
            }
        }
        try! await self.passScanProtocolRouter(address)
    }
    
    /**
     Retrieves a version number from a specific smart contract.
     - Returns: An asynchronous task that returns the version number as a String.
     */
    public func getVersion(_ contractAddress: String, _ contractType: String) async throws -> String {
        do {
            let versionNumber = try await checkVersion(contractAddress, contractType)
            debugPrint("Version Number: \(versionNumber)")
            return versionNumber
        } catch Errors.invalidVersion {
            debugPrint("Invalid version encountered")
            throw Errors.invalidVersion
        } catch {
            debugPrint("Error getting version: \(error.localizedDescription)")
            throw error
        }
    }
    
    /**
     Handles sign-in for a given email address                   using Magic.link SDK.
     - Parameters:
     - emailAddress: An email address for which to perform sign-in.
     - Note: Stores the login token in UserDefaults after successful authentication.
     */
    
    public func handleSignIn() {
        oauth2Login(clientID: AppSettings.clientID, clientSecret: AppSettings.clientSecret) { urlRequest in
            guard let request = urlRequest else {
                print("Failed to create URLRequest")
                return
            }
            URLSession.shared.dataTask(with: request) { data, response, error in
            }.resume()
        }
        
        // Your remaining code for handleSignIn
        guard !accessToken.isEmpty else {
            print("address is empty")
            return
        }
        AppSettings.authToken = accessToken
        self.token = accessToken
        self.getAccount()
    }
    
    /**
     Gets the user's Ethereum public address using the Magic.link SDK and passes it to the `delegation` instance.
     - Note: Calls `loginComplete(address:)` of the `delegation` instance to pass the Ethereum public address to it.
     */
    public func getAccount()  {
        guard !accessToken.isEmpty else {
               print("address is empty")
            return
           }
        self.delegation.loginComplete(address: address)
    }
    
    /**
     Checks the balance of NFT (Non-Fungible Token) of a user for a given contract address.
     - Parameters:
     - contractAddress: An Ethereum contract address for which to check NFT balance.
     - userAddress: An Ethereum public address of the user whose NFT balance to check.
     - Returns: The balance of NFT.
     */
    
    public func nftCheck(_ contractAddress: String, _ userAddress: String,_ contractType: String) async -> BigUInt {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            return await withCheckedContinuation { continuation in
                
                contract["balanceOfBatch"]?([add2],[2]).call(){ response, error in
                    if let response = response {
                        guard let res = response[""] as? [BigUInt] else { return }
                        continuation.resume(returning: res.first ?? BigUInt() )
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
    
    /**
     This asynchronous function checks the version of a contract for the given contract address and type.
     It gets the contract ABI (Application Binary Interface) using the 'getContractABI' function,
     constructs a contract instance, calls the 'getVersion' function to get the contract version,
     and then returns the version string or "NONE" if there was an error.
     - Parameters:
     - contractAddress: The contract address for which to check the version.
     - contractType: The type of the contract for which to check the version.
     - Returns: A string containing the contract version or "NONE" if there was an error.
     */
    public func checkVersion(_ contractAddress: String, _ contractType: String) async throws -> String {
        do {
            let contractABI = await getContractABI(contractType)
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            print(contract)
            return try await withCheckedThrowingContinuation { continuation in
                contract["getVersion"]?().call() { response, error in
                    if let response = response {
                        if let version = response["version"] as? String {
                            continuation.resume(returning: version)
                        } else {
                            continuation.resume(throwing: Errors.invalidResponse)
                        }
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: Errors.unknownError)
                    }
                }
            }
        } catch {
            throw error
        }
    }
    /**
     This asynchronous function adds a membership to the given contract address for the given user Ethereum address and metadata.
     It gets the contract ABI (Application Binary Interface) using the 'getContractABI' function,
     constructs a contract instance, and then creates a transaction to call the 'addMembership' function
     with the given user address and metadata. It signs the transaction with the private key and then sends
     the transaction to the network to be mined.
     - Parameters:
     - contractAddress: The contract address to which to add the membership.
     - userAddress: The Ethereum address of the user to add as a member.
     - metadata: The metadata to associate with the membership.
     */
    public func addMembership(_ contractAddress: String, _ userAddress: String, _ metadata: String,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["addMembership"]?(add2, metadata).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    
    /**
     Removes membership of a user from a contract on the Ethereum blockchain.
     - Parameters:
     - contractAddress: The Ethereum address of the contract.
     - userAddress: The Ethereum address of the user whose membership needs to be removed.
     - Returns: Void.
     */
    public func removeMembership(_ contractAddress: String, _ userAddress: String,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert user address to EthereumAddress object
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            
            // Retrieve private key for the transaction from info.plist
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            // Get transaction count for nonce
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    // Create transaction object
                    let transaction = contract["removeMembership"]?(add2).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    // Sign transaction with private key
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
                    // Send transaction
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
    /**
     Checks if a user is a confirmed member of a contract on the Ethereum blockchain.
     - Parameters:
     - contractAddress: The Ethereum address of the contract.
     - ownerAddress: The Ethereum address of the owner of the contract.
     - userAddress: The Ethereum address of the user to be checked.
     - Returns: A boolean value indicating whether the user is a confirmed member of the contract.
     */
    public func checkMembership(_ contractAddress: String, _ ownerAddress: String, _ userAddress: String,_ contractType: String) async -> Bool {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert owner and user addresses to EthereumAddress objects
            guard let add1 = try? EthereumAddress(hex: ownerAddress,eip55: false) else { return Bool() }
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return Bool() }
            
            // Make call to confirmMembership function of the contract
            return await withCheckedContinuation { continuation in
                contract["confirmMembership"]?(add1,add2).call() { response, error in
                    if let response = response {
                        
                        // Return response as a boolean
                        continuation.resume(returning: (response[""] as? Bool) ?? Bool())
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
    
    public func getMembershipMetadata(_ contractAddress: String, _ ownerAddress: String, _ userAddress: String,_ contractType: String) async -> String {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert owner and user addresses to EthereumAddress objects
            guard let add1 = try? EthereumAddress(hex: ownerAddress,eip55: false) else { return "" }
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return "" }
            
            // Make call to confirmMembership function of the contract
            return await withCheckedContinuation { continuation in
                contract["getMembershipMetadata"]?(add1,add2).call() { response, error in
                    if let response = response {
                        // Return response as a boolean
                        continuation.resume(returning: (response[""] as? String) ?? "")
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return ""
    }
    
    /**
     Calculates the loyalty points of a given user for the specified loyalty contract.
     - Parameters:
     - contractAddress: The Ethereum address of the loyalty contract.
     - userAddress: The Ethereum address of the user to check loyalty points for.
     - Returns: A `BigUInt` representing the user's loyalty points.
     */
    public func loyaltyCheck(_ contractAddress: String, _ userAddress: String,_ contractType: String) async -> BigUInt {
        
        // Get the ABI of the loyalty contract
        let contractABI = await getContractABI(contractType);
        
        do {
            // Create a Web3 object using the Magic RPC provider
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            
            // Create a contract object using the contract address and ABI
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert the user address to an EthereumAddress object
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            // Call the `checkPoints` function on the contract using the user address
            return await withCheckedContinuation { continuation in
                contract["checkPoints"]?(add2).call() { response, error in
                    if let response = response {
                        // If the call is successful, return the user's loyalty points
                        continuation.resume(returning: (response[""] as? BigUInt) ?? BigUInt())
                    } else {
                        // If the call fails, print an error message and return 0 loyalty points
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            // If an error occurs, print an error message and return 0 loyalty points
            print(error.localizedDescription)
        }
        return BigUInt()
        
    }
    
    /**
     Adds loyalty points to the user's account.
     - Parameters:
     - contractAddress: The address of the loyalty contract.
     - userAddress: The address of the user's account to add points to.
     - points: The number of points to add to the user's account.
     */
    public func loyaltyAdd(_ contractAddress: String, _ userAddress: String, _ points: UInt,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["addPoints"]?(add2, points).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    
    /**
     Many loyalty programs want to reward users by converting points to stored value. This transaction redeems points and increases stored value balances for recipient.
     - Parameters:
     - contractAddress: The address of the loyalty contract.
     - recipientAddress: The address of the user's account to add points to.
     - points: The number of points to add to the user's account.
     */
    public func convertPointsToCoins(_ contractAddress: String, _ recipientAddress: String, _ points: UInt,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: recipientAddress,eip55: false) else { return }
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["convertPointsToCoins"]?(add2, points).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    /**
     Separated from redemption, this is called if points expire or other activities cause a balance to be reduced by amount without any benefit going to the member recipient.
     - Parameters:
     - contractAddress: The address of the loyalty contract.
     - recipientAddress: The address of the user's account to add points to.
     - points: The number of points to add to the user's account.
     */
    public func loyaltyForfeit(_ contractAddress: String, _ recipientAddress: String, _ points: UInt,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: recipientAddress,eip55: false) else { return }
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["forfeitPoints"]?(add2, points).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    
    /**
     If points are to be converted into stored value or rewards, this can be called to reduce the current points balance for the recipient by pointsAmt, associated with a redemption event eventId.
     - Parameters:
     - contractAddress: The address of the loyalty contract.
     - recipientAddress: The address of the user's account to add points to.
     - points: The number of points to add to the user's account.
     */
    public func loyaltyRedeem(_ contractAddress: String, _ recipientAddress: String, _ points: UInt, _ eventId: UInt,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: recipientAddress,eip55: false) else { return }
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    let transaction = contract["redeemPoints"]?(add2, points).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    
    /**
     Returns the balance of current points owned by recipient, which does NOT take all redemptions and forfeitures into account. This amount can only grow.
     - Parameters:
     - contractAddress: The address of the loyalty contract.
     - recipientAddress: The address of the user's account to add points to.
     - points: The number of points to add to the user's account.
     */
    public func loyaltyLifetimeCheck(_ contractAddress: String, _ userAddress: String,_ contractType: String) async -> BigUInt {
        
        let contractABI = await getContractABI(contractType);
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            return await withCheckedContinuation { continuation in
                contract["checkLifetimePoints"]?(add2).call() { response, error in
                    if let response = response {
                        continuation.resume(returning: (response[""] as? BigUInt) ?? BigUInt())
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
    
    /**
     Checks the balance of a user's account for a given ERC20 token contract.
     - Parameters:
     - contractAddress: The address of the ERC20 token contract.
     - userAddress: The address of the user's account to check the balance of.
     - Returns: The balance of the user's account.
     */
    public func svCheck(_ contractAddress: String, _ userAddress: String,_ contractType: String) async -> BigUInt {
        
        let contractABI = await getContractABI(contractType);
        let contractAddress = storedValueContractAddressC;
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return BigUInt() }
            
            return await withCheckedContinuation { continuation in
                contract["balanceOf"]?(add2).call() { response, error in
                    if let response = response {
                        continuation.resume(returning: response[""] as? BigUInt ?? BigUInt())
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
    
    /**
     Retrieves the connection information for a given serial number from the Connected Packaging smart contract.
     - Parameters:
     - serialNumber: The serial number of the connected packaging.
     - Returns: The Ethereum address of the connected packaging.
     */
    public func connectedPackageQueryID(serialNumber: String,_ contractType: String) async -> String {
        
        // Get the ABI and contract address.
        let contractABI = await getContractABI(contractType);
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            
            // Instantiate the contract.
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Call the "retrieveConnection" function.
            return await withCheckedContinuation { continuation in
                contract["retrieveNFCID"]?(serialNumber).call() { response, error in
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
            // Return an error message if there was an issue.
            print(error.localizedDescription)
        }
        return "ERROR"
    }
    
    /**
     Retrieves the connection information for a given serial number from the Connected Packaging smart contract.
     - Parameters:
     - serialNumber: The serial number of the connected packaging.
     - contractType: The type of smart contract.
     - Returns: The Ethereum address of the connected packaging.
     */
    public func connectedPackageQueryPass(serialNumber: String,_ contractType: String) async -> String {
        
        // Get the ABI and contract address.
        let contractABI = await getContractABI(contractType);
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            
            // Instantiate the contract.
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Call the "retrieveConnection" function.
            return await withCheckedContinuation { continuation in
                contract["retrieveNFCPass"]?(serialNumber).call() { response, error in
                    if let response = response {
                        let eth = response[""] as? String
                        continuation.resume(returning: eth ?? "")
                        //return response;
                    } else {
                        print(error?.localizedDescription ?? "Failed to get response")
                    }
                }
            }
        } catch {
            // Return an error message if there was an issue.
            print(error.localizedDescription)
        }
        return "ERROR"
    }
    
    /**
     Claims a connection for a given user address and serial number in the Connected Packaging smart contract.
     - Parameters:
     - userAddress: The Ethereum address of the user.
     - serialNumber: The serial number of the connected packaging.
     */
    public func connectedPackagePublish(userAddress: String, serialNumber: String,_ contractType: String) async {
        
        // Get the ABI and contract address.
        let contractABI = await getContractABI(contractType);
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert the user address to an Ethereum address.
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            
            // Get the private key.
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            // Get the transaction count and create the transaction.
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{nonce in
                    let transaction = contract["claimConnection"]?(serialNumber,add2).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    
                    // Sign and send the transaction.
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    /**
     Revokes a connection for a given serial number in the Connected Packaging smart contract.
     - Parameters:
     - serialNumber: The serial number of the connected packaging.
     */
    public func connectedPackagePurge(serialNumber: String,_ contractType: String) async {
        
        let contractABI = await getContractABI(contractType);
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3(rpcURL: "\(AppSettings.rpcUrl)/\(AppSettings.chainId)")
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: AppSettings.kryPTKey)
            let chainId = EthereumQuantity(quantity: BigUInt(Int(AppSettings.chainId) ?? 0))
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{nonce in
                    let transaction = contract["revokeConnection"]?(serialNumber).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: chainId) else { return }
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
    
    /**
     Returns the ABI (Application Binary Interface) of a smart contract.
     - Parameters:
     - contractName: The name of the smart contract.
     - Returns: The ABI data of t                  he smart contract.
     */
    func getContractABI(_ contractName: String) async -> Data {
        //TODO: cache the contract ABIs
        guard let thisurl = URL(string: "https://unpkg.com/@credenza-web3/contracts/artifacts/"+contractName+".json")
        else {
            // Return empty data if the URL is invalid.
            return Data(count:2)
        }
        
        let request = URLRequest(url: thisurl)
        do {
            let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
            
            // Check if the response status code is 200 (OK).
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { fatalError("Error while fetching data") }
            
            if let string = String(data: data, encoding: .utf8) {
                var dictonary:NSDictionary?
                
                if let data = string.data(using: String.Encoding.utf8) {
                    do {
                        
                        // Parse the JSON response into a dictionary.
                        dictonary = try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject] as NSDictionary?
                        
                        if let myDictionary = dictonary {
                            
                            // Get the ABI data from the dictionary and convert it to UTF-8 encoded data.
                            guard let data = try? JSONSerialization.data(withJSONObject: myDictionary["abi"] as Any, options: []) else {
                                
                                // Return empty data if the ABI data cannot be retrieved.
                                return Data(count: 0)
                            }
                            guard let Jase = String(data: data, encoding: String.Encoding.utf8) else {
                                
                                // Return empty data if the ABI data cannot be converted to a string.
                                return Data(count: 0)
                            }
                            guard let contractABI = Jase.data(using: .utf8) else {
                                
                                // Return empty data if the ABI data cannot be converted to UTF-8 encoded data.
                                return Data(count: 0)}
                            
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
        
        // Return empty data if an error occurs during the API request.
        return Data(count: 0)
    }
    
    // MARK: - Utilities
    
    /**
     Returns a string containing information about the records in the given array of NFCNDEFMessage objects.
     - Parameter messages: An array of NFCNDEFMessage objects.
     - Returns: A string containing information about the records in the given array of NFCNDEFMessage objects.
     */
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
    
    /**
     Given an NFC tag, this function returns information about it in a dictionary format.
     - Parameter tag: an __NFCTag instance that represents the NFC tag.
     - Returns: a dictionary with information about the tag.
     */
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
    
    /**
     This function is called when the NFC reader becomes active.
     - Parameter session: an instance of NFCReader that represents the session.
     */
    public func readerDidBecomeActive(_ session: NFCReader) {
        print("Reader did become")
    }
    
    /**
     This function is called when the NFC reader fails to read or write to a tag.
     - Parameters:
     - session: an instance of NFCReader that represents the session.
     - error: an Error instance that contains information about the error that occurred.
     */
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
            self.NFCAddressCompletionHandler?(serialID)
            self.NFCAddressCompletionHandler = nil
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
    
    // MARK: - activatePassScan method
    /**
     Activates the passport scan functionality.
     - Parameter viewController: The view controller where the QRCodeScannerController will be presented.
     */
    public func activatePassScan(_ viewController: UIViewController) throws{
        do {
            guard !accessToken.isEmpty else {
                   print("Access token is empty login first")
                   // Handle the case when accessToken is empty, such as throwing an error
                   throw Errors.emptyAccessToken
               }
            let scanner = QRCodeScannerController()
            scanner.delegate = self
            viewController.present(scanner, animated: true, completion: nil)
            self.shouldMakeStringCheck = true
        }catch{
            print("user is not loged in")
        }
    }
    
    // MARK: - PassScanProtocolRouter method
    /**
     Processes the JSON string and performs actions based on the specified scan type.
     - Parameter jsonString: The JSON string to be processed.
     */
    public func passScanProtocolRouter(_ jsonString: String) async throws {
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Invalid JSON string")
            throw Errors.invalidResponse
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            
            guard let scanTypeString = jsonObject?["scanType"] as? String,
                  let scanType = ScanType(rawValue: scanTypeString) else {
                print("Invalid or missing ScanType in JSON")
                throw Errors.invalidScanType
            }
            
            switch scanType {
            case .AirDrop:
                try await handleAirDrop(json: jsonObject)
            case .RequestLoyaltyPoints:
                try await handleRequestLoyaltyPoints(json: jsonObject)
            }
        } catch {
            print("Error parsing JSON: \(error)")
            throw Errors.jsonParsing(error)
        }
        self.shouldMakeStringCheck = false
    }
    
    // MARK: - handleAirDrop method
    /**
     Handles the AirDrop functionality based on the provided JSON parameters.
     - Parameter json: The JSON dictionary containing parameters for the AirDrop.
     */
    private func handleAirDrop(json: [String: Any]?) async throws {
        guard let contractAddress = json?["contractAddress"] as? String,
              let tokenId = json?["tokenId"],
              let amount = json?["amount"] as? Int,
              let chainId = json?["chainId"] as? String else {
            print("Missing required parameters for AIR_DROP")
            throw Errors.missingParameters
        }
        do {
            let targetAddress = await getAddressforlogincode()
            let accesstoken = await authenticateAndGetToken()
            guard let urls = URL(string: "\(AppSettings.passCodeBaseUrl)/chains/\(chainId)/\(contractAddress)/tokens/airDrop") else {
                throw Errors.invalidResponse
            }
            let url = urls
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accesstoken)", forHTTPHeaderField: "Authorization")
            let body: [String: Any] = [
                "targetAddress": targetAddress,
                "tokenId": tokenId,
                "amount": amount
            ]
            
            let requestBody = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = requestBody
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Response: \(response)")
            guard let responseString = String(data: data, encoding: .utf8) else {
                return
            }
            self.delegation.passScanComplete(response: responseString)
        } catch {
            print("Error encoding request body: \(error)")
            throw Errors.apiCalling(error)
        }
    }
    
    // MARK: - handleRequestLoyaltyPoints method
    /**
     Handles the request for loyalty points based on the provided JSON parameters.
     - Parameter json: The JSON dictionary containing parameters for the loyalty points request.
     */
    private func handleRequestLoyaltyPoints(json: [String: Any]?) async throws {
        guard let eventId = json?["eventId"] as? String,
              let chainId = json?["chainId"] as? String,
              let contractAddress = json?["contractAddress"] as? String else {
            print("Missing required parameters for REQUEST_LOYALTY_POINTS")
            throw Errors.missingParameters
        }
        
        do {
            let accesstoken = await authenticateAndGetToken()
            guard let urls = URL(string: "\(AppSettings.passCodeBaseUrl)/chains/\(chainId)/requestLoyaltyPoints?eventId=\(eventId)&contractAddress=\(contractAddress)") else {
                throw Errors.invalidResponse
            }
            let url = urls
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("Bearer \(accesstoken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Response: \(response)")
            guard let responseString = String(data: data, encoding: .utf8) else {
                return
            }
            self.delegation.passScanComplete(response: responseString)
        } catch {
            print("Error checking login status: \(error)")
            throw Errors.apiCalling(error)
        }
    }
    
    
    // MARK: - queryRuleset method
    /**
     Queries the ruleset for a given passport and ruleset ID.
     - Parameter passportId: The ID of the passport.
     - Parameter ruleSetId: The ID of the ruleset.
     - Returns: A Data object containing information about the ruleset.
     */
    public func queryRuleset(passportId: String, ruleSetId: String) async -> Data? {
        // Construct the URL
        guard let url = URL(string: "\(AppSettings.passCodeBaseUrl)/discounts/rulesets/validate") else {
            // Return nil if the URL is invalid.
            return nil
        }
        let accesstoken = await authenticateAndGetToken()
        // Create a URLRequest with the URL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(accesstoken)", forHTTPHeaderField: "Authorization")
        
        // Construct the JSON payload
        let payloadDict: [String: String] = [
            "passportId": passportId,
            "ruleSetId": ruleSetId
        ]
        
        if let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict) {
            // Set the request body
            request.httpBody = payloadData
            
            do {
                // Send the rt and get the response
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Check if the response status code is 200 (OK)
                    print("responseruleset",response)
                    return data
                } else {
                    // Handle the error or non-200 response here
                    // You can log the response or handle it as needed
                    return nil
                }
            } catch {
                // Handle any errors that occurred during the request
                print("Error: \(error)")
                return nil
            }
        } else {
            // Handle JSON serialization error
            return nil
        }
    }
    
    // MARK: - showPassportIDQRCode method
    /**
     Shows the QR code for the passport ID.
     This method checks if the user is logged in and then generates and displays the QR code.
     */
    public func showPassportIDQRCode() async throws -> UIImage {
        return await withCheckedContinuation { continuation in
           
                guard !accessToken.isEmpty else {
                       print("address is empty")
                    print("User is not logged in or an error occurred.")
                    return
                   }
                // User is logged in, proceed with generating the QR code.
                let scanType = "PASSPORT_ID"
                let date = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime])
                let timestamp = String(Int(Date().timeIntervalSince1970))
                DispatchQueue.global(qos: .background).async {
                    let signature = self.signTimestamp(Timestamp: timestamp)
                    print("signaature",signature)
                    let qrCodeData: [String: Any] = [
                        "scanType": scanType,
                        "date": date,
                        "chainId": AppSettings.chainId,
                        "sig": signature
                    ]
                    
                    if let jsonString = self.jsonString(from: qrCodeData), let image = self.generateQRCode(from: jsonString) {
                        // Now you have the QR code image, and you can display it or use it as needed.
                        // Example: imageView.image = qrCodeImage
                        continuation.resume(returning: image)
                        print("Signature:", signature)
                    }
                }
        }
    }
    
    // Function to sign the timestamp using MagicSDK_Web3
    /**
     Signs the timestamp using MagicSDK_Web3.
     - Returns: A string representing the signature.
     */
    private func signTimestamp(Timestamp: String) -> String {
        let contractAddress = self.address
        guard "\(loginCode)\(Timestamp)".data(using: .utf8) != nil else {
            return ""
        }
        
        do {
            let signature = try EthereumAddress(ethereumValue: contractAddress)
            print("sigt:",signature.hex(eip55: false))
            return signature.hex(eip55: false)
        } catch {
            print("Error: \(error)")
            return "Error occurred: \(error)"
        }
    }
    
    // Function to convert a dictionary to a JSON string
    /**
     Converts a dictionary to a JSON string.
     - Parameter data: The dictionary to be converted.
     - Returns: A JSON string.
     */
    private func jsonString(from data: [String: Any]) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("Error while converting to JSON string: \(error)")
        }
        return nil
    }
    
    // MARK: - generateQRCode method
    /**
     Generates a QR code from a JSON string.
     - Parameter jsonString: The JSON string to generate the QR code from.
     - Returns: A UIImage containing the QR code.
     */
    private func generateQRCode(from jsonString: String) -> UIImage? {
        if let data = jsonString.data(using: .utf8) {
            if let filter = CIFilter(name: "CIQRCodeGenerator") {
                filter.setValue(data, forKey: "inputMessage")
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                if let output = filter.outputImage?.transformed(by: transform) {
                    return UIImage(ciImage: output)
                }
            }
        }
        return nil
    }
    
    // MARK: - getWalletPass method
    /**
     Retrieves the wallet pass for the logged-in user.
     This method first checks if the user is logged in, then calls the appropriate API to get the wallet pass.
     */
    public func getWalletPass() async throws -> PKPass? {
        
        guard !accessToken.isEmpty else {
               print("Access token is empty login first")
               // Handle the case when accessToken is empty, such as throwing an error
               throw Errors.emptyAccessToken
           }
        do {
            let address = await getAddressforlogincode()
            let accessToken = await authenticateAndGetToken()
            let apiUrl = "\(AppSettings.passCodeBaseUrl)/apple/pkpass/passportId"
            var urlComponents = URLComponents(string: apiUrl)!
            urlComponents.queryItems = [
                URLQueryItem(name: "chainId", value: AppSettings.chainId),
                URLQueryItem(name: "address", value: address),
                URLQueryItem(name: "sessionToken", value: accessToken)
            ]
            print("urlComponents f:",urlComponents)
            var request = URLRequest(url: urlComponents.url!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Errors.networkRequestFailed
            }
            
            if httpResponse.statusCode == 200 {
                // Initialize PKPass with the pass data
                let pass = try PKPass(data: data)
                return pass
                
            } else {
                print("Unexpected status code: \(httpResponse.statusCode)")
                return nil
            }
            
        }catch {
            print("Error checking login status: \(error)")
            throw error
        }
    }
    
    // MARK: - getAddressforlogincode method
    /**
     Gets the user's Ethereum public address using the Magic.link SDK and passes it to the `delegation` instance.
     - Note: Calls `loginComplete(address:)` of the `delegation` instance to pass the Ethereum public address to it.
     */
    private func getAddressforlogincode() async -> String {
        guard !address.isEmpty else {
               print("address is empty")
            return ""
           }
        return address
    }
    
    // MARK: - getloginCode method
    /**
     Retrieves a login code from the server.
     This method gets the user's Ethereum address, then calls the API to get the login code.
     */
    private func getloginCode(address: String) async {
        // Call the API to get the wallet pass
        let apiUrl = "\(AppSettings.passCodeBaseUrl)/auth"
        var urlComponents = URLComponents(string: apiUrl)!
        urlComponents.queryItems = [
            URLQueryItem(name: "address", value: address)
        ]
        print("urlComponents t:", urlComponents)
        
        // Use URL directly here
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid HTTP response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                // The server responded with a 200 OK status
                do {
                    // Try to parse the data as JSON
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let loginCode = json["loginCode"] as? String {
                        self.loginCode = loginCode
                        // self.showPassportIDQRCode()
                        print("loginc:",loginCode)
                        return
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                    return
                }
            } else {
                print("Unexpected status code: \(httpResponse.statusCode)")
                return
            }
        } catch {
            print("Error downloading wallet pass: \(error)")
            return
        }
        return
    }
    
    private func getLoginCode() async -> String {
        guard !loginCode.isEmpty else {
               print("loginCode is empty")
            return ""
           }
        return loginCode
    }
    
    // MARK: - auth method
    /**
     Performs authentication.
     - Parameter : A closure to be called upon completion of the authentication process.
     */
    private func authenticateAndGetToken() async -> String {
        guard !accessToken.isEmpty else {
               print("accessToken is empty")
            return ""
           }
        return accessToken
    }
    
    // MARK: - oauth2ToAuthorize
    /**
         Performs authentication using OAuth2 authorization.
         - Parameters:
            - clientID: The client ID for OAuth2 authentication.
            - clientSecret: The client secret for OAuth2 authentication.
            - completion: A closure to be called upon completion of the authentication process. It returns a URLRequest for the authentication URL.
    */
    private func oauth2Login(clientID: String, clientSecret: String, completion: @escaping (URLRequest?) -> Void) {
        debugPrint("codeVerifier: \(codeVerifier)")
        let sha256Digest = codeVerifier.hashSha256()
        let codeChallenge = sha256Digest.base64urlencode()
        self.codeChallenge = codeChallenge
        debugPrint("codeChallenge: \(codeChallenge)")
        clientId = clientID
        clientSecretId = clientSecret
        let urlString = "\(AppSettings.accountBaseUrl)/authorize"
        let queryParameters = [
            "client_id": clientID,
            "state": "state",
            "redirect_uri": "https://example.com/callback",
            "scope": "openid profile email phone blockchain.evm blockchain.evm.write",
            "response_type": "code",
            "code_challenge": codeChallenge,
            "code_challenge_method": "S256",
            "nonce": "nonce123"
        ]
        
        // Combine the base URL and query parameters
        var components = URLComponents(string: urlString)!
        var queryItems = [URLQueryItem]()
        for (key, value) in queryParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        
        // Create the URL request from the manually constructed URL
        guard let url = components.url else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        
        // Set the HTTP method and headers
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
      
        // Call presentWebView(withURL:) passing the URL
        Task{
             webViewLogin(withURL: url)
        }
        
        completion(request)
    }

    // MARK: - WebView login
    /**
         Presents a web view with the provided URL.
         - Parameter url: The URL to be loaded in the web view.
         */
    private func webViewLogin(withURL url: URL) {
        // Create a WKWebView instance
        DispatchQueue.main.async {
            let webView = WKWebView(frame: UIScreen.main.bounds)
            webView.navigationDelegate = self
            // Load the provided URL
            let request = URLRequest(url: url)
            webView.load(request)
            // Present the web view controller from the top-most view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               
               let window = windowScene.windows.first,
               let topViewController = window.rootViewController {
                showLoginWebPage(on: topViewController)
            } else if let window = UIApplication.shared.delegate?.window,
                      let topViewController = window?.rootViewController {
                showLoginWebPage(on: topViewController)
            }
            
            func showLoginWebPage(on vc: UIViewController){
                let webViewController = UIViewController()
                webViewController.view = webView
                vc.present(webViewController, animated: true, completion: nil)
            }
        }
    }

    // MARK: - oauth2ToToken
    /**
         Performs authentication.
         - Parameter completion: A closure to be called upon completion of the authentication process.
         */
    private func getToken(from code: String) async {
        let urlString = "\(AppSettings.accountBaseUrl)/token"
        print("codeVerifier: \(codeVerifier)")
        
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL")
            return
        }
                
        let parameters: [String: Any] = [
            "client_id": self.clientId,
            "client_secret": self.clientSecretId,
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": codeVerifier,
            "redirect_uri": "https://example.com/callback"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set the Content-Type header
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Construct the HTTP body from the parameters
        let httpBody = parameters.compactMap { (key, value) -> String? in
            guard let value = value as? String else { return nil }
            return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }.joined(separator: "&")
        
        request.httpBody = httpBody.data(using: .utf8)
        
        // Encode client ID and client secret for Authorization header
        let credentials = "\(clientId):\(clientSecretId)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            print("Error encoding credentials")
            return
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Create URLSession task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Non-HTTPURLResponse received")
                return
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let accessToken = json["access_token"] as? String {
                            print("Access Token: \(accessToken)")
                            // Save access token to a variable or UserDefaults here
                            UserDefaults.standard.set(accessToken, forKey: "accessToken")
                            self.accessToken = accessToken
                            Task{
                                 await self.getloginCode(address: accessToken);
                                   await self.getAccountAddress()
                            }
                        }else{
                            print("Access Token is null")
                        }
                        if let idToken = json["id_token"] as? String {
                            print("ID Token: \(idToken)")
                            // Save id token to a variable or UserDefaults here
                            UserDefaults.standard.set(idToken, forKey: "idToken")
                            self.IdToken = idToken
                        }
                        else{
                            print("ID Token is null")
                        }
                        if let refreshToken = json["refresh_token"] as? String {
                            print("Refresh Token: \(refreshToken)")
                            // Save refresh token to a variable or UserDefaults here
                            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
                            self.refreshToken = refreshToken
                        }else{
                            print("Refresh Token is null")
                        }
                    } else {
                        print("Response data could not be parsed as JSON")
                    }
                } catch {
                    print("Error parsing response data: \(error)")
                }
            } else {
                print("No response data received")
            }
        }
        
        // Resume the task
        task.resume()
    }
    
    //MARK: - getAccountAddress
    /**
     Performs authentication.
     - Parameter completion: A closure to be called upon completion of the authentication process.
     */
    private func getAccountAddress() async {
        let urlString = "\(AppSettings.evmBaseUrl)/address"
        let bearerToken = self.accessToken
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    do {
                        let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        if let address = jsonResponse?["address"] as? String {
                            self.address = address
                            Task {
                                await getSignature(address: address)
                            }
                        }
                    } catch {
                        print("Error parsing JSON: \(error.localizedDescription)")
                    }
                } else {
                    print("Server response error: \(httpResponse.statusCode)")
                    if let responseData = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseData)")
                    }
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    //MARK: - GetSignature
    /**
     Performs authentication.
     - Parameter address: The address to generate signature for.
     - Parameter completion: A closure to be called upon completion of the authentication process.
     */
    private func getSignature(address: String) async {
            
            let bearerToken = self.accessToken
            // Prepare URL
            guard let url = URL(string: "\(AppSettings.evmBaseUrl)/sign") else {
                print("Invalid URL")
                return
            }
            
            // Prepare request object
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            // Prepare request body
            let params: [String: Any] = [
                "method": "personal_sign",
                "params": [
                    "Text",
                    address
                ]
            ]
            guard let httpBody = try? JSONSerialization.data(withJSONObject: params, options: []) else {
                print("Failed to serialize JSON")
                return
            }
            request.httpBody = httpBody
            
            // Create URLSession task
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data, error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Status code: \(httpResponse.statusCode)")
                }
                
                // Parse response JSON
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Response JSON: \(jsonResponse)")
                    if let signature = jsonResponse["signature"] as? String {
                        print("Signature: \(signature)")
                        self.signature = signature
                    }
                } else {
                    print("Failed to parse response JSON")
                }
            }
            task.resume()
        }
}

// MARK: -  QR scanner Delegate
extension PassportUtility: QRScannerCodeDelegate {
    /// It gets call when scanner did complete scanning QRCode.
    public func qrScanner(_ controller: UIViewController, scanDidComplete result: String) {
        print("Scanned QR code: \(result)")
        if shouldMakeStringCheck {
            Task {
                try await passScanProtocolRouter(result)
            }
        } else {
            self.delegation.qrScannerSuccess(result: result)
        }
    }
    /// It gets call when scanner did fail while scanning QRCode.
    public func qrScannerDidFail(_ controller: UIViewController, error: QRCodeError) {
        self.delegation.qrScannerDidFail(error: error)
    }
    /// It gets call when scanner did cancel before scanning QRCode.
    public func qrScannerDidCancel(_ controller: UIViewController) {
        self.delegation.qrScannerDidCancel()
    }
}

extension Data {
    /// Hexadecimal string representation of `Data` object.
    var hexadecimal: String {
        return map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Webview delegate methods

extension PassportUtility: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                print("Clicked URL:", url.absoluteString)
            }
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            print("Final URL:", url.absoluteString)
            
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                for queryItem in queryItems {
                    if queryItem.name == "code", let code = queryItem.value {
                        print("Found code:", code)
                        UserDefaults.standard.set(code, forKey: "savedCode")
                        Task {
                            await getToken(from: code)
                        }
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let topViewController = scene.windows.first?.rootViewController {
                                                topViewController.dismiss(animated: true, completion: nil)
                                            }
                        return
                    }
                }
            }
        }
    }
}
   
