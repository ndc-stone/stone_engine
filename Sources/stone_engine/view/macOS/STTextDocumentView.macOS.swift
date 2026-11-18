/*
STTextDocumentView.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

open class STTextDocumentView: NSView {
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    open override var isFlipped: Bool {
        true
    }
}
#endif
