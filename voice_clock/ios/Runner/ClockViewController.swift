//
//  ViewController.swift
//  Runner
//
//  Created by Elaine on 19/01/2020.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

import UIKit
import Intents
import IntentsUI
import CoreSpotlight
import MobileCoreServices

public let kConfigDarkActivityType = "dev.elainedb.dark"

class ClockViewController: FlutterViewController {
    var porcupineManager: PorcupineManager!
    
    var hotwordChannel: FlutterMethodChannel!
    var sttChannel: FlutterMethodChannel!
    var configChannel: FlutterMethodChannel!
    var configSetChannel: FlutterMethodChannel!
    var addShortcutChannel: FlutterMethodChannel!
    
    override func viewDidLoad() {
        hotwordChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/hotword", binaryMessenger: self.binaryMessenger)
        sttChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/stt", binaryMessenger: self.binaryMessenger)
        configChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/config", binaryMessenger: self.binaryMessenger)
        configSetChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/configSet", binaryMessenger: self.binaryMessenger)
        addShortcutChannel = FlutterMethodChannel(name: "dev.elainedb.voice_clock/addShortcut", binaryMessenger: self.binaryMessenger)
        
        sttChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if (call.method == "final") {
                self.process()
            }
        })
        
        configSetChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if (call.method == "dark") {
                self.darkWasSet()
            }
        })
        
        addShortcutChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if (call.method == "dark") {
                self.addDarkShortcut()
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
    
    func darkShortcut(thumbnail: UIImage?) -> NSUserActivity {
        let activity = NSUserActivity(activityType: kConfigDarkActivityType)
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier(kConfigDarkActivityType)
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        activity.title = "Set theme to dark"
        attributes.contentDescription = "Set theme to dark"
        attributes.thumbnailData = thumbnail?.jpegData(compressionQuality: 1.0)
        activity.suggestedInvocationPhrase = "Set theme to dark"

        activity.contentAttributeSet = attributes
        
        return activity
    }
    
    func darkWasSet() {
      // Create and donate an activity-based Shortcut
      let activity = darkShortcut(thumbnail: UIImage(named: "square"))
      self.userActivity = activity
      activity.becomeCurrent()
    }
    
    func addDarkShortcut() {
        // Open View Controller to Create New Shortcut
        let activity = darkShortcut(thumbnail: UIImage(named: "square"))
        let shortcut = INShortcut(userActivity: activity)
        
        let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        vc.delegate = self
        
        present(vc, animated: true, completion: nil)
      }

}

extension ClockViewController: INUIAddVoiceShortcutViewControllerDelegate {
  func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                      didFinishWith voiceShortcut: INVoiceShortcut?,
                                      error: Error?) {
    dismiss(animated: true, completion: nil)
  }
  
  func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
    dismiss(animated: true, completion: nil)
  }
}
