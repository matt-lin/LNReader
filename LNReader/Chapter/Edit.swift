//
//  Edit.swift
//  LNReader
//
//  Created by Matt Lin on 12/3/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit

class Edit: UIView {
    init(chapter: ChapterViewController) {
        _chapter = chapter
        super.init(frame: chapter.view.frame)
        self.backgroundColor = UIColor.clear
        self.isHidden = true
        
        let defaultHeight = frame.height * Edit.DEFAULT_HEIGHT
        
        let hideFrame = CGRect(x: 0, y: 0, width: frame.width, height: defaultHeight)
        let hideView = HideView(frame: hideFrame)
        hideView.backgroundColor = UIColor.clear
        self.addSubview(hideView)

        let backgroundFrame = CGRect(x: 0, y: defaultHeight, width: frame.width, height: frame.height - defaultHeight)
        let background = UIView(frame: backgroundFrame)
        background.backgroundColor = UIColor.lightGray
        self.addSubview(background)
        
        let sliderText = UILabel(frame: CGRect(x: frame.width / 20, y: 15 + defaultHeight, width: 100, height: 20))
        sliderText.text = "Text size"
        self.addSubview(sliderText)
        
        let slider = UISlider(frame: CGRect(x: frame.width / 20, y: 35 + defaultHeight, width: frame.width * 9 / 10, height: 50))
        slider.maximumValue = 30
        slider.minimumValue = 10
        slider.isContinuous = false
        slider.setValue(Float(_chapter._fontSize), animated: false)
        slider.addTarget(chapter, action: #selector(chapter.setFont(sender:)), for: .valueChanged)
        self.addSubview(slider)
        
        
        let button = UIButton(frame: CGRect(x: frame.width / 10 + 100, y: 100 + defaultHeight, width: 200, height: 50))
        button.setTitle("Go to chapter", for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0), for: .highlighted)
        button.addTarget(self, action: #selector(changeChapter), for: .touchUpInside)
        self.addSubview(button)
        
        _textbox = UITextField(frame: CGRect(x: frame.width / 20, y: 100 + defaultHeight, width: 100, height: 50))
        _textbox!.placeholder = "Chapter"
        _textbox!.textColor = UIColor.black
        _textbox!.keyboardType = .numberPad
        self.addSubview(_textbox!)
    }

    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    @objc func changeChapter() {
        if let num = Int(_textbox!.text!) {
            _chapter.load(anotherChapter: num)
            self.isHidden = true
        }
        _textbox!.text = nil
        _textbox!.resignFirstResponder()
    }
    
    var _chapter: ChapterViewController
    var _textbox: UITextField?
    static var DEFAULT_HEIGHT = CGFloat(1.0/3)
}

private class HideView: UIView {
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.superview!.isHidden = true
        (self.superview as! Edit)._textbox!.resignFirstResponder()
    }
}
