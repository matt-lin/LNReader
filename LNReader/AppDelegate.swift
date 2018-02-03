//
//  AppDelegate.swift
//  LNReader
//
//  Created by Matt Lin on 11/24/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit
import CoreData
import SystemConfiguration
import Alamofire


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var orientationLock = UIInterfaceOrientationMask.portrait
    weak var _tableView: TableViewController?
    var bgDownload: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        window = UIWindow(frame: UIScreen.main.bounds)
        DataManager.managedContext = persistentContainer.viewContext
        
        let tableView = TableViewController()
        _tableView = tableView
        let navigationController = ViewController(rootViewController: tableView)
        navigationController.delegate = navigationController
        navigationController.isToolbarHidden = false
        window!.rootViewController = navigationController
        window!.makeKeyAndVisible()
   
        return true
    }
    

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        saveAndCancel(application)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        saveAndCancel(application)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        if bgDownload != UIBackgroundTaskInvalid {
            application.endBackgroundTask(bgDownload)
            bgDownload = UIBackgroundTaskInvalid
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        _tableView?.save()
        self.saveContext()
        _tableView?.cancel()
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }
    
    func saveAndCancel(_ application: UIApplication) {
        if let tableView = _tableView {
            tableView.save()
            self.saveContext()
            guard tableView.isActive && bgDownload == UIBackgroundTaskInvalid else { return }
            
            if UserDefaults().bool(forKey: "background_preference") {
                bgDownload = application.beginBackgroundTask(withName: "Download", expirationHandler: {
                    if self.bgDownload != UIBackgroundTaskInvalid {
                        application.endBackgroundTask(self.bgDownload)
                        tableView.cancel()
                        self.bgDownload = UIBackgroundTaskInvalid
                    }
                })
            } else {
                tableView.cancel()
            }
        }
    }
    
    func endBackground() {
        if bgDownload != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(bgDownload)
            bgDownload = UIBackgroundTaskInvalid
        }
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "LNReader")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

