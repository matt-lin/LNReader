//
//  ChapterText.swift
//  LNReader
//
//  Created by Matt Lin on 1/18/18.
//  Copyright © 2018 Matt Lin. All rights reserved.
//

import UIKit

class ChapterText: UITextView, UITextViewDelegate {
    init(frame: CGRect, fontSize: Int, title: String, data: String?, delegate: ChapterViewController) {
        _fontSize = fontSize
        _data = data
        _title = title
        _controller = delegate
        
        super.init(frame: frame, textContainer: nil)
        
        self.isEditable = false
        self.isSelectable = false
        self.renderText()
        self.delegate = self
        self.contentInset = UIEdgeInsets.zero
    }
    
    
    convenience init (title: String, data: String?, other: ChapterText) {
        self.init(frame: other.frame, fontSize: other._fontSize, title: title, data: data, delegate: other._controller)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _controller.toggleNavigationBar()
        _controller.setOffset(offset: Int(self.contentOffset.y))
    }
    
    
    /**
     Parse text and set it to be dispalyed.
     */
    func renderText() {
        if _data != nil {
            let title = _title + "\n\n"
            let chapter = _data!
            let fontSize = CGFloat(_fontSize)
            let comb = NSMutableAttributedString(string: title + chapter)
            comb.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "Arial-BoldMT", size: fontSize * 3 / 2) as Any, range: NSMakeRange(0, title.count))
            comb.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "ArialMT", size: fontSize) as Any, range: NSMakeRange(title.count, chapter.count))
            _titleCount = title.count
            _chapterCount = chapter.count
            self.attributedText = comb
            let frame = self.frame
            self.sizeToFit()
            self.frame = frame
        } else {
            self.text = "Missing Chapter"
        }
    }
    
    
    /**
     Change font size of the text.
     
     - parameter size: Font size to be set.
     */
    func setFontSize(size: Int) {
        guard _data != nil else {
            return
        }
        
        if _titleCount == nil {
            _titleCount = (_title + "\n\n").count
        }
        if _chapterCount == nil {
            _chapterCount = _data!.count
        }
        
        let attrString = NSMutableAttributedString(attributedString: self.attributedText)
        let fontSize = CGFloat(size)
        let titleAttr: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: UIFont(name: "Arial-BoldMT", size: fontSize * 3 / 2) as Any]
        let chapterAttr: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: UIFont(name: "ArialMT", size: fontSize) as Any]
        attrString.setAttributes(titleAttr, range: NSMakeRange(0, _titleCount!))
        attrString.setAttributes(chapterAttr, range: NSMakeRange(_titleCount!, _chapterCount!))
        self.attributedText = attrString
        _fontSize = size
    }
    
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if contentOffset.y - 75 > scrollView.contentSize.height - scrollView.frame.height {
            _controller.nextChapter(sender: nil)
        } else if contentOffset.y < -100 {
            _controller.prevChapter(sender: nil)
        } else {
            _controller.setOffset(offset: Int(targetContentOffset.pointee.y))
        }
    }
    
    /** Chapter data. */
    private var _data: String?
    private var _title: String
    private var _controller: ChapterViewController
    
    private var _fontSize: Int
    private var _titleCount, _chapterCount: Int?
}
