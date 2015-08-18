//
//  AppDelegate.swift
//  AppRating
//
//  Created by Hannes Jung on 17/08/15.
//  Copyright (c) 2015 LOOP. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        setupAppRater()
        return true
    }
    
    func setupAppRater() {
        AppRater.sharedInstance.alertTitle = "Rate Pages"
        AppRater.sharedInstance.alertMessage = "If you enjoy using Pages, would you mind taking a moment to rate it? It won't take more than a minute. Thanks for your support!"
        AppRater.sharedInstance.alertRateTitle = "Rate Pages"
        AppRater.sharedInstance.alertRateLaterTitle = "Remind me later"
        AppRater.sharedInstance.alertCancelTitle = "No, thanks"
        
        AppRater.sharedInstance.appID = "361309726" //put app id here
        AppRater.sharedInstance.daysUntilPrompt = -1
        AppRater.sharedInstance.usesUntilPrompt = 3
        AppRater.sharedInstance.daysBeforeReminding = 3
        AppRater.sharedInstance.significantEventsUntilPrompt = -1
        AppRater.sharedInstance.resetOnNewAppVersion = false
        
        AppRater.sharedInstance.debug = true
        
        AppRater.sharedInstance.appLaunched()
    }


}

