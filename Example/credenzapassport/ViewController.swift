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
import Foundation

class ViewController: UIViewController, PassportDelegate {
        
    var pUtility: PassportUtility?
    @IBOutlet weak var buttons: UIStackView!
    //MARK: - UIView life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        pUtility = PassportUtility(delegate: self)
    }
    

    
    //MARK: - Action methods
    @IBAction func scanQRCode(_ sender: UIButton) {
        debugPrint("Opening scanner...")
        DispatchQueue.main.async { [weak self] in
            self?.buttons.isHidden = true
        }
        
        pUtility?.scanQR(self)
    }
    
    @IBAction func login(_ sender: Any) {
        Task { @MainActor in
            pUtility!.handleSignIn()
        }
    }
    
    @IBAction func readTagIDButtonTapped(_ sender: Any)  {
        /*readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Nearby NFC card for read tag identifier")
         readerWriter.begin()
         readerWriter.detectedMessage = "detected Tag info"*/
        Task {
            let b = await pUtility!
                .loyaltyCheck("INSERT_CONTRACT_ADDRESS","INSERT_USER_ADDRESS","INSERT_CONTRACT_TYPE");
            print("b:",b)
            
            let c = await pUtility!
                .checkMembership("INSERT_CONTRACT_ADDRESS","INSERT_OWNER_ADDRESS", "INSERT_USER_ADDRESS","INSERT_CONTRACT_TYPE")
            print("c:",c)
            
            let d = try await pUtility!
                .checkVersion("INSERT_CONTRACT_ADDRESS","INSERT_CONTRACT_TYPE");
            print("d:",d)
            
            let e = await pUtility!
                .svCheck("INSERT_CONTRACT_ADDRESS","INSERT_USER_ADDRESS","INSERT_CONTRACT_TYPE");
            print("e:",e)
            
            let f = await pUtility!
                .nftCheck("INSERT_CONTRACT_ADDRESS","INSERT_USER_ADDRESS","INSERT_CONTRACT_TYPE");
            print("f:",f)
            
            //await pUtility!.loyaltyAdd("INSERT_CONTRACT_ADDRESS", "INSERT_USER_ADDRESS", INSERT_POINTS,"INSERT_CONTRACT_TYPE")
            
            //await pUtility!.removeMembership("INSERT_CONTRACT_ADDRESS", "INSERT_USER_ADDRESS","INSERT_CONTRACT_TYPE")
            
            await pUtility!.addMembership("INSERT_CONTRACT_ADDRESS", "INSERT_USER_ADDRESS","INSERT_META_DATA","INSERT_CONTRACT_TYPE");

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
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { [weak self] in
            self?.buttons.isHidden = false
        }
        
    }
    
    func qrScannerDidFail(error: Error) {
        print(error.localizedDescription)
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { [weak self] in
            self?.buttons.isHidden = false
        }
    }
    
    func qrScannerDidCancel() {
        print("QRCodeScanner did cancel")
        DispatchQueue.main.async { [weak self] in
            self?.buttons.isHidden = false
        }
    }
    
    func passScanComplete(response: String) {
        print("passScanComplete: \(response)")
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { [weak self] in
            self?.buttons.isHidden = false
        }
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
        DispatchQueue.main.async { [weak self] in
            self?.buttons.isHidden = true
        }
        try? pUtility?.activatePassScan(self)
    }
    
    func queryRuleset(){
        // calling of queryRuleset
        Task{
            await pUtility?.queryRuleset(passportId: "INSERT_PASSPORT_ID", ruleSetId: "INSERT_RULESET_ID")
        }
    }
    
    func showPassportIDQRCode(){
        // calling of showPassportIDQRCode
        Task {
            let image = try! await pUtility!.showPassportIDQRCode()
            debugPrint(image)
        }
    }
    
    func readNFCPass() {
        Task{
           try! await pUtility?.readNFCPass()
        }
    }
    
}
