//
//  PlayerViewController.swift
//  Manga Reader
//
//  Created by Matt Lin on 1/2/18.
//  Copyright © 2018 Matt Lin. All rights reserved.
//

import UIKit

struct AppUtility {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
        
        self.lockOrientation(orientation)
        
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
    }

}

class PlayerViewController: UIViewController {
    required init(file: URL, delegate: VideoTableViewController?) {
        _file = file
        _delegate = delegate
        
        super.init(nibName: nil, bundle: nil)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view = PlayerView(frame: self.view.frame, file: _file, delegate: _delegate)
        playerView.navigationController = self.navigationController as? ViewController
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.landscape, andRotateTo: .landscapeLeft)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.navigationController?.setToolbarHidden(true, animated: false)
        playerView.show()
    }
    
    
    var playerView: PlayerView {
        return self.view as! PlayerView
    }
    
    
    var _file: URL
    weak private var _delegate: VideoTableViewController?
}
