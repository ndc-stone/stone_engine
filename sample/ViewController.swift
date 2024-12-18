/*
ViewController.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

let catcherText = "If you really want to hear about it, the first thing you'll probably want to know is where I was born, an what my lousy childhood was like, and how my parents were occupied and all before they had me, and all that David Copperfield kind of crap, but I don't feel like going into it, if you want to know the truth. In the first place, that stuff bores me, and in the second place, my parents would have about two hemorrhages apiece if I told anything pretty personal about them. They're quite touchy about anything like that, especially my father. They're nice and all--I'm not saying that--but they're also touchy as hell. Besides, I'm not going to tell you my whole goddam autobiography or anything. I'll just tell you about this madman stuff that happened to me around last Christmas just before I got pretty run-down and had to come out here and take it easy. I mean that's all I told D.B. about, and he's my brother and all. He's in Hollywood. That isn't too far from this crumby place, and he comes over and visits me practically every week end. He's going to drive me home when I go home next month maybe. He just got a Jaguar. One of those little English jobs that can do around two hundred miles an hour. It cost him damn near four thousand bucks. He's got a lot of dough, now. He didn't use to. He used to be just a regular writer, when he was home. He wrote this terrific book of short stories, The Secret Goldfish, in case you never heard of him. The best one in it was \"The Secret Goldfish.\" It was about this little kid that wouldn't let anybody look at his goldfish because he'd bought it with his own money. It killed me. Now he's out in Hollywood, D.B., being a prostitute. If there's one thing I hate, it's the movies. Don't even mention them to me."

let rashomonText = "　ある日の暮方の事である。一人の下人が、羅生門の下で雨やみを待っていた。\n　広い門の下には、この男のほかに誰もいない。ただ、所々丹塗の剥げた、大きな円柱に、蟋蟀が一匹とまっている。羅生門が、朱雀大路にある以上は、この男のほかにも、雨やみをする市女笠や揉烏帽子が、もう二三人はありそうなものである。それが、この男のほかには誰もいない。"

let yoshuText = 
    "　洋酒といえば、だれでも最初に思い浮かべるのがウイスキー。いわば洋酒のシンボル的な存在なのだが、英語表記が［一般に〔米〕では Whiskey,〔英〕では Whisky.］であることはあまり知られていない。米英両国では、このスペルの差で自国産と輸入品を区別しているという。わが和製ウイスキーの“Whisky”という英国式表示は、手本にしたスコッチのフォルムに倣ったものであり、それ以上の意味はないようだ。カナ表記にしても、ごくまれに〈ウヰスキー〉という書き方を見かけるが、これとて差別化を意図したものではなく、単にカナづかいの時代性にすぎない。"

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
    
    @IBAction func catcherAction(_ sender: AnyObject) {
        // Set text
        textView.text = catcherText
        
        // Notify it
        textViewDidChange(textView)
    }
    
    @IBAction func rashomonAction(_ sender: AnyObject) {
        // Set text
        textView.text = rashomonText
        
        // Notify it
        textViewDidChange(textView)
    }
    
    @IBAction func yoshuAction(_ sender: AnyObject) {
        // Set text
        textView.text = yoshuText
        
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
