//
//  HTMLViewController.swift
//  LNReader
//
//  Created by Matt Lin on 12/8/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit

class HTMLViewController: UIViewController {
    init() {
        _titlebox = UITextField(frame: CGRect(x: 30, y: 100, width: 300, height: 50))
        _querybox = UITextField(frame: CGRect(x: 30, y: 150, width: 300, height: 50))
        _typebox = TypePicker(frame: CGRect(x: 30, y: 200, width: 300, height: 50))
        _initialsbox = UITextField(frame: CGRect(x: 30, y: 250, width: 100, height: 50))
        _frombox = UITextField(frame: CGRect(x: 30, y: 300, width: 50, height: 50))
        _tobox = UITextField(frame: CGRect(x: 110, y: 300, width: 50, height: 50))
        _linkbox = UITextField(frame: CGRect(x: 30, y: 200, width: 300, height: 50))
        _button = UIButton(frame: CGRect(x: 30, y: 350, width: 70, height: 35))
        _cancel = UIButton(frame: CGRect(x: 275, y: 350, width: 70, height: 35))
        _autoCompleteTable = UITableView(frame: CGRect(x: 30, y: 150, width: 300, height: 120))
        _tableDelegate = AutoCompleter(textbox: _titlebox)
        
        _progressBar = UIProgressView(frame: CGRect(x: 37.5, y: 430, width: 300, height: 50))
        _progressBar.isHidden = true
        
        _progressLabel = UILabel(frame: CGRect(x: 37.5, y: 400, width: 300, height: 20))
        _progressLabel.text = "Loading..."
        _progressLabel.isHidden = true
        _progressLabel.textAlignment = .center
        HTMLScraper._progressBar = _progressBar
        HTMLScraper._progressLabel = _progressLabel
        HTMLScraper._start = _button
        HTMLScraper._cancel = _cancel
        
        super.init(nibName: nil, bundle: nil)
        self.view.backgroundColor = UIColor.white
        self.view.isMultipleTouchEnabled = false
        
        HTMLScraper.delegate = self
        
        _titlebox.placeholder = "Title"
        _titlebox.autocapitalizationType = .none
        _titlebox.addTarget(self, action: #selector(showAutoComplete), for: .editingDidBegin)
        _titlebox.addTarget(self, action: #selector(checkAutoComplete(sender:)), for: .editingChanged)
        _titlebox.addTarget(self, action: #selector(hideAutoComplete), for: .editingDidEnd)
        
        _querybox.placeholder = "Query"
        _querybox.autocorrectionType = .no
        _querybox.autocapitalizationType = .none
        
        _initialsbox.placeholder = "Initials"
        _initialsbox.autocorrectionType = .no
        _initialsbox.autocapitalizationType = .allCharacters
        
        _frombox.placeholder = "From"
        _frombox.keyboardType = UIKeyboardType.numberPad
        
        _tobox.placeholder = "To"
        _tobox.keyboardType = UIKeyboardType.numberPad
        
        _linkbox.placeholder = "Link"
        _linkbox.autocorrectionType = .no
        _linkbox.isHidden = true
        _linkbox.autocapitalizationType = .none
        
        _typebox.dataSource = _typebox
        _typebox.delegate = _typebox
        _typebox._delegate = self
        
        _button.setTitle("Fetch", for: .normal)
        _button.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
        _button.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.5), for: .highlighted)
        _button.setTitleColor(UIColor.gray, for: .disabled)
        _button.addTarget(self, action: #selector(fetchChapter), for: .touchUpInside)
        
        _cancel.setTitle("Cancel", for: .normal)
        _cancel.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
        _cancel.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.5), for: .highlighted)
        _cancel.setTitleColor(UIColor.gray, for: .disabled)
        _cancel.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        _cancel.isEnabled = false
        
        _autoCompleteTable.delegate = _tableDelegate
        _autoCompleteTable.dataSource = _tableDelegate
        _autoCompleteTable.isScrollEnabled = false
        _autoCompleteTable.isHidden = true
        _autoCompleteTable.tableFooterView = UIView(frame: CGRect.zero)
        _autoCompleteTable.register(UITableViewCell.self, forCellReuseIdentifier: "title")
        _autoCompleteTable.separatorStyle = UITableViewCellSeparatorStyle.none
        
        self.view.addSubview(_titlebox)
        self.view.addSubview(_querybox)
        self.view.addSubview(_initialsbox)
        self.view.addSubview(_frombox)
        self.view.addSubview(_tobox)
        self.view.addSubview(_linkbox)
        self.view.addSubview(_typebox)
        self.view.addSubview(_button)
        self.view.addSubview(_cancel)
        self.view.addSubview(_autoCompleteTable)
        self.view.addSubview(_progressBar)
        self.view.addSubview(_progressLabel)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    @objc func hideAutoComplete() {
        self._autoCompleteTable.isHidden = true
    }
    
    
    @objc func showAutoComplete() {
        self._autoCompleteTable.isHidden = false
    }
    
    
    @objc func checkAutoComplete(sender: UITextField) {
        if let text = sender.text, _tableDelegate.searchAutocomplete(substr: text) {
            _autoCompleteTable.reloadData()
        }
    }
    
    
    @objc func cancel(alert shouldAlert: Bool = true) {
        _cancel.isEnabled = false
        _scraper?.cancel(shouldAlert)
    }
    
    
    func set(books: [String]) {
        _tableDelegate.change(books: books)
        _autoCompleteTable.reloadData()
    }
    
    
    /**
     Fetch chapter with information in textboxes and selector.  Alert user
     if title is empty, an incorrect range of chapters is given or if
     no query is given with either ww searches or gravity tales searches.
     */
    @objc func fetchChapter() {
        _button.isEnabled = false
        _cancel.isEnabled = true
        let title = _titlebox.text ?? ""
        let query = _querybox.text?.isEmpty ?? true ? nil : _querybox.text
        let initials = _initialsbox.text?.isEmpty ?? true ? nil : _initialsbox.text
        let from = Int(_frombox.text ?? "") ?? 1
        let to = Int(_tobox.text ?? "")
        let link = _linkbox.text?.isEmpty ?? true ? nil : _linkbox.text
        let hasBook = _typebox.selected == .Machine && _typebox.hasBook
        
        if title.isEmpty {
            alert(title: "Missing title", message: "Please enter a title.")
            _button.isEnabled = true
            _cancel.isEnabled = false
            return
        } else if to == nil || to! < from || from < 1 || to! > 5000 {
            alert(title: "Incorrect range", message: "Please enter a valid chapter range.")
            _button.isEnabled = true
            _cancel.isEnabled = false
            return
        } else if (_typebox.selected == .WW || _typebox.selected == .GravityTales) && query == nil {
            alert(title: "Missing query", message: "Please add a query when searching \(_typebox.selected.rawValue).")
            _button.isEnabled = true
            _cancel.isEnabled = false
            return
        } else if _typebox.selected == .General && link == nil {
            alert(title: "Missing link", message: "Please add a link when searching general.")
            _button.isEnabled = true
            _cancel.isEnabled = false
            return
        }
        
        let scraper = HTMLScraper(title: title, type: _typebox.selected, query: query, hasBook: hasBook, initials: initials, link: link)
        _scraper = scraper
        
        _progressBar.isHidden = false
        _progressLabel.isHidden = false
        scraper.fetch(from: from, to: to!)
        releaseFirstResponder()
    }
    
    
    func alert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
        self.present(alert, animated: false, completion: nil)
        _button.isEnabled = true
        _progressBar.isHidden = true
        _progressLabel.isHidden = true
        return
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseFirstResponder()
    }
    
    
    func releaseFirstResponder() {
        if _titlebox.isFirstResponder {
            _titlebox.resignFirstResponder()
        } else if _querybox.isFirstResponder {
            _querybox.resignFirstResponder()
        } else if _initialsbox.isFirstResponder {
            _initialsbox.resignFirstResponder()
        } else if _frombox.isFirstResponder {
            _frombox.resignFirstResponder()
        } else if _tobox.isFirstResponder {
            _tobox.resignFirstResponder()
        }
    }
    
    
    func clearFields() {
        _titlebox.text = nil
        _querybox.text = nil
        _initialsbox.text = nil
        _frombox.text = nil
        _tobox.text = nil
        _linkbox.text = nil
        _tableDelegate.clear()
        _autoCompleteTable.reloadData()
        _typebox.selectRow(0, inComponent: 0, animated: false)
        _typebox.pickerView(_typebox, didSelectRow: 0, inComponent: 0)
        _typebox.selectRow(0, inComponent: 1, animated: false)
        _typebox.pickerView(_typebox, didSelectRow: 0, inComponent: 1)
    }
    
    
    func toggleLinkBox() {
        UIView.transition(with: self._querybox, duration: 0.2, options: .transitionCrossDissolve, animations: {
            if self._linkbox.isHidden {
                self._querybox.isHidden = true
                self._typebox.frame.origin.y -= 50
            } else {
                self._querybox.isHidden = false
                self._typebox.frame.origin.y += 50
            }
        }) { (completed) in
            if completed {
                self._linkbox.isHidden = !self._linkbox.isHidden
            }
        }
    }
    
    var isActive: Bool {
        get {
            return _cancel.isEnabled
        }
    }
    
    private var _titlebox, _querybox, _initialsbox, _frombox, _tobox, _linkbox: UITextField
    private var _button, _cancel: UIButton
    private var _typebox: TypePicker
    private var _autoCompleteTable: UITableView
    private var _tableDelegate: AutoCompleter
    private var _scraper: HTMLScraper?
    private var _progressBar: UIProgressView
    private var _progressLabel: UILabel
}


fileprivate class TypePicker: UIPickerView, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return selected == .Machine ? 2 : 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return component == 1 ? 2 : ScraperType.vals.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 1 {
            return row == 0 ? "" : "Book"
        }
        return ScraperType.vals[row].rawValue
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 1 {
            hasBook = row != 0
            return
        }
        
        let prev = selected
        selected = ScraperType.vals[row]
        if (selected == .Machine) == (prev != .Machine) {
            pickerView.reloadAllComponents()
            hasBook = false
        }
        
        if (selected == .General) == (prev != .General) {
            _delegate?.toggleLinkBox()
        }
    }
    
    var selected = ScraperType.Machine
    var hasBook = false
    
    var _delegate: HTMLViewController?
}


fileprivate class AutoCompleter: NSObject, UITableViewDataSource, UITableViewDelegate {
    init(textbox: UITextField) {
        _textbox = textbox
    }
    
    
    /**
     Change the list of books to autocomplete.  Removes duplication
     'Machine' titles.
     */
    func change(books: [String]) {
        for book in books {
            let title = book.replacingOccurrences(of: " - Machine", with: "")
            if !_data.contains(title) {
                _data.append(title)
            }
        }
        _display = _data
    }
    
    
    func clear() {
        _display = _data
    }
    
    
    /**
     Compares current substring in textbox to other titles to make
     an autocomplete form.
     
     - parameter substr: Current text in textbox.
     
     - returns:
     True if changes were made to _display.
     */
    func searchAutocomplete(substr: String) -> Bool {
        if substr.isEmpty {
            _display = _data
            return true
        }
        
        var newDisplay: [String] = []
        for book in _data {
            if book.localizedCaseInsensitiveContains(substr) {
                newDisplay.append(book)
            }
        }
        if arrayEquals(arr1: newDisplay, arr2: _display) {
            return false
        }
        _display = newDisplay
        return true
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "title", for: indexPath)
        cell.textLabel?.text = _display[indexPath.row]
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let text = _display[indexPath.row]
        _textbox.text = text
        tableView.isHidden = true
        if searchAutocomplete(substr: text) {
            tableView.reloadData()
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 30
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _display.count >= 4 ? 4 : _display.count
    }
    
    
    /**
     Compares 2 arrays up to the 4th value.
     
     - parameters:
     - arr1: First array.
     - arr2: Second array.
     
     - returns:
     True if both arrays are the same up until the 4th value.
     */
    func arrayEquals(arr1: [String], arr2: [String]) -> Bool {
        if arr1.count <= 4 && arr2.count <= 4 && arr1.count != arr2.count {
            return false
        }
        
        let end = min(arr1.count, arr2.count, 4)
        for i in 0..<end {
            if arr1[i] != arr2[i] {
                return false
            }
        }
        return true
    }
    
    
    var _data: [String] = []
    var _display: [String] = []
    var _textbox: UITextField
}
