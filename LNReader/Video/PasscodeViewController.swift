//
//  PasscodeViewController.swift
//  LNReader
//
//  Created by Matt Lin on 1/3/18.
//  Copyright © 2018 Matt Lin. All rights reserved.
//

import UIKit

class PasscodeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view = Decoder(frame: self.view.frame, controller: self)
        PasscodeViewController.ordering = []
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func first(_ ordering: [Int], _ text: String) {
        self.view = Passcode(frame: self.view.frame, controller: self)
        PasscodeViewController.ordering = ordering
        PasscodeViewController.key = text
    }
    
    func success() {
        (self.navigationController as? ViewController)?.replaceViewController(VideoTableViewController())
    }
    
    static var ordering = [1,2,3,4]
    static var key = ""
}


fileprivate protocol View {
    func clicked(_ order: Int)
}


fileprivate class Decoder: UIView, View {
    init(frame: CGRect, controller: PasscodeViewController) {
        _ordering = [0, 1, 2, 3]
        _textField = UITextField(frame: CGRect(x: 10, y: 100, width: 200, height: 50))

        super.init(frame: frame)
        _controller = controller
        self.backgroundColor = UIColor.white
        
        self.addSubview(Button(x: 0, y: 146, delegate: self, order: 1, show: true)) //1
        self.addSubview(Button(x: 125, y: 146, delegate: self, order: 2, show: true)) //2
        self.addSubview(Button(x: 250, y: 146, delegate: self, order: 3, show: true)) //3
        self.addSubview(Button(x: 0, y: 271, delegate: self, order: 4, show: true)) //4
        self.addSubview(Button(x: 125, y: 271, delegate: self, order: 5, show: true)) //5
        self.addSubview(Button(x: 250, y: 271, delegate: self, order: 6, show: true)) //6
        self.addSubview(Button(x: 0, y: 396, delegate: self, order: 7, show: true)) //7
        self.addSubview(Button(x: 125, y: 396, delegate: self, order: 8, show: true)) //8
        self.addSubview(Button(x: 250, y: 396, delegate: self, order: 9, show: true)) //9
        
        _textField.isSecureTextEntry = true
        self.addSubview(_textField)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clicked(_ order: Int) {
        if _ordering.contains(order) {
            _ordering.append(order + 17)
        } else {
            _ordering.append(order)
        }
        if _ordering.count == 14 {
            guard let text = _textField.text, text.count == 16 else {
                _ordering = [0, 1, 2, 3]
                return
            }
            _controller?.first(_ordering, text)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _textField.resignFirstResponder()
    }
    
    weak var _controller: PasscodeViewController?
    var _ordering: [Int]
    var _textField: UITextField
}


fileprivate class Passcode: UIView, View {
    init(frame: CGRect, controller: PasscodeViewController) {
        super.init(frame: frame)
        self.isMultipleTouchEnabled = false
        self.backgroundColor = UIColor.white
        
        _controller = controller
        self.addSubview(Button(x: 0, y: 146, delegate: self, order: 6)) //1
        self.addSubview(Button(x: 125, y: 146, delegate: self, order: 3)) //2
        self.addSubview(Button(x: 250, y: 146, delegate: self, order: 0)) //3
        self.addSubview(Button(x: 0, y: 271, delegate: self, order: 2)) //4
        self.addSubview(Button(x: 125, y: 271, delegate: self, order: 7)) //5
        self.addSubview(Button(x: 250, y: 271, delegate: self, order: 4)) //6
        self.addSubview(Button(x: 0, y: 396, delegate: self, order: 5)) //7
        self.addSubview(Button(x: 125, y: 396, delegate: self, order: 1)) //8
        self.addSubview(Button(x: 250, y: 396, delegate: self, order: 8)) //9
        let line1 = UIView(frame: CGRect(x: 187, y: 0, width: 5, height: 667))
        line1.backgroundColor = UIColor.black
        line1.isUserInteractionEnabled = false
        
        let line2 = UIView(frame: CGRect(x: 0, y: 333, width: 375, height: 5))
        line2.backgroundColor = UIColor.black
        line1.isUserInteractionEnabled = false
        self.addSubview(line1)
        self.addSubview(line2)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func clicked(_ order: Int) {
        if order == current {
            if order == NUM {
                _controller?.success()
            }
            current += 1
        } else {
            current = 0
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        current = 0
    }
    
    weak var _controller: PasscodeViewController?
    var current: Int = 0
    let NUM = 8
}


fileprivate class Button: UIView {
    init(x: CGFloat, y: CGFloat, delegate: View, order: Int, show: Bool = false) {
        _delegate = delegate
        _order = order
        super.init(frame: CGRect(x: x, y: y, width: 125, height: 125))
        if show {
            self.backgroundColor = UIColor.blue
            self.layer.borderColor = UIColor.black.cgColor
            self.layer.borderWidth = 1
        } else {
            self.backgroundColor = UIColor.white
        }
        self.isMultipleTouchEnabled = false
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _delegate?.clicked(_order)
    }
    
    
    var _delegate: View?
    var _order: Int
}
