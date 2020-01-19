//
//  ViewController.swift
//  Runner
//
//  Created by Elaine on 19/01/2020.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

import UIKit

class ClockViewController: FlutterViewController {
    var porcupineManager: PorcupineManager!
    
    var hotwordChannel: FlutterMethodChannel!
    var sttChannel: FlutterMethodChannel!
    var configChannel: FlutterMethodChannel!
    
    override func viewDidLoad() {
        hotwordChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/hotword", binaryMessenger: self.binaryMessenger)
        sttChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/stt", binaryMessenger: self.binaryMessenger)
        configChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/config", binaryMessenger: self.binaryMessenger)
        
        sttChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if (call.method == "final") {
                self.process()
            }
        })
        
        self.process()
    }
    
    func process() {
        let modelFilePath = Bundle.main.path(forResource: "porcupine_params", ofType: "pv")
        let keywordFilePath = Bundle.main.path(forResource: "hey pico_ios", ofType: "ppn")

        let keywordCallback: ((WakeWordConfiguration) -> Void) = { word in
            print("hotword detected!")
            self.hotwordChannel.invokeMethod("hotword", arguments: "")
            self.porcupineManager.stopListening()
        }

        let keyword = WakeWordConfiguration(name: "hey pico", filePath: keywordFilePath!, sensitivity: 0.5)
        
        do {
            porcupineManager = try PorcupineManager(modelFilePath: modelFilePath!, wakeKeywordConfiguration: keyword, onDetection: keywordCallback)
            try porcupineManager.startListening()
        } catch {
            let alert = UIAlertController(
                    title: "Alert",
                    message: "Something went wrong",
                    preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
    }
}
