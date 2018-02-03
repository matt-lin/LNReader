//
//  VideoTableViewController.swift
//  Manga Reader
//
//  Created by Matt Lin on 1/2/18.
//  Copyright © 2018 Matt Lin. All rights reserved.
//

import UIKit
import CryptoSwift

class VideoTableViewController: UITableViewController, URLSessionDownloadDelegate {
    deinit {
        self.pause(alert: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _key = PasscodeViewController.key
        _ordering = PasscodeViewController.ordering
        PasscodeViewController.key = ""
        PasscodeViewController.ordering = []
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "video")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "progress")
        loadData()
        _progress.backgroundColor = UIColor.blue
         self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(edit))
        
        
        let reset = UIBarButtonItem(title: "Reset Cache", style: .done, target: self, action: #selector(clearCache))
        self.setToolbarItems([reset], animated: false)
        
        VideoTableViewController.current = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        loadData()
    }
    
    
    @objc func clearCache() {
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let tmp = doc.deletingLastPathComponent().appendingPathComponent("tmp", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return
        }
        
        if files.isEmpty {
            self.alert(title: "Cache is empty.", message: nil)
            return
        }
        
        let alert = UIAlertController(title: "Clear \(files.count) files?", message: "Paused files cannot be resumed if cache is cleared.", preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        let confirm = UIAlertAction(title: "Confirm", style: .default) { _ in
            var count = 0
            for file in files {
                if let _ = try? FileManager.default.removeItem(at: file) {
                    count += 1
                }
            }
            DispatchQueue.main.async {
                if count == files.count {
                    self.alert(title: "Successfully deleted cache.", message: nil)
                } else {
                    self.alert(title: "Failed to delete \(files.count - count) files", message: nil)
                }
            }
        }
        
        alert.addAction(cancel)
        alert.addAction(confirm)
        self.present(alert, animated: false, completion: nil)
    }
    
    
    @objc func edit() {
        let alert = UIAlertController(title: "Edit Video", message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { (textField) in
            textField.placeholder = "Name"
        })
        alert.addTextField(configurationHandler: { (textField) in
            textField.placeholder = "URL"
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        let confirm = UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let textFields = alert.textFields, textFields.count == 2, let name = textFields[0].text, let range = name.range(of: ".* - Episode [0-9]+", options: .regularExpression) {
                let title = String(name[range])
                guard let encoded = try? Encoder.encrypt(toCoreData: title, key: self._key) else { return }
                if let exists = DataManager.existsVideo(encoded: encoded), !exists {
                    if let url = textFields[1].text, !url.isEmpty  {
                        self.download(name: title, url: url)
                    } else  {
                        DataManager.saveVideo(encoded: encoded)
                        self.insert(title)
                        self.tableView.reloadData()
                    }
                }
            }
        })
        alert.addAction(cancel)
        alert.addAction(confirm)
        self.present(alert, animated: false, completion: nil)
    }
    
    
    func alert(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
        self.present(alert, animated: false, completion: nil)
    }
    

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return _titles.count + 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == _titles.count + 1 {
            return _paused.count
        }
        let title = _titles[section - 1]
        return _data[title]!.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "progress", for: indexPath)
            cell.contentView.addSubview(_progress)
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "video", for: indexPath)
        if indexPath.section == _titles.count + 1 {
            cell.textLabel?.text = _paused[indexPath.row]
        } else {
            cell.textLabel?.text = title(indexPath)
        }
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 0 {
            pause()
        } else if indexPath.section == _titles.count + 1 {
            resume(title: _paused[indexPath.row])
        } else {
            let fileName = title(indexPath)
            guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let downloadsFolder = doc.appendingPathComponent("Downloads", isDirectory: true)
            let name = PlayerView.hashStr(str: fileName)
            let url = downloadsFolder.appendingPathComponent("\(name)")
            if FileManager.default.fileExists(atPath: url.path) == true {
                let playerController = PlayerViewController(file: url, delegate: self)
                self.navigationController?.pushViewController(playerController, animated: false)
            }
        }
        
        return nil
    }

    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }
        return true
    }
    

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.section == _titles.count + 1 {
                let title = _paused.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, let encoded = try? Encoder.encrypt(toCoreData: title, key: self._key) else {
                    return
                }
                DataManager.deleteVideo(encoded: encoded)
                
                let file = doc.appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(PlayerView.hashStr(str: title))
                try? FileManager.default.removeItem(at: file)
            } else {
                alertRemove(indexPath)
            }
        }
    }
    
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Progress"
        } else if section == _titles.count + 1 {
            return "Paused"
        }
        return _titles[section - 1]
    }
    
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 20
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    
    func loadData() {
        if let videos = DataManager.getVideos(key: _key) {
            _data = videos.videos
            _titles = _data.keys.map {
                $0
            }.sorted()
            _paused = videos.paused
            self.tableView.reloadData()
        }
    }
    
    
    private func title(_ indexPath: IndexPath) -> String {
        let title = _titles[indexPath.section - 1]
        return _data[title]![indexPath.row]
    }
    
    
    private func remove(_ indexPath: IndexPath) {
        self.tableView.beginUpdates()
        let title = _titles[indexPath.section - 1]
        let name = _data[title]!.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        if _data[title]!.isEmpty {
            _data[title] = nil
            _titles.remove(at: indexPath.section - 1)
            let section = IndexSet(arrayLiteral: indexPath.section)
            self.tableView.deleteSections(section, with: .fade)
        }
        self.tableView.endUpdates()
        
        guard let encoded = try? Encoder.encrypt(toCoreData: name, key: _key) else {
            return
        }
        DataManager.deleteVideo(encoded: encoded)
    }
    
    
    private func alertRemove(_ indexPath: IndexPath) {
        let name = self.title(indexPath)
        let alert = UIAlertController(title: "Delete file for video \(name)", message: nil, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        let confirm = UIAlertAction(title: "Delete", style: .default, handler: { _ in
            guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            let hash = PlayerView.hashStr(str: name)
            let downloadsFolder = doc.appendingPathComponent("Downloads", isDirectory: true)
            let url = downloadsFolder.appendingPathComponent(hash)
            DispatchQueue.main.async {
                if let _ = try? FileManager.default.removeItem(at: url) {
                    self.alert(title: "Successfully deleted file.", message: nil)
                } else if !FileManager.default.fileExists(atPath: url.path) {
                    self.alert(title: "File does not exist.", message: nil)
                } else {
                    self.alert(title: "Failed to delete.", message: nil)
                }
            }
        })
        alert.addAction(cancel)
        alert.addAction(confirm)
        self.present(alert, animated: false, completion: nil)
        self.remove(indexPath)
    }
    
    
    private func insert(_ title: String) {
        let range = title.range(of: ".*(?= - Episode)", options: .regularExpression)!
        let name = String(title[range])
        if var arr = _data[name] {
            arr.append(title)
            _data[name] = arr.sorted()
        } else {
            _data[name] = [title]
            _titles.append(name)
            _titles = _titles.sorted()
        }
    }

    
    // Mark  - URL Session Download Delegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            _data.count > 0,
            let fileName = tempName,
            let encoded = try? Encoder.encrypt(toCoreData: fileName, key: _key) else { return }
        let downloadsURL = documentURL.appendingPathComponent("Downloads", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            let err = error as NSError
            if err.code != 516 {
                return
            }
        }
        DataManager.saveVideo(encoded: encoded)
       
        let name = PlayerView.hashStr(str: fileName)
        let destinationURL = downloadsURL.appendingPathComponent(name)
        
        let iv = String(name[Range(NSMakeRange(0, 16), in: name)!])
        self.insert(fileName)
        if let ind = _paused.index(of: fileName) {
            _ = _paused.remove(at: ind)
        }
        tempName = nil
        _downloadTask = nil

        encrypt(location: location, destination: destinationURL, iv: iv)
    }
    
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let diff = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self._progress.setProgress(diff, animated: false)
        }
    }

    
    func download(name: String, url: String) {
        guard let videoURL = URL(string: url.replacingOccurrences(of: " ", with: "%20")), !_downloading else {
            return
        }
        tempName = name
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        if !UserDefaults().bool(forKey: "cellular_data") {
            let request = NSMutableURLRequest(url: videoURL)
            request.allowsCellularAccess = false
            let downloadTask = session.downloadTask(with: request as URLRequest)
            _downloadTask = downloadTask
            downloadTask.resume()
        } else {
            let downloadTask = session.downloadTask(with: videoURL)
            _downloadTask = downloadTask
            downloadTask.resume()
        }
    }
    
    
    func pause(alert shouldAlert: Bool = true) {
        guard _downloading,
            let task = _downloadTask,
            let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let name = tempName,
            let encoded = try? Encoder.encrypt(toCoreData: name, key: _key)
            else { return }

        task.cancel { (data) in
            DataManager.saveVideo(encoded: encoded, downloaded: false)
            let fileName = PlayerView.hashStr(str: name)
            let file = doc.appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(fileName)
            if (try? data?.write(to: file)) != nil {
                self._paused.append(name)
                self._paused = self._paused.sorted()
                DispatchQueue.main.async {
                    self.tableView.reloadSections(IndexSet(arrayLiteral: self._titles.count + 1), with: .automatic)
                    if shouldAlert {
                        self.alert(title: "Paused", message: nil)
                    }
                }
            }
            self._downloadTask = nil
            self._progress.setProgress(0, animated: false)
        }
    }
    
    
    func resume(title: String) {
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, !_downloading else {
            return
        }
        
        let fileName = PlayerView.hashStr(str: title)
        let downloads = doc.appendingPathComponent("Downloads", isDirectory: true)
        let resumeURL = downloads.appendingPathComponent(fileName)
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        guard let data = try? Data(contentsOf: resumeURL) else {
            return
        }
        tempName = title

        let downloadTask = session.downloadTask(withResumeData: data)
        _downloadTask = downloadTask
        downloadTask.resume()
    }
    
    
    // Mark - Helper functions
    
    func encrypt(location: URL, destination: URL, iv: String) {
        DispatchQueue.main.async {
            do {
                let dat = try Data(contentsOf: location)
                var bytes = dat.bytes
                let thousand = 5000
                
                let encryptor = try AES(key: self._key, iv: iv)
                for i in self._ordering {
                    let start = i * thousand
                    let end = (i + 1) * thousand
                    let encoded = try encryptor.encrypt(bytes[start..<end])
                    bytes.replaceSubrange(start..<end, with: encoded)
                }

                let save = Data(bytes)
                try save.write(to: destination)
                self.alert(title: "Finished download.", message: nil)
            } catch {
                self.alert(title: "Download failed.", message: nil)
            }
            self.tableView.reloadData()
            self._progress.setProgress(0, animated: false)
        }
    }
    
    func decrypt(location: URL, iv: String) -> Data? {
        do {
            let dat = try Data(contentsOf: location)
            var bytes = dat.bytes
            let thousand = 5000
            
            let decryptor = try AES(key: _key, iv: iv)
            for i in _ordering.reversed() {
                let start = i * thousand
                let end = start + 5008
                let decoded = try decryptor.decrypt(bytes[start..<end])
                bytes.replaceSubrange(start..<end, with: decoded)
            }
            let dataq = Data(bytes: bytes)
            return dataq
        } catch {
            return nil
        }
    }
    
    // Table delegate vars
    var _data: [String: [String]] = [:]
    var _titles: [String] = []
    var _paused: [String] = []
    
    // URL delegate vars
    var _downloadTask: URLSessionDownloadTask? {
        willSet {
            _downloading = newValue != nil
        }
    }
    private var tempName: String?
    private var _downloading = false
    private var _key: String = "", _ordering: [Int] = []
    var _progress = UIProgressView(frame: CGRect(x: 0, y: 5, width: 375, height: 10))
    
    static var current: VideoTableViewController?
}

fileprivate class Encoder {
    static func encrypt(toCoreData title: String, key: String) throws -> String {
        let encryptor = try AES(key: key, iv: PlayerView.VAL)
        let encrypted = try encryptor.encrypt(title.bytes)
        
        return Data(bytes: encrypted).base64EncodedString()
    }
    
    static func decrypt(fromCoreData title: String, key: String) throws -> String? {
        guard let data = Data(base64Encoded: title), let decryptor = try? AES(key: key, iv: PlayerView.VAL), let encrypted = try? decryptor.decrypt(data.bytes) else {
            return nil
        }
        
        return Data(bytes: encrypted).base64EncodedString()
    }
}
