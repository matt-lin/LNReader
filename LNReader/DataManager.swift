//
//  DataManager.swift
//  LNReader
//
//  Created by Matt Lin on 12/30/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit
import CoreData
import CryptoSwift

class DataManager: NSObject {
    /**
     Add a name and its initials to the listing of books if it doesn't exist aleady.
     
     - parameters:
        - name: Name of the Book.
        - initials: Initials the book is saved as.
     */
    static func saveTitle(name: String, initials: String, shouldChange: Bool = true) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        
        if let results = try? managedContext.fetch(fetchRequest), let result = results.first {
            if result.value(forKey: "initials") as? String != initials {
                result.setValue(initials, forKey: "initials")
            }
            return
        }
        guard let entity = NSEntityDescription.entity(forEntityName: "Book", in: managedContext) else {
            return
        }
        let entry = NSManagedObject(entity: entity, insertInto: managedContext)
        
        entry.setValue(name, forKey: "name")
        entry.setValue(initials, forKey: "initials")
        _titlesHaveChanged = _titlesHaveChanged || shouldChange
    }
    
    /**
     Delete initials from the listing if it exists.
     
     - parameter initials: Initials to delete
     */
    static func deleteTitle(initials: String, shouldChange: Bool = true) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchRequest.predicate = NSPredicate(format: "initials == %@", initials)
        
        if let results = try? managedContext.fetch(fetchRequest), let result = results.first {
            managedContext.delete(result)
            _titlesHaveChanged = _titlesHaveChanged || shouldChange
        }
    }
    
    /**
     Get the listing of books.
     
     - returns:
     A tuple containing an array of the titles and an array of the initials
     */
    static func loadTitles() -> (titles: [String], initials: [String])? {
        guard _titlesHaveChanged else {
            return nil
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchRequest.includesSubentities = false
        fetchRequest.propertiesToFetch = ["name", "initials"]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        if let results = try? managedContext.fetch(fetchRequest) {
            var titles: [String] = []
            var initials: [String] = []
            for result in results {
                titles.append(result.value(forKey: "name") as? String ?? "Name")
                initials.append(result.value(forKey: "initials") as? String ?? "ASD")
            }
            
            _titlesHaveChanged = false
            return (titles, initials)
        }
        
        return nil
    }
    
    
    static func saveChapterTitle(chapter: Int, title: String, book: String, overwrite: Bool = true) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ChapterTitle")
        fetchRequest.predicate = NSPredicate(format: "book.name == %@ && id == %d", book, chapter)
        
        if let results = try? managedContext.fetch(fetchRequest), let first = results.first {
            if overwrite {
                first.setValue(title, forKey: "title")
            }
            return
        }
        
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetch.predicate = NSPredicate(format: "name == %@", book)
        
        guard let results = try? managedContext.fetch(fetch), let bookObj = results.first, let entity = NSEntityDescription.entity(forEntityName: "ChapterTitle", in: managedContext) else { return }
        
        let chapterTitle = NSManagedObject(entity: entity, insertInto: managedContext)
        chapterTitle.setValue(chapter, forKey: "id")
        chapterTitle.setValue(title, forKey: "title")
        chapterTitle.setValue(bookObj, forKey: "book")
    }
    
    
    static func getChapterInfo(initials: String) -> (chapters: [String], numbers: [Int], chapterInd: Int, size: Int, offset: Int)? {
        let fetchChapter = NSFetchRequest<NSManagedObject>(entityName: "ChapterTitle")
        fetchChapter.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        fetchChapter.predicate = NSPredicate(format: "book.initials == %@", initials)
        
        let fetchBook = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchBook.predicate = NSPredicate(format: "initials == %@", initials)
        
        guard let results = try? managedContext.fetch(fetchChapter),
            !results.isEmpty,
            let books = try? managedContext.fetch(fetchBook),
            let book = books.first
            else { return nil }
        
        var chapters = [String]()
        var numbers = [Int]()
        
        for result in results {
            chapters.append(result.value(forKey: "title") as! String)
            numbers.append(result.value(forKey: "id") as! Int)
        }
        
        let chapter = book.value(forKey: "chapter") as! Int
        let chapterInd = ChapterViewController.binarySearch(arr: numbers, val: chapter)
        let size = book.value(forKey: "size") as! Int
        let offset = book.value(forKey: "offset") as! Int
        return (chapters, numbers, chapterInd, size, offset)
    }
    
    /**
     Get the current chapter and the font size of the book.
     
     - parameter title: Title of the book.
     
     - returns:
     A tuple with the chapter and the font size.
     */
//    static func currentChapter(title: String) -> (chapter: Int, size: Int, offset: Int)? {
//        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
//        fetchRequest.propertiesToFetch = ["chapter", "size"]
//        fetchRequest.includesSubentities = false
//        fetchRequest.predicate = NSPredicate(format: "name == %@", title)
//
//        if let results = try? managedContext.fetch(fetchRequest),
//            let first = results.first,
//            let chapter = first.value(forKey: "chapter") as? Int,
//            let size = first.value(forKey: "size") as? Int,
//            let offset = first.value(forKey: "offset") as? Int
//        {
//            return (chapter, size, offset)
//        }
//        return nil
//    }
    
    /**
     Save the chapter and font size for the book if changes have been made.
     
     - parameters:
        - chapter: The chapter number to be saved.
        - size: The font size to be saved.
        - offset: Current offset in text view.
        - initials: The initials of the book.
     */
    static func saveChapter(chapter: Int?, size: Int, offset: Int, initials: String?) {
        guard let _initials = initials, let _chapter = chapter else {
            return
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchRequest.predicate = NSPredicate(format: "initials == %@", _initials)
        
        guard let results = try? managedContext.fetch(fetchRequest), let currBook = results.first else {
            return
        }
        
        let currSize = currBook.value(forKey: "size")
        if currBook.value(forKey: "chapter") as? Int == _chapter && currSize != nil && currSize as? Int == size && currBook.value(forKey: "offset") as? Int == offset {
            return
        }
        currBook.setValue(_chapter, forKey: "chapter")
        currBook.setValue(size, forKey: "size")
        currBook.setValue(offset, forKey: "offset")
    }
    
    // Video
    /**
     Check if name already exists in the database.
     
     - parameter encoded: Encrypted name to be checked.
     
     - returns:
     Return true if name already exists, false if name doesn't exist or nil
     if error.
     */
    static func existsVideo(encoded: String) -> Bool? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Video")
        fetchRequest.predicate = NSPredicate(format: "name == %@", encoded)
        
        if let count = try? managedContext.count(for: fetchRequest), count == 1 {
            return true
        }
        return false
    }
    
    
    /**
     Encrypt title and save it to databse.
     
     - parameters:
         - title: Title of video.
         - key: Encryption key.
     */
    static func saveVideo(encoded: String, downloaded: Bool = true) {
        guard let entity = NSEntityDescription.entity(forEntityName: "Video", in: managedContext) else {
            return
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Video")
        fetchRequest.predicate = NSPredicate(format: "name == %@", encoded)

        if let results = try? managedContext.fetch(fetchRequest), let first = results.first {
            first.setValue(downloaded, forKey: "downloaded")
        } else {
            let video = NSManagedObject(entity: entity, insertInto: managedContext)
            video.setValue(encoded, forKey: "name")
            video.setValue(downloaded, forKey: "downloaded")
        }
    }
    
    
    /**
     Get videos from core data.
     
     - parameter key: Decryption key.
     
     - returns:
     A tuple with a dictionary of all downloaded videos split into series and paused videos listed.
     */
    static func getVideos(key: String) -> (videos: [String: [String]], paused: [String])? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Video")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        var mapping = [String: [String]]()
        var paused = [String]()
        let decryptor = try! AES(key: key, iv: PlayerView.VAL)
        
        if let results = try? managedContext.fetch(fetchRequest), !results.isEmpty {
            for result in results {
                guard let temp = result.value(forKey: "name") as? String,
                    let bytes = Data(base64Encoded: temp),
                    let decoded = try? decryptor.decrypt(bytes.bytes),
                    let name = String(bytes: decoded, encoding: .utf8),
                    let range = name.range(of: ".*(?= - Episode)", options: .regularExpression),
                    let downloaded = result.value(forKey: "downloaded") as? Bool else {
                    continue
                }
                
                if !downloaded {
                    paused.append(name)
                    continue
                }
                
                let tempName = String(name[range])

                if var arr = mapping[tempName] {
                    arr.append(name)
                    mapping[tempName] = arr.sorted()
                } else {
                    mapping[tempName] = [name]
                }
            }
            
            return (mapping, paused.sorted())
        }
        return nil
    }
    
    
    /**
     Delete video from core data if exists.
     
     - parameter encoded: Encrypted video title.
     */
    static func deleteVideo(encoded: String) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Video")
        fetchRequest.predicate = NSPredicate(format: "name == %@", encoded)

        if let results = try? managedContext.fetch(fetchRequest), let first = results.first {
            managedContext.delete(first)
        }
    }
    
    
    static func clearAll() {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        
        if let results = try? managedContext.fetch(fetchRequest) {
            for result in results {
                managedContext.delete(result)
            }
        }
    }
    
    static weak var managedContext: NSManagedObjectContext!
    static var _titlesHaveChanged = true
}
