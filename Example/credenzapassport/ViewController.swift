//
//  ViewController.swift
//  credenzapassport
//
//  Created by sandyUPGRADED on 10/25/2022.
//  Copyright (c) 2022 sandyUPGRADED. All rights reserved.
//

import UIKit
import credenzapassport
import WebKit
import NFCReaderWriter
import PassKit

/*import NFCReaderWriter
 import MagicSDK
 import MagicSDK_Web3*/
import Foundation

class ViewController: UIViewController, PassportDelegate {
    
//    @IBOutlet weak var tagID: UILabel!
    @IBOutlet weak var webView: WKWebView!
//    @IBOutlet weak var viewForEmbeddingWebView: UIView!
    @IBOutlet weak var emailID: UITextField!
//    @IBOutlet weak var qrCodeImageView: UIImageView!
    
    var pUtility: PassportUtility?
    
    //MARK: - UIView life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        pUtility = PassportUtility(delegate: self)
    }
    
    //MARK: - Action methods
    @IBAction func scanQRCode(_ sender: UIButton) {
        debugPrint("Opening scanner...")
        pUtility?.scanQR(self)
    }
    
    @IBAction func login(_ sender: Any) {
        Task { @MainActor in
            pUtility!.handleSignIn(emailID.text!)
        }
        
    }
    
    @IBAction func readTagIDButtonTapped(_ sender: Any)  {
        /*readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Nearby NFC card for read tag identifier")
         readerWriter.begin()
         readerWriter.detectedMessage = "detected Tag info"*/
        Task {
            let b = await pUtility!
                .loyaltyCheck("CONTRACT_ADDRESS","USER_ADDRESS");
            print(b)
            
            let c = await pUtility!
                .checkMembership("CONTRACT_ADDRESS","OWNER_ADDRESS", "USER_ADDRESS")
            print(c)
            
            let d = await pUtility!
                .checkVersion("CONTRACT_ADDRESS","CONTRACT_TYPE");
            print(d)

            let e = await pUtility!
                .svCheck("CONTRACT_ADDRESS","USER_ADDRESS");
            print(e)
            
            let f = await pUtility!
                .nftCheck("CONTRACT_ADDRESS","USER_ADDRESS");
            print(f)
            
            //await pUtility!.loyaltyAdd("CONTRACT_ADDRESS", "USER_ADDRESS", POINTS)
            
            //await pUtility!.removeMembership("CONTRACT_ADDRESS", "USER_ADDRESS")
            
            await pUtility!.addMembership("CONTRACT_ADDRESS", "USER_ADDRESS","META_DATA");
        }
    }
    
    func loginComplete(address: String) {
        print(address)
        print("check",address)
    }
    
    func nfcScanComplete(address: String) {
        print(address)
    }
    
    func qrScannerSuccess(result: String) {
        print("scanner :",result)
    }
    
    func qrScannerDidFail(error: Error) {
        print(error.localizedDescription)
    }
    
    func qrScannerDidCancel() {
        print("QRCodeScanner did cancel")
    }
    
    func passScanComplete(response: String) {
        print("passScanComplete: \(response)")
    }
    
}

//MARK: - Example methods
extension ViewController {
    
    func getwalletPass(){
        // calling of GetWalletPass
        Task {
            do {
                guard let pass = try await pUtility?.getWalletPass() else {
                    return
                }
                let library = PKPassLibrary()
                if library.containsPass(pass) {
                    
                } else {
                    // If the pass is not in the library, present PKAddPassesViewController
                    let addPassViewController = PKAddPassesViewController(pass: pass)
                    self.present(addPassViewController, animated: true)
                }
            } catch let error {
                debugPrint(error)
            }
        }
    }
    
    func activePassScan(){
        // calling of activatePassScan
        try? pUtility!.activatePassScan(self, completionHandler: {
            data in print("activepassscan:",data)
        })
    }
    
    func queryRuleset(){
        // calling of queryRuleset
        Task{
            await pUtility?.queryRuleset(passportId: "PASSPORT_ID", ruleSetId: "RULESET_ID")
        }
    }
    
    func showPassportIDQRCode(){
        // calling of showPassportIDQRCode
        Task {
            let image = try! await pUtility!.showPassportIDQRCode()
            debugPrint(image)
        }
    }
    
}
