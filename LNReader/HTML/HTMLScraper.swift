//
//  HTMLScraper.swift
//  LNReader
//
//  Created by Matt Lin on 12/2/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit
import Alamofire

extension String {
    public func strip() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func stripAndReplace() -> String {
        let stripped = self.strip().replacingOccurrences(of: "\n", with: "")
        return stripped
    }
    
    public func index(afterChar: Character) -> String.Index? {
        if let ind = self.index(of: afterChar) {
            return self.index(after: ind)
        }
        return nil
    }
}

enum ScraperType: String {
    static let vals = [ScraperType.Machine, ScraperType.WW, ScraperType.GravityTales, ScraperType.General]
    
    case Machine = "Machine"
    case WW = "WuxiaWorld"
    case GravityTales = "Gravity Tales"
    case General = "General"
}

class HTMLScraper {
    /**
     Set information for scraper.
     
     - parameters:
         - title: Book title.
         - type: Type of website to be fetched.
         - query: Website query paramater. Title replacing spaces with '-' if nil.
         - initials: Initials to be saved as.  Title initials if nil.
     */
    init(title: String, type: ScraperType, query: String?, hasBook: Bool, initials: String?, link: String?) {
        _title = title.strip()
        _type = type
        _query = query ?? title.replacingOccurrences(of: " ", with: "-")
        _hasBook = hasBook
        _initials = initials ?? ChapterViewController.convertTitle(title: title)
        _link = link
        ScraperOperation._data = [:]
        ScraperOperation._count = 0
    }
    
    
    /**
     Fetch chapters.
     
     - Important:
     Must call set before calling fetch.
     
     - parameters:
         - from: Staring chapter (inclusive).
         - to: Ending chapter (inclusive).
     */
    func fetch(from start: Int, to end: Int) {
        Alamofire.request("https://www.google.com").response { response in
            if let err = response.error, err._code == -1009 {
                self.alert(title: "No internet connection", message: nil)
                HTMLScraper._start?.isEnabled = true
                HTMLScraper._cancel?.isEnabled = false
                return
            }
            if self._type == .Machine && !HTMLScraper._loggedIn {
                self.machineLogin(from: start, to: end)
            } else {
                self.get(from: start, to: end)
            }
        }
    }
    
    
    /**
     Create Scraper Operations and add them to the operation queue to be fetch asynchronously.
     Saves fetched data after finished.
     
     - parameters:
         - from: Staring chapter (inclusive).
         - to: Ending chapter (inclusive).
     */
    private func get(from start: Int, to end: Int) {
        var query: String
        var localGet: (_: String, _: Int) -> (title: String, chapter: String)?
        
        operationQueue.maxConcurrentOperationCount = 10
        
        switch _type {
        case .WW:
            query = String(format: HTMLScraper.WW_FORMAT, _query, _query, "%d")
            localGet = HTMLScraper.getww
        case .GravityTales:
            let tit = _title.replacingOccurrences(of: " ", with: "-")
            query = String(format: HTMLScraper.GT_FORMAT, tit, _query, "%d")
            localGet = HTMLScraper.getgt
        case .Machine:
            if _hasBook {
                query = String(format: HTMLScraper.MACHINE_BOOK_FORMAT, _query, "%d", "%d")
            } else {
                query = String(format: HTMLScraper.MACHINE_FORMAT, _query, "%d")
            }
            localGet = HTMLScraper.getMachine
        case .General:
            query = _link
            localGet = HTMLScraper.getGen
            operationQueue.maxConcurrentOperationCount = 1
        }
        
        let title = _type == .Machine ? _title + " - Machine" : _title
        let initials = _type == .Machine ? _initials + "M" : _initials
        
        DataManager.saveTitle(name: title, initials: initials)
        
        HTMLScraper._progressLabel?.text = "Fetching chapters"
        let group = DispatchGroup()
        
        ScraperOperation._progressBar = HTMLScraper._progressBar
        ScraperOperation._increment = 1 / Float(end - start + 1)
        ScraperOperation._group = group
        ScraperOperation._get = localGet
        ScraperOperation._query = query
        ScraperOperation._hasBook = _hasBook
        ScraperOperation._book = 1
        ScraperOperation._isGeneral = _link != nil
        ScraperOperation._bookName = title
        ScraperOperation._hasSet = true
        
        for chapter in start...end {
            group.enter()
            operationQueue.addOperation(ScraperOperation(chapter: chapter))
        }
        
        group.notify(queue: .main) {
            let count = ScraperOperation._count
            if count > 0 {
                self.alert(count: count)
                self.save()
            } else {
                self.alert(title: "Failed to fetch chapters for \(self._title)", message: nil)
            }
            HTMLScraper.reset()
        }
    }
    
    
    func alert(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
        HTMLScraper.delegate?.present(alert, animated: false, completion: nil)
    }
    
    
    func alert(count: Int) {
        alert(title: "Finished getting chapters for \(_title)", message: "Got \(count) chapter\(count < 2 ? "" : "s")")
    }
    
    
    static func getMachine(_ inhtml: String, _: Int) -> (title: String, chapter: String)? {
        let stripped = inhtml.stripAndReplace()
        if stripped.range(of: HTMLScraper.MACHINE_404, options: .regularExpression) != nil { return nil }
        
        guard let titleStart = stripped.range(of: "<span class=\"chapter-title\"[^<]+</span>", options: .regularExpression),
        let titleRange = stripped[titleStart].range(of: "(?<=>)[^<>]+(?=</)", options: .regularExpression) else { return nil }
        var title = String(stripped[titleRange])
        if title.isEmpty { return nil }
        let ind = title.index(afterChar: "#") ?? title.index(after: title.startIndex)
        title = "Chapter " + title[ind...]
        title = title.replacingOccurrences(of: ":", with: " -")
        title = HTMLScraper.decode(html: title)
        
        guard let textStart = stripped.range(of: "<div class=\"chapter-body ") else { return nil }
        let html = stripped[textStart.upperBound...]
        
        guard let textRange = html.range(of: "(?<=>).*?(?=</div>)", options: .regularExpression) else {
            return nil
        }
        let text = String(html[textRange])

        let sentenceMatches = HTMLScraper.MACHINE_SENTENCE_PATTERN.matches(in: text, range: NSMakeRange(0, text.count))
        
        let sentences = sentenceMatches.map {
            String(text[Range($0.range, in: text)!])
        }
        
        var chapter = ""
        for sentence in sentences {
            var cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: sentence, options: [], range: NSMakeRange(0, sentence.count), withTemplate: "")
            for _ in 0..<10 where cleared.range(of: HTMLScraper.WORD_PATTERN.pattern, options: .regularExpression) != nil {
                cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: cleared, options: [], range: NSMakeRange(0, cleared.count), withTemplate: "")
            }
            
            chapter += decode(html: cleared) + "\n\n"
        }
        
        if chapter.isEmpty { return nil }

        return (title, chapter)
    }
    
    
    static func getww(_ inhtml: String, _: Int) -> (title: String, chapter: String)? {
        let stripped = inhtml.stripAndReplace()
        if stripped.range(of: HTMLScraper.WW_404, options: .regularExpression) != nil {
            return nil
        }
        guard let divStart = stripped.range(of: "<div itemprop=\"articleBody\">") else {
            return nil
        }
        
        let html = stripped[divStart.upperBound...]
        
        guard let textRange = html.range(of: "(>Next Chapter( ?</strong>)? ?</a>).*?>(Previous|Next) Chapter ?</a>", options: .regularExpression) else {
            return nil
        }

        let text = String(html[textRange])
        let paragraphMatches = HTMLScraper.WW_PARAGRAPH_PATTERN.matches(in: text, range: NSMakeRange(0, text.count))
        
        let paragraphs = paragraphMatches.map {
            String(text[Range($0.range, in: text)!])
        }
        
        var title = "", chapter = ""
        var isTitle = true
        if paragraphs.isEmpty {
            return nil
        }
        
        for paragraph in paragraphs {
            var cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: paragraph, options: [], range: NSMakeRange(0, paragraph.count), withTemplate: "")
            for _ in 0..<10 {
                if cleared.range(of: HTMLScraper.WORD_PATTERN.pattern, options: .regularExpression) == nil {
                    break
                }
                cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: cleared, options: [], range: NSMakeRange(0, cleared.count), withTemplate: "")
            }
            if isTitle && cleared.range(of: "chapter", options: .caseInsensitive) != nil && !cleared.contains("collapseomatic") {
                title = cleared.replacingOccurrences(of: ":", with: "-").strip()
                title = HTMLScraper.decode(html: title)
                isTitle = false
                continue
            } else if isTitle {
                continue
            }
            cleared = HTMLScraper.decode(html: cleared).strip()
            if cleared.isEmpty {
                continue
            }
            chapter += cleared + "\n\n"
        }
        
        if title.isEmpty || chapter.isEmpty { return nil }
        
        return (title, chapter)
    }
    
    
    static func getgt(_ inhtml: String, _: Int) -> (title: String, chapter: String)? {
        let stripped = inhtml.stripAndReplace()
        guard let divStart = stripped.range(of: "(?<=<div id=\"chapterContent\").*?(?=</div>)", options: .regularExpression) else {
            return nil
        }
        
        let html = String(stripped[divStart])
        var paragraphMatches = HTMLScraper.GT_PARAGRAPH_PATTERN.matches(in: html, range: NSMakeRange(0, html.count))
        if paragraphMatches.isEmpty {
            paragraphMatches = HTMLScraper.GT_PARAGRAPH_BACKUP_PATTERN.matches(in: html, range: NSMakeRange(0, html.count))
        }
        
        let paragraphs = paragraphMatches.map {
            String(html[Range($0.range, in: html)!])
        }
        
        var title = "", chapter = ""
        var isTitle = true
        if paragraphs.isEmpty {
            return nil
        }
        
        for paragraph in paragraphs {
            var cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: paragraph, options: [], range: NSMakeRange(0, paragraph.count), withTemplate: "")
            for _ in 0..<10 {
                if cleared.range(of: HTMLScraper.WORD_PATTERN.pattern, options: .regularExpression) == nil {
                    break
                }
                cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: cleared, options: [], range: NSMakeRange(0, cleared.count), withTemplate: "")
            }
            if isTitle && cleared.range(of: "chapter", options: .caseInsensitive) != nil {
                title = cleared.replacingOccurrences(of: ":", with: " -")
                title = HTMLScraper.decode(html: title).strip()
                isTitle = false
                continue
            } else if !isTitle {
                chapter += decode(html: cleared) + "\n\n"
            }
        }
        
        return (title, chapter)
    }
    
    
    static func getGen(_ inhtml: String, _ chapterNum: Int) -> (title: String, chapter: String)? {
        let stripped = inhtml.stripAndReplace()
        
        let divMatches = HTMLScraper.GENERAL_DIV_PATTERN.matches(in: stripped, options: [], range: NSMakeRange(0, stripped.count))
        
        guard let last = divMatches.last else { return nil }
        
        let div = String(stripped[Range(last.range, in: stripped)!])
        
        let matches = GENERAL_P_PATTERN.matches(in: div, options: [], range: NSMakeRange(0, div.count))
        
        guard !matches.isEmpty else { return nil }
        
        var title = ""
        var chapter = ""
        var filler = ""
        var isTitle = true
        
        for match in matches {
            var cleared = String(div[Range(match.range, in: div)!])
            for _ in 0..<10 {
                if cleared.range(of: HTMLScraper.WORD_PATTERN.pattern, options: .regularExpression) == nil {
                    break
                }
                cleared = HTMLScraper.WORD_PATTERN.stringByReplacingMatches(in: cleared, options: [], range: NSMakeRange(0, cleared.count), withTemplate: "")
            }
            if isTitle && cleared.range(of: "chapter", options: .caseInsensitive) != nil {
                title = cleared.replacingOccurrences(of: ":", with: "-").strip()
                title = HTMLScraper.decode(html: title)
                isTitle = false
                continue
            } else if isTitle {
                filler += HTMLScraper.decode(html: cleared).strip() + "\n\n"
                continue
            }
            cleared = HTMLScraper.decode(html: cleared).strip()
            if cleared.isEmpty {
                continue
            }
            chapter += cleared + "\n\n"
        }
        
        if chapter.isEmpty {
            chapter = filler
            title = "Chapter \(chapterNum)"
        }
        
        guard !chapter.isEmpty && !title.isEmpty else { return nil }
        
        return (title, chapter)
    }
    
    
    /**
     Decodes html entities.
     
     - parameter html: html text to decode.
     */
    static func decode(html: String) -> String {
        var result = html
        while let range = result.range(of: "&#?[a-zA-Z0-9]+;", options: .regularExpression) {
            let code = result[range]
            if let hash = code.range(of: "(?<=#)[a-fA-F0-9]+(?=;)", options: .regularExpression), let intrep = Int(code[hash]), let uni = UnicodeScalar(intrep) {
                result = result.replacingCharacters(in: range, with: String(Character(uni)))
            } else if let replace = HTMLScraper.mapping[String(code)] {
                result = result.replacingCharacters(in: range, with: replace)
            } else {
                result = result.replacingCharacters(in: range, with: "")
            }
        }
        return result
    }
    
    
    /**
     Saves data after fetching.  If book file already exists, append fetched data to old data,
     overwriting any overlapping data.  Otherwise, creates a new file with name _initals.json and writes data to
     it.
     
     If running in background, notifies application when done to cancel background task.
     */
    func save() {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, !ScraperOperation._data.isEmpty else {
            return
        }
        
        let _data = ScraperOperation._data
        
        var savedData: [String: String] = [:]
        var changed = true
        
        let initials = _type == .Machine ? _initials + "M" : _initials
        
        let fileURL = dir.appendingPathComponent(initials + ".json")
        
        if FileManager.default.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
            let jsonResult = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
            let result = jsonResult as? [String: String]
        {
            savedData = result
            changed = false
        }

        savedData.merge(_data) { (_, new) -> String in new }

        if let jsonData = try? JSONSerialization.data(withJSONObject: savedData, options: []), let _ = try? jsonData.write(to: fileURL, options: .atomic) {
            ScraperOperation._hasChanged = changed || ScraperOperation._hasChanged
            try? DataManager.managedContext.save()
        }
        
        ScraperOperation._data = [:]
        ScraperOperation._count = 0

        (UIApplication.shared.delegate as? AppDelegate)?.endBackground()
    }
    
    
    /**
     Login to machine website to allow download of select books.
     
     - parameters:
         - from: Staring chapter (inclusive).
         - to: Ending chapter (inclusive).
     */
    func machineLogin(from start: Int, to end: Int) {
        HTMLScraper._progressLabel?.text = "Logging in"
        Alamofire.request("https://lnmtl.com/auth/login", method: .get, parameters: nil, encoding: URLEncoding.default, headers: nil).response {
            response in
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8), let token = HTMLScraper.findToken(in: utf8Text) {
                let paramaters: Parameters = [
                    "_token": token,
                    "email": "matthewytlin@yahoo.com",
                    "password": "Asdf1234"
                ]

                Alamofire.request("https://lnmtl.com/auth/login", method: .post, parameters: paramaters, encoding: JSONEncoding.default, headers: nil).response {
                    _ in
                    HTMLScraper._loggedIn = true
                    self.get(from: start, to: end)
                }
            } else  {
                self.alert(title: "Failed to load machine chapters", message: nil)
                HTMLScraper._start?.isEnabled = true
                HTMLScraper._cancel?.isEnabled = false
                HTMLScraper._progressLabel?.text = "Loading..."
            }
        }
    }
    
    
    /**
     Find form token in html to login.
     
     - parameter in: html text.
     */
    static func findToken(in html: String) -> String? {
        let range = html.range(of: "(?<=<meta id=\"token\" name=\"token\" value=\").*?(?=\">)", options: .regularExpression)
        return range == nil ? nil : String(html[range!])
    }
    
    
    /**
     Cancel current fetch operations and save what has already been fetched.
     
     Sets progress bar and progress label to default states and resets start
     and cancel buttons.
     */
    func cancel(_ shouldAlert: Bool) {
        HTMLScraper._progressLabel?.text = "Cancelling"
        operationQueue.cancelAllOperations()
        save()
        if shouldAlert {
            self.alert(title: "Cancelled", message: nil)
        }
        HTMLScraper.reset()
    }
    
    
    static func reset() {
        _progressBar?.isHidden = true
        _progressLabel?.isHidden = true
        _start?.isEnabled = true
        _cancel?.isEnabled = false
        _progressBar?.setProgress(0, animated: false)
        _progressLabel?.text = "Loading..."
    }
    
    
    private var _title, _query, _initials: String
    private var _link: String!
    private var _hasBook: Bool
    private var _type: ScraperType
    
    private var operationQueue = OperationQueue()
    static weak var _progressBar: UIProgressView?
    static weak var _progressLabel: UILabel?
    static weak var _start, _cancel: UIButton?
    static var delegate: UIViewController?
    static var _loggedIn = false
    
    static let MACHINE_SENTENCE_PATTERN = try! NSRegularExpression(pattern: "(?<=<sentence class=\"translated\">).*?(?=</sentence>)")
    static let MACHINE_WORD_PATTERN = try! NSRegularExpression(pattern: "</?t.*?>|</?w.*?>|</?dq>")
    static let WORD_PATTERN = try! NSRegularExpression(pattern: "</?[^<]+?>")
    static let MACHINE_404 = "<div class=\"jumbotron\".*?> *<h1>#404: Not found</h1>"
    static let MACHINE_FORMAT = "https://lnmtl.com/chapter/%@-chapter-%@"
    static let MACHINE_BOOK_FORMAT = "https://lnmtl.com/chapter/%@-book-%@-chapter-%@"
    static let WW_PARAGRAPH_PATTERN = try! NSRegularExpression(pattern: "<p.*?</p>|<strong>.*?</strong>|<b.*?</b>")
    static let WW_404 = "<section class=\"error-404 not-found\">"
    static let WW_FORMAT = "http://www.wuxiaworld.com/%@-index/%@-chapter-%@/"
    static let GT_DIV_PATTEREN = try! NSRegularExpression(pattern: "<div id=\"chapterContent\"")
    static let GT_FORMAT = "http://gravitytales.com/novel/%@/%@-chapter-%@"
    static let GT_PARAGRAPH_PATTERN = try! NSRegularExpression(pattern: "<p.*?>.*?</p>")
    static let GT_PARAGRAPH_BACKUP_PATTERN = try! NSRegularExpression(pattern: "(?<=>)[^<]+(?=<br>|<hr>)")
    static let GENERAL_DIV_PATTERN = try! NSRegularExpression(pattern: "<div[^>]*>.*?<p.*?</p>.*?(Previous ++Chapter<|Next ++Chapter<)")
    static let GENERAL_P_PATTERN = try! NSRegularExpression(pattern: "<p.*?</p>")
    static let mapping: [String: String] = [
        "&nbsp;": "\u{00A0}",
        "&bdquo;": "\u{201E}",
        "&amp;": "&",
        "&rdquo;": "\"",
        "&yen;": "\u{A5}"
    ]
}
