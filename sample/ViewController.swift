/*
ViewController.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit
import stone_engine

let englishText = "Every line of text on a screen is the result of hundreds of small decisions. A layout engine has to measure each character, choose where the line should break, and decide what to do when a word doesn't quite fit. On paper, those decisions were made once and printed forever. On a phone, they're made again whenever someone rotates the device, changes the font size, or opens the same document in a narrow window. That's why a good engine needs to be both careful and fast.\n\nConsider a simple paragraph. It may contain ordinary words, numbers like 1,024 or 3.14, abbreviations such as e.g. and U.S.A., hyphenated terms like well-known, and a phrase in \"double quotes\" or 'single quotes'. Each of them behaves a little differently at the end of a line. Punctuation shouldn't be left alone at the start of the next one, and an opening bracket (like this one) shouldn't be stranded at the end of the previous one.\n\nNone of this is visible when it works. Readers simply keep reading, line after line, without ever thinking about the machinery underneath. That quiet result is the whole point of typesetting, and it's what this sample is here to help you test."

let rashomonText = "　ある日の暮方の事である。一人の下人が、羅生門の下で雨やみを待っていた。\n　広い門の下には、この男のほかに誰もいない。ただ、所々丹塗の剥げた、大きな円柱に、蟋蟀が一匹とまっている。羅生門が、朱雀大路にある以上は、この男のほかにも、雨やみをする市女笠や揉烏帽子が、もう二三人はありそうなものである。それが、この男のほかには誰もいない。"

let mixedText = 
    "　文字組みといえば、多くの人が最初に思い浮かべるのは本や雑誌の紙面だろう。しかし画面の上の文章にも、同じように組版の工夫がある。英語でいう［一般に〔活字を組む作業は〕Typesetting,〔文字の設計や扱い全般は〕Typography.］という言葉は、日本語の文章を扱うアプリでもそのまま重要な意味を持つ。たとえば iPhone や iPad の画面では、1行の長さは機種や向きによって変わり、40字だった行が次の瞬間には25字になることもある。そのたびに「行頭に句読点を置かない」「閉じ括弧を行頭に送らない」といった禁則処理をやり直さなければならない。和文と欧文が混ざると、さらに難しくなる。Stone Engine 1.0 のような英数字を含む語は途中で折り返さないほうが読みやすいし、縦書きでは 12 や 2024 といった数字を縦中横にするか、横に寝かせるかも判断しなければならない。（括弧の中の文章）や『書名』、そして約物が連続する箇所――こうした細部の積み重ねが、読みやすさを左右する。読者に意識されないことこそ、よい組版の証しなのである。"

class RootController: UITableViewController {
    override func viewDidLoad() {
        title = "stone engine"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "default")
        
        cell.textLabel?.text = indexPath.row == 0 ? "STLabel" : "STTextView"
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            performSegue(withIdentifier: "label", sender: self)
        }
        else if indexPath.row == 1 {
            performSegue(withIdentifier: "textView", sender: self)
        }
    }
}

class LabelController: UIViewController {
    @IBOutlet weak var label: STLabel!
    @IBOutlet weak var inspectorScrollView: UIScrollView!
    @IBOutlet weak var inspectorContainerView: UIView!
    
    override func viewDidLoad() {
        // Configure itself
        title = "STLabel"
        
        // Configure label
        label.text = rashomonText
    }
    
    override func viewWillLayoutSubviews() {
        //let inspctorController = children.compactMap({ $0 as? InspectorController }).first
    }
    
    override func viewDidLayoutSubviews() {
        //let inspctorController = children.compactMap({ $0 as? InspectorController }).first
    }
}

class TextViewController: UIViewController {
    var observers = [NSObjectProtocol]()
    @IBOutlet weak var textView: STTextView!
    
    override func viewDidLoad() {
        // Configure itself
        title = "STTextView"
        
        // Configure label
        textView.text = rashomonText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIWindow.keyboardWillChangeFrameNotification, object: nil, queue: .main, using: { (notification) in
            // Update appearance
            self.updateScrollViewInsetForKeyboard(scrollView: self.textView, initialInset: .init(top: 20, left: 20, bottom: 20, right: 20), notification: notification)
        }))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let _ = textView.becomeFirstResponder()
    }
    
    func updateScrollViewInsetForKeyboard(scrollView: UIScrollView, initialInset: UIEdgeInsets, notification: Notification) {
        // Get focused view
        guard let focusedView = scrollView.focusedView else { return }
        
        // Get keyboard end frame
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        // For keyboard will be hidden or empty or floating
        guard let windowFrame = view.window?.frame else { return }
        if endFrame.minY >= windowFrame.height || endFrame.isEmpty || windowFrame.width != endFrame.width {
            // Clear inset
            scrollView.contentInset = initialInset
            scrollView.scrollIndicatorInsets = .zero
        }
        // For keyboard will be shown
        else {
            // Check focused view frame with keyboard frame
            let focusedViewFrame = focusedView.convert(focusedView.bounds, to: nil)
            guard focusedViewFrame.maxY > endFrame.minY else { return }
            
            // Decide content inset bottom
            let bottom = view.frame.height - view.convert(.init(x: 0, y: endFrame.minY), from: nil).y
            var inset = initialInset
            inset.bottom += bottom
            scrollView.contentInset = inset
            scrollView.scrollIndicatorInsets = .init(top: 0, left: 0, bottom: bottom, right: 0)
        }
    }
}

class InspectorController: UIViewController {
    var labelController: LabelController? { parent as? LabelController }
    var textVewController: TextViewController? { parent as? TextViewController }
    var label: STLabel? { labelController?.label }
    var textView: STTextView? { textVewController?.textView }
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var fontSizeSlider: UISlider!
    @IBOutlet weak var lineHeightScaleSlider: UISlider!
    @IBOutlet weak var textAlignSegmentedControl: UISegmentedControl!
    @IBOutlet weak var directionSegmentedControl: UISegmentedControl!
    @IBOutlet weak var latinFontButton: UIButton!
    @IBOutlet weak var japaneseFontButton: UIButton!
    @IBOutlet weak var latinFontScaleSlider: UISlider!
    @IBOutlet weak var japaneseFontScaleSlider: UISlider!
    @IBOutlet weak var punctuationSegmentedControl: UISegmentedControl!
    @IBOutlet weak var allowTateChuYokoSwitch: UISwitch!
    @IBOutlet weak var processKinsokuSwitch: UISwitch!
    @IBOutlet weak var divideByWordsSwitch: UISwitch!
    
    override func viewDidLoad() {
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Update appearance
        updateAppearance()
    }
    
    func updateAppearance() {
        // Update appearance
        if let label = label {
            fontSizeSlider.value = Float(label.fontSize)
            textAlignSegmentedControl.selectedSegmentIndex = label.textAlign.rawValue
            
            var container = AttributeContainer()
            container.font = UIFont.systemFont(ofSize: 13)
            latinFontButton.configuration?.attributedTitle = .init(label.fontNames(script: .latin).first ?? "", attributes: container)
            japaneseFontButton.configuration?.attributedTitle = .init(label.fontNames(script: .japanese).first ?? "", attributes: container)
            latinFontScaleSlider.value = Float(label.fontScale(script: .latin))
            japaneseFontScaleSlider.value = Float(label.fontScale(script: .japanese))
            
            allowTateChuYokoSwitch.isOn = label.isAllowedTateChuYoko
            processKinsokuSwitch.isOn = label.isKinsokuAvailable
            divideByWordsSwitch.isOn = label.isDividedByWords
        }
        else if let textView = textView {
            fontSizeSlider.value = Float(textView.fontSize)
            textAlignSegmentedControl.selectedSegmentIndex = textView.textAlign.rawValue
            textView.contentInset = .init(top: 20, left: 20, bottom: 20, right: 20)
                    
            var container = AttributeContainer()
            container.font = UIFont.systemFont(ofSize: 13)
            latinFontButton.configuration?.attributedTitle = .init(textView.fontNames(script: .latin).first ?? "", attributes: container)
            japaneseFontButton.configuration?.attributedTitle = .init(textView.fontNames(script: .japanese).first ?? "", attributes: container)
            
            allowTateChuYokoSwitch.isOn = textView.isAllowedTateChuYoko
            processKinsokuSwitch.isOn = textView.isKinsokuAvailable
            divideByWordsSwitch.isOn = textView.isDividedByWords
        }
    }
    
    @IBAction func editTextAction(_ sender: AnyObject) {
        // Create controller
        guard let editTextController = storyboard?.instantiateViewController(identifier: "editText") as? EditTextController else { return }
        editTextController.label = label
        editTextController.stTextView = textView
        
        // Present controller
        present(editTextController, animated: true)
    }
    
    @IBAction func fontSizeAction(_ sender: AnyObject) {
        guard let slider = sender as? UISlider else { return }
        label?.fontSize = CGFloat(slider.value)
        textView?.fontSize = CGFloat(slider.value)
    }
    
    @IBAction func lineHeightScaleAction(_ sender: AnyObject) {
        guard let slider = sender as? UISlider else { return }
        label?.lineHeightScale = CGFloat(slider.value)
        textView?.lineHeightScale = CGFloat(slider.value)
    }
    
    @IBAction func textAlignAction(_ sender: AnyObject) {
        guard let segmentedControl = sender as? UISegmentedControl else { return }
        if segmentedControl.selectedSegmentIndex == 0 {
            label?.textAlign = .leading
            textView?.textAlign = .leading
        }
        else if segmentedControl.selectedSegmentIndex == 1 {
            label?.textAlign = .center
            textView?.textAlign = .center
        }
        else if segmentedControl.selectedSegmentIndex == 2 {
            label?.textAlign = .trailng
            textView?.textAlign = .trailng
        }
        else if segmentedControl.selectedSegmentIndex == 3 {
            label?.textAlign = .justify
            textView?.textAlign = .justify
        }
    }
    
    @IBAction func directionAction(_ sender: AnyObject) {
        guard let segmentedControl = sender as? UISegmentedControl else { return }
        label?.direction = segmentedControl.selectedSegmentIndex == 0 ? .lrTb : .tbRl
        textView?.direction = segmentedControl.selectedSegmentIndex == 0 ? .lrTb : .tbRl
    }
    
    @IBAction func latinFontAction(_ sender: AnyObject) {
        // Create controller
        let fontController = FontController()
        fontController.script = .latin
        fontController.label = labelController?.label
        fontController.textView = textVewController?.textView
        fontController.inspectorController = self
        fontController.modalPresentationStyle = .popover
        if let popoverPresentation = fontController.popoverPresentationController {
            popoverPresentation.sourceView = latinFontButton
            popoverPresentation.sourceRect = latinFontButton.bounds
        }
        
        // Present controller
        present(fontController, animated: true)
    }
    
    @IBAction func japaneseFontAction(_ sender: AnyObject) {
        // Create controller
        let fontController = FontController()
        fontController.script = .japanese
        fontController.label = labelController?.label
        fontController.textView = textVewController?.textView
        fontController.inspectorController = self
        fontController.modalPresentationStyle = .popover
        if let popoverPresentation = fontController.popoverPresentationController {
            popoverPresentation.sourceView = japaneseFontButton
            popoverPresentation.sourceRect = japaneseFontButton.bounds
        }
        
        // Present controller
        present(fontController, animated: true)
    }
    
    @IBAction func latinFontScaleAction(_ sender: AnyObject) {
        label?.setFontScale(CGFloat(latinFontScaleSlider.value), script: .latin)
        textView?.setFontScale(CGFloat(latinFontScaleSlider.value), script: .latin)
    }
    
    @IBAction func japaneseFontScaleAction(_ sender: AnyObject) {
        label?.setFontScale(CGFloat(japaneseFontScaleSlider.value), script: .japanese)
        textView?.setFontScale(CGFloat(japaneseFontScaleSlider.value), script: .japanese)
    }
    
    @IBAction func punctuationAction(_ sender: AnyObject) {
        guard let segmentedControl = sender as? UISegmentedControl else { return }
        guard let punctuationMode = STPunctuationMode(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        label?.punctuationMode = punctuationMode
    }
    
    @IBAction func tateChuYokoAction(_ sender: AnyObject) {
        guard let sw = sender as? UISwitch else { return }
        label?.isAllowedTateChuYoko = sw.isOn
        textView?.isAllowedTateChuYoko = sw.isOn
    }
    
    @IBAction func processKinsokuAction(_ sender: AnyObject) {
        guard let sw = sender as? UISwitch else { return }
        label?.isKinsokuAvailable = sw.isOn
        textView?.isKinsokuAvailable = sw.isOn
    }
    
    @IBAction func divideByWordsAction(_ sender: AnyObject) {
        guard let sw = sender as? UISwitch else { return }
        label?.isDividedByWords = sw.isOn
        textView?.isKinsokuAvailable = sw.isOn
    }
}

class EditTextController: UIViewController, UITextViewDelegate {
    weak var label: STLabel?
    weak var stTextView: STTextView?
    
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        // Set text
        if let label = label {
            textView.text = label.text
        }
        else if let stTextView = stTextView {
            textView.text = stTextView.text
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Make text view first responder
        textView.becomeFirstResponder()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // Set text
        label?.text = textView.text
        stTextView?.text = textView.text
    }
    
    @IBAction func englishAction(_ sender: AnyObject) {
        // Set text
        textView.text = englishText
        
        // Notify it
        textViewDidChange(textView)
    }
    
    @IBAction func rashomonAction(_ sender: AnyObject) {
        // Set text
        textView.text = rashomonText
        
        // Notify it
        textViewDidChange(textView)
    }
    
    @IBAction func mixedAction(_ sender: AnyObject) {
        // Set text
        textView.text = mixedText
        
        // Notify it
        textViewDidChange(textView)
    }
    
    @IBAction func deleteAction(_ sender: AnyObject) {
        // Remove text
        textView.text = ""
        
        // Notify it
        textViewDidChange(textView)
    }
}

class FontController: UITableViewController {
    weak var label: STLabel?
    weak var textView: STTextView?
    weak var inspectorController: InspectorController?
    
    var script: STScript = .japanese
    var familyNames: [String] {
        switch script {
        case .latin: return ["en"]
        case .japanese: return ["ja"]
        default: return []
        }
    }
    
    var fontNames = [String]()
    
    override func viewDidLoad() {
        // Get family names
        let familyNames = UIFont.availableFamilyNames(familyNames) ?? []
        
        // Collect font names
        var fontNames = [String]()
        for familyName in familyNames {
            fontNames.append(contentsOf: UIFont.fontNames(forFamilyName: familyName))
        }
        self.fontNames = fontNames
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontNames.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "fontCell")
        cell.textLabel?.text = fontNames[indexPath.row]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        label?.setFontNames([fontNames[indexPath.row]], script: script)
        textView?.setFontNames([fontNames[indexPath.row]], script: script)
        inspectorController?.updateAppearance()
    }
}

extension UIView {
    private func focusedView(in view: UIView) -> UIView? {
        // Check view
        if view.isFirstResponder { return view }
        
        // Find in subviews
        for subview in view.subviews {
            if let view = focusedView(in: subview) { return view }
        }
        
        return nil
    }
    
    var focusedView: UIView? {
        // Find first responder view
        return focusedView(in: self)
    }
}
