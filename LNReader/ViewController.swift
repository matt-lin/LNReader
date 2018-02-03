//
//  ViewController.swift
//  LNReader
//
//  Created by Matt Lin on 11/24/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//
import UIKit

extension UINavigationController {
    func toggleNavigationBar(hide: Bool) {
        self.setNavigationBarHidden(hide, animated: true)
        self.setToolbarHidden(hide, animated: true)
    }
}

class ViewController: UINavigationController, UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is TableViewController {
            (viewController as! TableViewController).save()
        }
    }
    
    func replaceViewController(_ replacement: UIViewController) {
        var viewControllers = self.viewControllers
        viewControllers[viewControllers.count - 1] = replacement
        self.setViewControllers(viewControllers, animated: true)
    }
}
