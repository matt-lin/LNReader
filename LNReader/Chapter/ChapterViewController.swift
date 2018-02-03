//
//  ChapterViewController.swift
//  LNReader
//
//  Created by Matt Lin on 11/30/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit

class ChapterViewController: UIViewController {
    init?(initials: String) {
        _initials = initials
        
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

        let file = dir.appendingPathComponent(_initials + ".json")

        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe),
            let jsonResult = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
            let result = jsonResult as? [String: String],
            let info = DataManager.getChapterInfo(initials: _initials) else { return nil }

        _bookData = result
        
        _chapterInd = info.chapterInd
        _fontSize = info.size
        _chapters = info.chapters
        _chapterMapping = info.numbers
        _offset = info.offset
        
        
        super.init(nibName: nil, bundle: nil)
        self.view.backgroundColor = UIColor.white
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
     override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .done, target: self, action: #selector(edit))
        let prevButton = UIBarButtonItem(title: "Prev", style: .done, target: self, action: #selector(prevChapter(sender:)))
        
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        
        _progressView = UIProgressView()
        _progressView.frame.size = CGSize(width: 150, height: 20)
        
        let progress = _progress
        _progressView.setProgress(progress, animated: false)
        let progressBar = UIBarButtonItem(customView: _progressView)
        
        let space2 = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        space2.width = 10
        
        _labelView = UILabel()
        _labelView.adjustsFontSizeToFitWidth = true
        _labelView.text = String(format: "%.2f%%", progress * 100)
        let label = UIBarButtonItem(customView: _labelView)
        
        let space3 = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)

        let nextButton = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(nextChapter(sender:)))
        self.toolbarItems = [prevButton, space, progressBar, space2, label, space3, nextButton]
        
        let statusHeight = UIApplication.shared.statusBarFrame.height
        let y: CGFloat = (self.navigationController?.navigationBar.frame.height ?? 30) + statusHeight
        let heightDiff: CGFloat = y + (self.navigationController?.toolbar.frame.height ?? 30)
        ChapterViewController.SHOWN_FRAME = CGRect(x: 0, y: y, width: self.view.frame.width, height: self.view.frame.height - heightDiff)
        ChapterViewController.HIDDEN_FRAME = CGRect(x: 0, y: statusHeight, width: self.view.frame.width, height: self.view.frame.height - statusHeight)
        
        self.view.addSubview(chapterTextView())
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        _editView = Edit(chapter: self)
        _transparentView = TransparentView(controller: self)

        self.view.addSubview(_editView!)
        self.view.addSubview(_transparentView!)
        
        _chapter?.setContentOffset(CGPoint(x: 0, y: _offset), animated: false)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        for subview in self.view.subviews {
            subview.removeFromSuperview()
        }
        _editView = nil
        _transparentView = nil
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        _editView = nil
        _transparentView = nil
        _chapter = nil
        _bookData = [:]
        _chapters = []
    }
    
    
    @objc func edit() {
        _editView!.isHidden = false
        self.toggleNavigationBar()
        self.view.bringSubview(toFront: _editView!)
    }
    
    // Mark - Chapter
    
    /**
     Initializes a ChapterText view at chapter and returns it.
     
     - parameter chapter: Chapter number.
     
     - returns:
     The ChapterText view to be displayed.
     */
    private func chapterTextView() -> UITextView {
        let chapterTitle = _chapters[_chapterInd]
        let chapterData = _bookData[String(_chapterNum)]
        _chapter = ChapterText(frame: ChapterViewController.SHOWN_FRAME, fontSize: _fontSize, title: chapterTitle, data: chapterData, delegate: self)
        return _chapter!
    }
    
    /**
     Parse title and load book data into memory.  If book has not changed, display the previous book
     instead of loading data.
     
     - parameters:
     - book: The initials of the book.
     - transparentView: The transparent view to be used to cover the chapter.
     */
    func load(initials: String) -> ChapterViewController? {
        _initials = initials
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let file = dir.appendingPathComponent(_initials + ".json")
        if let data = try? Data(contentsOf: file, options: .mappedIfSafe),
            let jsonResult = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
            let result = jsonResult as? [String: String]
        {
            _bookData = result
            if self.load() {
                return self
            }
        }
        return nil
    }
    
    /**
     Initial load of chapter.  Gets the user's current chapter if exists, else gets the starting chapter
     of the book.
     */
    private func load() -> Bool {
        guard let info = DataManager.getChapterInfo(initials: _initials) else { return false }
        
        _chapterInd = info.chapterInd
        _fontSize = info.size
        _chapters = info.chapters
        _chapterMapping = info.numbers
        _offset = info.offset
        self.view.addSubview(chapterTextView())
        return true
    }
    
    /**
     Load another chapter.
     
     - Important:
     Assumes a new chapter index has already been set. Assumes a previous chapter has already been loaded before.
     */
    func loadAnotherChapter() {
        let chapterTitle = _chapters[_chapterInd]
        let chapterData = _bookData[String(_chapterNum)]
        let nextChapter = ChapterText(title: chapterTitle, data: chapterData, other: _chapter!)
        
        _chapter!.removeFromSuperview()
        _chapter = nextChapter
        _offset = 0
        _hasChanged = true
        
        self.view.addSubview(nextChapter)
        
        let progress = _progress
        _labelView.text = String(format: "%.2f%%", progress * 100)
        _progressView.setProgress(progress, animated: false)
    }
    
    func load(anotherChapter: Int) {
        _chapterNum = anotherChapter
        self.loadAnotherChapter()
    }
    
    /**
     Loads the next chapter.
     
     - parameter shouldCover: Should transparent view cover the chapter view?
     */
    @objc func nextChapter(sender: UIBarButtonItem?) {
        guard _chapterInd + 1 < _chapterMapping.count else { return }
        _chapterInd += 1
        self.loadAnotherChapter()
        if sender != nil {
            self.view.bringSubview(toFront: _transparentView!)
        }
    }
    
    
    /**
     Loads the previous chapter.
     
     - parameter shouldCover: Should transparent view cover the chapter view?
     */
    @objc func prevChapter(sender: UIBarButtonItem?) {
        guard _chapterInd != 0 else { return }
        _chapterInd -= 1
        self.loadAnotherChapter()
        if sender != nil {
            self.view.bringSubview(toFront: _transparentView!)
        }
    }
    
    
    func setOffset(offset: Int) {
        if _offset != offset && offset >= 0 {
            _offset = offset
            _hasChanged = true
        }
    }
    
    /**
     Toggles visibility of the navigation bar, toolbar and the transprent view.  Brings transprent view to
     the front.
     */
    func toggleNavigationBar() {
        self.view.bringSubview(toFront: _transparentView!)
        let hide = !_transparentView!.isHidden
        UIView.animate(withDuration: 0.2) {
            if hide {
                self._chapter?.frame = ChapterViewController.HIDDEN_FRAME
            } else {
                self._chapter?.frame = ChapterViewController.SHOWN_FRAME
            }
        }
        
        _transparentView!.isHidden = hide
        self.navigationController!.toggleNavigationBar(hide: hide)
    }
    
    /**
     Sets the font size of the chapter text. Responds to the text size slider.
     
     - parameter sender: Text size slider.
     */
    @objc func setFont(sender: UISlider) {
        let newSize = Int(sender.value)
        if newSize != _fontSize && newSize > 0 && newSize < 30 {
            _fontSize = newSize
            _chapter?.setFontSize(size: newSize)
            _hasChanged = true
        }
    }
    
    
    /**
     Saves current chapter number and font size if there are changes.
     */
    func save() {
        if _chapter != nil && _hasChanged {
            DataManager.saveChapter(chapter: _chapterNum, size: _fontSize, offset: _offset, initials: _initials)
            _hasChanged = false
        }
    }
    
    
    /**
     Converts given string to initials.  Words can be separated by spaces or '-'.
     
     - parameter title: String to be converted
     
     - returns:
     Initials of title.
     */
    static func convertTitle(title: String) -> String {
        var initials = ""
        for word in title.split(whereSeparator: {
            (char: Character) -> Bool in return char == " " || char == "-"
        }) {
            initials.append(word[word.startIndex])
        }
        return initials.uppercased()
    }
    
    
    static func binarySearch(arr: [Int], val: Int) -> Int {
        var range = 0..<arr.count
        
        while range.startIndex < range.endIndex {
            let midIndex = range.startIndex + (range.endIndex - range.startIndex) / 2
            
            if arr[midIndex] == val {
                return midIndex
            } else if arr[midIndex] < val {
                range = midIndex + 1 ..< range.endIndex
            } else {
                range = range.startIndex ..< midIndex
            }
        }
        return range.startIndex == 0 ? 0 : range.startIndex - 1
    }
    
    
    private var _bookData: [String: String]
    
    /** Current index in chapter mapping. */
    private var _chapterInd: Int
    
    /** Mapping of _chapters index to chapter number. */
    private var _chapterMapping: [Int]
    
    /** Current chapter number. */
    private var _chapterNum: Int {
        get {
            return _chapterMapping[_chapterInd]
        }
        
        set {
            _chapterInd = ChapterViewController.binarySearch(arr: _chapterMapping, val: newValue)
        }
    }
    
    /** Current content offset in chapter text view. */
    private var _offset: Int
    
    /** Current chapter text view. */
    private var _chapter: ChapterText?
    
    /** Initials of current book.*/
    var _initials: String
    
    /** List of chapters in current book */
    private var _chapters: [String]
    
    /** Font size with default value 20 */
    var _fontSize: Int = 20
    
    /** Bool to record if changes have occurred.*/
    var _hasChanged = false
    
    private var _progressView: UIProgressView!
    
    private var _progress: Float {
        get {
            return Float(_chapterInd) / Float(_chapterMapping.count - 1)
        }
    }
    
    private var _labelView: UILabel!
    
    var _editView: Edit?, _transparentView: TransparentView?
    
    static var SHOWN_FRAME: CGRect!
    static var HIDDEN_FRAME: CGRect!
}
