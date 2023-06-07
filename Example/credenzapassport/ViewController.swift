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

/*import NFCReaderWriter
import MagicSDK
import MagicSDK_Web3*/
import Foundation

class ViewController: UIViewController, PassportDelegate {
  
    var pUtility: PassportUtility?

    override func viewDidLoad() {
        super.viewDidLoad()
        pUtility = PassportUtility(delegate: self)
        // Do any additional setup after loading the view.
        //handleSignIn()
        //authN()
    }
    
    @IBOutlet weak var tagID: UILabel!
    @IBOutlet weak var webView: WKWebView!

    @IBOutlet weak var viewForEmbeddingWebView: UIView!
    
    @IBOutlet weak var emailID: UITextField!

    @IBAction func scanQRCode(_ sender: UIButton) {
        debugPrint("Opening scanner...")
        pUtility?.scanQR(self)
    }
    
    @IBAction func login(_ sender: Any) {
        //print(emailID.text)
        //print("bobo")
        pUtility!.handleSignIn(emailID.text!)
    }

    @IBAction func readTagIDButtonTapped(_ sender: Any)  {
        /*readerWriter.newWriterSession(with: self, isLegacy: false, invalidateAfterFirstRead: true, alertMessage: "Nearby NFC card for read tag identifier")
        readerWriter.begin()
        readerWriter.detectedMessage = "detected Tag info"*/
        Task {
            let b = await pUtility!
                .loyaltyCheck("0x61ff3d77ab2befece7b1c8e0764ac973ad85a9ef","0x375fa2f7fec390872a04f9c147c943eb8e48c43d");
            print(b)
            
            let c = await pUtility!
                .checkMembership("0x3366F71c99A4684282BfE8af800194abeEF5F4C3","0xc3736D688d2F83cBADFf0675b9A604A2Ae60D151", "0x375fa2f7fec390872a04f9c147c943eb8e48c43d")
            print(c)
            
            let d = await pUtility!
                .checkVersion("0x61ff3d77ab2befece7b1c8e0764ac973ad85a9ef","LoyaltyContract");
            print(d)
            
            
            let e = await pUtility!
                .svCheck("0x893fBedDaDfdfb836CC069902F7270eA56fD6ebF","0x2d3e53bea19d756624dbfa3a9cd9b616878cf698");
            print(e)
            
            
            let f = await pUtility!
                .nftCheck("0x4d20968f609bf10e06495529590623d5d858c5c7","0x2d3e53bea19d756624dbfa3a9cd9b616878cf698");
            print(f)
            
            //await pUtility!.loyaltyAdd("0x61ff3d77ab2befece7b1c8e0764ac973ad85a9ef", "0x375fa2f7fec390872a04f9c147c943eb8e48c43d", 11)
            
            //await pUtility!.removeMembership("0x3366F71c99A4684282BfE8af800194abeEF5F4C3", "0x375fa2f7fec390872a04f9c147c943eb8e48c43d")
            
            await pUtility!.addMembership("0x3366F71c99A4684282BfE8af800194abeEF5F4C3", "0x375fa2f7fec390872a04f9c147c943eb8e48c43d","app metameta")
            
            
        }
    }
    
    func loginComplete(address: String) {
        print(address)
    }
    
    func nfcScanComplete(address: String) {
        print(address)

    }
    
    func qrScannerSuccess(result: String) {
        print(result)
    }
    
    func qrScannerDidFail(error: Error) {
        print(error.localizedDescription)
    }
    
    func qrScannerDidCancel() {
        print("QRCodeScanner did cancel")
    }

  
}

