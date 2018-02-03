//
//  EditTable.swift
//  LNReader
//
//  Created by Matt Lin on 12/15/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit

class EditTable: UIViewController, UITableViewDelegate, UITableViewDataSource {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = loadBooks()
        
        let barHeight: CGFloat = UIApplication.shared.statusBarFrame.size.height
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        
        _table = UITableView(frame: CGRect(x: 0, y: barHeight, width: displayWidth, height: displayHeight - barHeight))
        _table.register(UITableViewCell.self, forCellReuseIdentifier: "book")
        _table.dataSource = self
        _table.delegate = self
        _table.allowsSelection = false
        self.navigationItem.rightBarButtonItem = editButtonItem
        _add = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(addRow))
        
        self.view.addSubview(_table)
    }
    
    
    /**
     Reload table data if there are changes
     */
    override func viewDidAppear(_ animated: Bool) {
        if loadBooks() || _needsReset {
            _table.reloadData()
            _needsReset = false
        }
    }
    
    
    /**
     Prompt user to add/edit row.  User inputs name and intiails.  If name already exists,
     replace initials else create new name a initials.
     */
    @objc func addRow() {
        let alert = UIAlertController(title: "Add row", message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { (textField) in
            textField.placeholder = "Name"
        })
        alert.addTextField(configurationHandler: { (textField) in
            textField.placeholder = "Initials"
            textField.autocapitalizationType = .allCharacters
        })
        alert.addTextField { (textField) in
            textField.placeholder = "Range start"
            textField.keyboardType = .numberPad
        }
        alert.addTextField { (textField) in
            textField.placeholder = "Range end"
            textField.keyboardType = .numberPad
        }
        let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        let confirm = UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let textFields = alert.textFields,
                textFields.count == 4,
                let name = textFields[0].text,
                let initials = textFields[1].text,
                !name.isEmpty && !initials.isEmpty
            {
                if let ind = self._titles.index(of: name) {
                    if self._initials[ind] == initials {
                        return
                    }
                    self._initials[ind] = initials
                    self._table.reloadRows(at: [IndexPath(row: ind, section: 1)], with: .automatic)
                } else {
                    self._titles.append(name)
                    self._initials.append(initials)
                    self._table.insertRows(at: [IndexPath(row: self._initials.count - 1, section: 1)], with: .automatic)
                }
                DataManager.saveTitle(name: name, initials: initials)
                if let field1 = textFields[2].text,
                    let field2 = textFields[3].text,
                    let start = Int(field1),
                    let end = Int(field2),
                    start >= 0 && end < 5000
                {
                    for i in start...end {
                        DataManager.saveChapterTitle(chapter: i, title: "Chapter \(i)", book: name, overwrite: false)
                    }
                }
                try? DataManager.managedContext.save()
            }
        })
        
        alert.addAction(cancel)
        alert.addAction(confirm)
        self.present(alert, animated: false, completion: nil)
        return
    }
    
    
    /**
     Reset titles and initials (section 1).  Called when titles have changed.
     */
    func resetTitles(info: (titles: [String], initials: [String])) {
        _titles = info.titles
        _initials = info.initials
        _needsReset = true
    }
    
    
    /**
     Load books on initial load and reloads if changes have been made.
     */
    func loadBooks() -> Bool {
        if ScraperOperation._hasChanged,  let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [], options: []) {
            _files = []
            _fileInitials = []
            for file in contents {
                if file.absoluteString.range(of: "(?<=/)[A-Z]+(?=[.]json$)", options: .regularExpression) != nil {
                    _files.append(file)
                    _fileInitials.append(file.lastPathComponent)
                }
            }
            ScraperOperation._hasChanged = false
            return true
        }
        return false
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return _fileInitials.count
        } else {
            return _initials.count
        }
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "book", for: indexPath)
        if indexPath.section == 0 {
            cell.textLabel?.text = _fileInitials[indexPath.row]
        } else {
            cell.textLabel?.text = "\(_titles[indexPath.row]): \(_initials[indexPath.row])"
        }
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            alert(row: indexPath)
        }
    }
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Files"
        } else {
            return "Mapping"
        }
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        if editing {
            self.navigationItem.leftBarButtonItem = _add
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }
        super.setEditing(editing, animated: animated)
    }
    
    
    /**
     Alert user to confirm delete action.
     */
    func alert(row: IndexPath) {
        let displayTitle = row.section == 0 ? _fileInitials[row.row] : _titles[row.row]
        let alert = UIAlertController(title: "Delete \(displayTitle)?", message: nil, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "No", style: .default, handler: nil)
        var confirm: UIAlertAction
        if row.section == 0 {
            confirm = UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
                let title = self._files.remove(at: row.row)
                let initials = self._fileInitials.remove(at: row.row)
                if let ind = self._initials.index(of: initials) {
                    DataManager.deleteTitle(initials: initials)
                    let _ = self._titles.remove(at: ind)
                    let _ = self._initials.remove(at: ind)
                    let row2 = IndexPath(row: ind, section: 1)
                    self._table.deleteRows(at: [row, row2], with: .automatic)
                } else {
                    self._table.deleteRows(at: [row], with: .automatic)
                }
                
                try? FileManager().removeItem(at: title)
            })
        } else {
            confirm = UIAlertAction(title: "Yes", style: .default, handler: { _ in
                let _ = self._titles.remove(at: row.row)
                let initials = self._initials.remove(at: row.row)
                DataManager.deleteTitle(initials: initials)
                self._table.deleteRows(at: [row], with: .none)
            })
        }
        alert.addAction(cancel)
        alert.addAction(confirm)
        self.present(alert, animated: false, completion: nil)
        return
    }
    
    
    /**
     Checks if two arrays are equal.
     
     - parameters:
         - arr1: First array.
         - arr2: Second array.
     
     - returns:
     Returns true if the arrays are the same at each index.
     */
    static func arrayEquals(_ arr1: [String], _ arr2: [String]) -> Bool {
        if arr1.count != arr2.count {
            return false
        }
        
        for i in 0..<arr1.count {
            if arr1[i] != arr2[i] {
                return false
            }
        }
        return true
    }
    
    
    var _add: UIBarButtonItem?
    var _files: [URL] = []
    var _fileInitials: [String] = []
    var _titles: [String] = []
    var _initials: [String] = []
    var _table: UITableView!
    var _changed = false
    var _needsReset = true
}
