//
//  TableViewController.swift
//  LNReader
//
//  Created by Matt Lin on 11/24/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit

class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    override func viewDidLoad() {
        super.viewDidLoad();
       
        let barHeight: CGFloat = UIApplication.shared.statusBarFrame.size.height
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        
        _tableView = UITableView(frame: CGRect(x: 0, y: barHeight, width: displayWidth, height: displayHeight - barHeight))
        _ = loadLocal()
        _tableView.register(UITableViewCell.self, forCellReuseIdentifier: "book")
        _tableView.dataSource = self
        _tableView.delegate = self
        _tableView.contentInsetAdjustmentBehavior = .automatic
        self.view.addSubview(_tableView)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        if loadLocal() {
            _tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .none)
        }
    }
    
    
    /**
     0. Number of downloaded books.
     1. 1.
     2. 1 (Hidden).
     3. 1 (Hidden).
     */
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return _titles.count
        case 1, 2, 3:
            return 1
        default:
            return 0
        }
    }
    
    
    public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case 0:
            if chapterViewController == nil {
                chapterViewController = ChapterViewController(initials: _initials[indexPath.row])
            } else {
                chapterViewController = chapterViewController!.load(initials: _initials[indexPath.row])
            }
            if chapterViewController != nil {
                self.navigationController?.pushViewController(chapterViewController!, animated: true)
            }
        case 1:
            htmlViewController.set(books: _titles)
            htmlViewController.clearFields()
            self.navigationController?.pushViewController(htmlViewController, animated: true)
        case 2:
            if _editClicks >= 2 {
                if _shouldReloadEditTable {
                    editTable.resetTitles(info: (_titles, _initials))
                    _shouldReloadEditTable = false
                }
                self.navigationController?.pushViewController(editTable, animated: true)
            }
        case 3:
            if _editClicks == 5 {
                self.navigationController?.pushViewController(PasscodeViewController(), animated: true)
            }
        default:
            break
        }
        _editClicks = 0
        return nil
    }   
    
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: "book", for: indexPath)
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = "\(_titles[indexPath.row])"
        case 1:
            cell.textLabel?.text = "Fetch chapters"
        case 2, 3:
            cell.textLabel?.text = ""
        default:
            break
        }
        return cell
    }
    
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Books"
        case 1:
            return "Online Scraper"
        default:
            return nil
        }
    }

    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && editingStyle == .delete {
            removeLocal(index: indexPath.row)
            _tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.none)
        }
    }
    
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return true
        }
        return false
    }
    
    
    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 2 && _editClicks < 2 {
            _editClicks += 1
            return false
        } else if indexPath.section == 3 && _editClicks < 5 {
            _editClicks += 1
            return false
        }
        return true
    }

    
    /**
     Sections:
     1. Downloaded books.
     2. Fetching.
     3. Error fixing.
     4. Videos.
     */
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    
    func save() {
        chapterViewController?.save()
    }
    
    
    func cancel() {
        htmlViewController.cancel()
        VideoTableViewController.current?.pause(alert: false)
    }
    
    
    var isActive: Bool {
        get {
            return htmlViewController.isActive
        }
    }
    
    
    private func loadLocal() -> Bool {
        if DataManager._titlesHaveChanged, let local = DataManager.loadTitles() {
            _titles = local.titles
            _initials = local.initials
            editTable.resetTitles(info: local)
            _shouldReloadEditTable = true
            return true
        }
        return false
    }
    
    
    private func removeLocal(index: Int) {
        let _ = _titles.remove(at: index)
        let initials = _initials.remove(at: index)
        DataManager.deleteTitle(initials: initials, shouldChange: false)
        _shouldReloadEditTable = true
    }
    
    
    private var _titles: [String] = []
    private var _initials: [String] = []
    private var _tableView: UITableView!
    private var _editClicks = 0
    private var _shouldReloadEditTable = false
    private var chapterViewController: ChapterViewController?
    private var htmlViewController = HTMLViewController()
    private var editTable = EditTable()
}
