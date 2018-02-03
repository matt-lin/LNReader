//
//  ScraperOperation.swift
//  LNReader
//
//  Created by Matt Lin on 12/29/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit
import Alamofire

class ScraperOperation: Operation {
    private var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isExecuting: Bool {
        return _executing
    }
    
    private var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isFinished: Bool {
        return _finished
    }
    
    func executing(_ executing: Bool) {
        _executing = executing
    }
    
    func finish(_ finished: Bool) {
        _finished = finished
    }
    
    private var _chapter: Int
    private var _currBook = 1
    
    static var _progressBar: UIProgressView?
    static var _increment: Float = 0
    static var _group: DispatchGroup?
    static var _data: [String: String] = [:]
    static var _get: (_ : String, _: Int) -> (title: String, chapter: String)? = { (_, _) in return nil }
    static var _query: String = ""
    static var _hasSet = false
    static var _count = 0
    static var _book = 1
    static var _hasBook = false
    static var _isGeneral = false
    static var _bookName: String = ""
    static var _hasChanged = true
    
    init(chapter: Int) {
        _chapter = chapter
    }
    
    
    override func main() {
        guard isCancelled == false && ScraperOperation._hasSet else {
            finish(true)
            return
        }
        var query: String
        if ScraperOperation._hasBook {
            _currBook = ScraperOperation._book
            query = String(format: ScraperOperation._query, _currBook, self._chapter)
        } else if ScraperOperation._isGeneral  {
            query = String(format: ScraperOperation._query, self._chapter)
        } else {
            query = String(format: ScraperOperation._query, self._chapter)
        }

        executing(true)
        
        Alamofire.request(query).validate(statusCode: 200..<300).responseData { response in
            if response.result.isSuccess, let data = response.data, let utf8Text = String(data: data, encoding: .utf8), let res = ScraperOperation._get(utf8Text, self._chapter)
            {
                DataManager.saveChapterTitle(chapter: self._chapter, title: res.title, book: ScraperOperation._bookName)
                ScraperOperation._data[String(self._chapter)] = res.chapter
                ScraperOperation._count += 1
            } else if ScraperOperation._hasBook && self._currBook < 15 {
                self._currBook += 1
                let newQuery = String(format: ScraperOperation._query, self._currBook, self._chapter)
                self.fetchBook(newQuery)
                return
            }
            ScraperOperation._progressBar?.setProgress(ScraperOperation._progressBar!.progress + ScraperOperation._increment , animated: false)
            ScraperOperation._group?.leave()
            self.executing(false)
            self.finish(true)
        }
    }
    
    func fetchBook(_ query: String) {
        Alamofire.request(query).validate(statusCode: 200..<300).responseData { response in
            if response.result.isSuccess, let data = response.data, let utf8Text = String(data: data, encoding: .utf8), let res = ScraperOperation._get(utf8Text, self._chapter)
            {
                DataManager.saveChapterTitle(chapter: self._chapter, title: res.title, book: ScraperOperation._bookName)
                ScraperOperation._data[String(self._chapter)] = res.chapter
                ScraperOperation._count += 1
                if ScraperOperation._book < self._currBook {
                    ScraperOperation._book  = self._currBook
                }
            } else if self._currBook < 15 {
                self._currBook += 1
                let newQuery = String(format: ScraperOperation._query, self._currBook, self._chapter)
                self.fetchBook(newQuery)
                return
            }
            ScraperOperation._progressBar?.setProgress(ScraperOperation._progressBar!.progress + ScraperOperation._increment , animated: false)
            ScraperOperation._group?.leave()
            self.executing(false)
            self.finish(true)
        }
    }
}
