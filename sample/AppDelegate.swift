/*
AppDelegate.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import CoreText
import UIKit

let additionalFonts: [String] = [
    "YuMin-Medium", "YuMin-Demibold", "YuMin-Extrabold", "YuGo-Medium", "YuGo-Bold",
]

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Match fonts
        matchFont(withNames: additionalFonts) { result in
        }
        
        return true
    }
}

func matchFont(withNames names: [String], completion: ((Bool) -> Void)?) {
    // Create font descriptors
    var fontDescriptors: [CTFontDescriptor] = []
    for name in names {
        let fontDescriptor = CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute as NSAttributedString.Key: name] as CFDictionary)
        fontDescriptors.append(fontDescriptor)
    }
    
    // Match font descriptors
    CTFontDescriptorMatchFontDescriptorsWithProgressHandler(fontDescriptors as CFArray, nil) { state, progressParameter in
        // Switch by state
        switch state {
        case .didFinish:
            // Dispatch to main
            DispatchQueue.main.async {
                // Invoke handler
                completion?(true)
            }
        case .didFailWithError:
            // Dispatch to main
            DispatchQueue.main.async {
                // Invoke handler
                completion?(false)
            }
        default:
            break
        }
        
        return true
    }
}
