/*
STTiledLayer.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

class STTiledLayer: CATiledLayer {
    // Context
    var context: STContext!
    
    //--------------------------------------------------------------//
    // MARK: - Tiled layer
    //--------------------------------------------------------------//
    
    override class func fadeDuration() -> CFTimeInterval { 0 }
    
    override var tileSize: CGSize {
        get { .init(width: 1024, height: 1024) }
        set {}
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    private func extractContentSize(string: String) -> CGSize? {
        // Expected contents description: <CAImageProvider 0x104bcee40: 1828 x 136>
        
        // Parse content description
        guard let range0 = string.range(of: ": ") else { return nil }
        guard let range1 = string.range(of: " x ") else { return nil }
        guard let range2 = string.range(of: ">") else { return nil }
        let widthStr = string[range0.upperBound ..< range1.lowerBound]
        let heightStr = string[range1.upperBound ..< range2.lowerBound]
        
        // Create size
        guard let width = Int(widthStr), let height = Int(heightStr) else { return nil }
        return .init(width: CGFloat(width) / contentsScale, height: CGFloat(height) / contentsScale)
    }
    
    var contentSize: CGSize? {
        // Extract content description
        guard let contentDescription = (contents as? NSObject)?.description else { return nil }
        return extractContentSize(string: contentDescription)
    }
}
