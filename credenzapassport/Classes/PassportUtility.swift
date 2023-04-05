//
//  PassportUtility.swift
//  credenzapassport
//
//  Created by Sandy Khaund on 10/31/22.
//

import NFCReaderWriter
import MagicSDK
import MagicSDK_Web3
import Foundation

public protocol PassportDelegate {
    // Define expected delegate functions
    func loginComplete(address: String)
    func nfcScanComplete(address: String)
}

/**
The PassportUtility class is used to handle NFC tag reading and writing for a passport-enabled tag.
It includes various methods for initializing credentials, reading NFC tags, interacting with smart contracts, and performing authentication.
*/
open class PassportUtility: NSObject, NFCReaderDelegate {
    
    // MARK: Local Variables
    /// The authentication token to be used for API calls.
    fileprivate var authenticationTokenC = ""
    /// The address of the NFT smart contract.
    fileprivate var nftContractAddressC = ""
    /// The address of the stored value smart contract.
    fileprivate var storedValueContractAddressC = ""
    /// The address of the connected smart contract.
    fileprivate var connectedContractAddressC = ""
    
    /// An instance of the NFCReaderWriter class.
    public let readerWriter = NFCReaderWriter.sharedInstance()
    /// An instance of the Magic class.
    let magic = Magic.shared
    /// The PassportDelegate object used for delegation.
    fileprivate var delegation: PassportDelegate
    
    /**
     Initializes a new instance of the PassportUtility class.
     - Parameter delegate: The PassportDelegate object used for delegation.
     */
    public init(delegate: PassportDelegate) {
        delegation = delegate
    }
    
    // MARK: - Helper methods
    
    /// Initializes the credentials needed for API calls and smart contract interaction.
    /// - Parameters:
    ///   - authenticationToken: The authentication token to be used for API calls.
    ///   - nftContractAddress: The address of the NFT smart contract.
    ///   - storedValueContractAddress: The address of the stored value smart contract.
    ///   - connectedContractAddress: The address of the connected smart contract.
    public func initializeCredentials(authenticationToken: String, nftContractAddress: String, storedValueContractAddress: String, connectedContractAddress: String) {
        self.authenticationTokenC = "https://deep-index.moralis.io/api/v2/\(authenticationToken)/logs?chain=rinkeby" // moralisURL
        self.nftContractAddressC = nftContractAddress
        self.storedValueContractAddressC = storedValueContractAddress
        self.connectedContractAddressC = connectedContractAddress
    }
    
    // MARK: - Actions
    
    ///Initiates a new NFC reader/writer session for reading from the passport-enabled tag.
    public func readNFC() {
        readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Scan Your Passport-Enabled Tag")
        readerWriter.begin()
    }
    
    /**
     Retrieves a version number from a specific smart contract.
     - Returns: An asynchronous task that returns the version number as a String.
     */
    public func getVersion() async {
        let versionNumber = await checkVersion("0x61ff3d77ab2befece7b1c8e0764ac973ad85a9ef", "LoyaltyContract")
        print (versionNumber)
    }
    
    ///Performs a GET request using the provided authentication token.
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
    
    /**
     Handles sign-in for a given email address using Magic.link SDK.
     - Parameters:
        - emailAddress: An email address for which to perform sign-in.
     - Note: Stores the login token in UserDefaults after successful authentication.
     */
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
    
    /**
     Gets the user's Ethereum public address using the Magic.link SDK and passes it to the `delegation` instance.
     - Note: Calls `loginComplete(address:)` of the `delegation` instance to pass the Ethereum public address to it.
    */
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
    
    /**
     Checks the balance of NFT (Non-Fungible Token) of a user for a given contract address.
     - Parameters:
        - contractAddress: An Ethereum contract address for which to check NFT balance.
        - userAddress: An Ethereum public address of the user whose NFT balance to check.
     - Returns: The balance of NFT.
    */
    public func nftCheck(_ contractAddress: String, _ userAddress: String) async -> BigUInt {
        
        let contractABI = await getContractABI("OzzieContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
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
     This function checks the ownership of an NFT (Non-Fungible Token) for the given Ethereum address. It constructs a contract instance, calls the 'balanceOfBatch' function to get the NFT balance, and then prints the response message or error message accordingly.
     - Parameter address: The Ethereum address for which to check the NFT ownership.
     */
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
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: nftContractAddressC))
            
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
    
    /**
     Removes membership of a user from a contract on the Ethereum blockchain.
     - Parameters:
        - contractAddress: The Ethereum address of the contract.
        - userAddress: The Ethereum address of the user whose membership needs to be removed.
     - Returns: Void.
     */
    public func removeMembership(_ contractAddress: String, _ userAddress: String) async {
        
        let contractABI = await getContractABI("MetadataMembershipContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert user address to EthereumAddress object
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            
            // Retrieve private key for the transaction from info.plist
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            // Get transaction count for nonce
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{ nonce in
                    // Create transaction object
                    let transaction = contract["removeMembership"]?(add2).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    // Sign transaction with private key
                    guard let signedTx = try transaction?.sign(with: myPrivateKey,chainId: 80001) else { return }
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
    public func checkMembership(_ contractAddress: String, _ ownerAddress: String, _ userAddress: String) async -> Bool {
        
        let contractABI = await getContractABI("MetadataMembershipContract");
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
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
    
    /**
    Calculates the loyalty points of a given user for the specified loyalty contract.
    - Parameters:
        - contractAddress: The Ethereum address of the loyalty contract.
        - userAddress: The Ethereum address of the user to check loyalty points for.
    - Returns: A `BigUInt` representing the user's loyalty points.
    */
    public func loyaltyCheck(_ contractAddress: String, _ userAddress: String) async -> BigUInt {
        // Get the ABI of the loyalty contract
        let contractABI = await getContractABI("LoyaltyContract");
        
        do {
            // Create a Web3 object using the Magic RPC provider
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            
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
    
    /**
    Checks the balance of a user's account for a given ERC20 token contract.
    - Parameters:
        - contractAddress: The address of the ERC20 token contract.
        - userAddress: The address of the user's account to check the balance of.
    - Returns: The balance of the user's account.
    */
    public func svCheck(_ contractAddress: String, _ userAddress: String) async -> BigUInt {
        
        let contractABI = await getContractABI("ERC20TestContract");
        let contractAddress = storedValueContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
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
    public func connectedPackageQuery(serialNumber: String) async -> String {
        
        // Get the ABI and contract address.
        let contractABI = await getContractABI("ConnectedPackagingContract");
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            
            // Instantiate the contract.
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Call the "retrieveConnection" function.
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
    public func connectedPackagePublish(userAddress: String, serialNumber: String) async {
        
        // Get the ABI and contract address.
        let contractABI = await getContractABI("ConnectedPackagingContract");
        let contractAddress = connectedContractAddressC;
        
        do {
            let web3 = Web3.init(provider: Magic.shared.rpcProvider)
            let contract = try web3.eth.Contract(json: contractABI, abiKey: nil, address: EthereumAddress(ethereumValue: contractAddress))
            
            // Convert the user address to an Ethereum address.
            guard let add2 = try? EthereumAddress(hex: userAddress,eip55: false) else { return }
            
            // Get the private key.
            let key = (Bundle.main.infoDictionary?["KRYPTKEY"] as? String) ?? ""
            let myPrivateKey = try EthereumPrivateKey(hexPrivateKey: key)
            
            // Get the transaction count and create the transaction.
            web3.eth.getTransactionCount(address: myPrivateKey.address, block: .latest)
                .done{nonce in
                    let transaction = contract["claimConnection"]?(serialNumber,add2).createTransaction(nonce: nonce, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei))
                    
                    // Sign and send the transaction.
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
    
    /**
    Revokes a connection for a given serial number in the Connected Packaging smart contract.
    - Parameters:
        - serialNumber: The serial number of the connected packaging.
    */
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
    /// Returns the ABI (Application Binary Interface) of a smart contract.
    ///
    /// - Parameter contractName: The name of the smart contract.
    /// - Returns: The ABI data of the smart contract.
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
    
    /// Returns a string containing information about the records in the given array of NFCNDEFMessage objects.
    ///
    /// - Parameter messages: An array of NFCNDEFMessage objects.
    /// - Returns: A string containing information about the records in the given array of NFCNDEFMessage objects.
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
    
    /// Given an NFC tag, this function returns information about it in a dictionary format.
    /// - Parameter tag: an __NFCTag instance that represents the NFC tag.
    /// - Returns: a dictionary with information about the tag.
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
    
    /// This function is called when the NFC reader becomes active.
    /// - Parameter session: an instance of NFCReader that represents the session.
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




