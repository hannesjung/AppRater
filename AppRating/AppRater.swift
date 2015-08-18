//
//  AppRater.swift
//  AppRating
//
//  Created by Hannes Jung on 17/08/15.
//  Copyright (c) 2015 LOOP. All rights reserved.
//

import UIKit
import StoreKit
import CFNetwork
import SystemConfiguration

protocol AppRaterDelegate {
    func appRaterDidDeclineToRate(appRater: AppRater)
    func appRaterDidOptToRemindLater(appRater: AppRater)
    func appRaterDidOptToRate(appRater: AppRater)
}

class AppRater: NSObject, UIAlertViewDelegate {
    private let appRaterFirstUseDateKey = "apprater-first-use-date-key"
    private let appRaterUseCountKey = "apprater-use-count-key"
    private let appRaterSignificantEventCountKey = "apprater-significant-event-count-key"
    private let appRaterCurrentVersionKey = "apprater-current-version-key"
    private let appRaterRatedCurrentVersionKey = "apprater-rated-current-version-key"
    private let appRaterDeclinedToRateKey = "apprater-declined-to-rate-key"
    private let appRaterReminderRequestDate = "apprater-reminder-request-date-key"
    
    private let templateReviewURL = "itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=APP_ID"
    private let templateReviewURLiOS7 = "itms-apps://itunes.apple.com/app/idAPP_ID"
    private let templateReviewURLiOS8 = "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=APP_ID&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
    
    private var ratingAlert: UIAlertView?
    
    var appID: String?
    var daysUntilPrompt: Int = 30
    var usesUntilPrompt: Int = 20
    var significantEventsUntilPrompt: Int = -1
    var daysBeforeReminding: Int = 1
    var resetOnNewAppVersion: Bool = false
    var resetDismissedOnNewAppVersion: Bool = false
    var showRateLaterButton: Bool = true
    var debug = false
    
    var alertTitle = "Rate this app"
    var alertMessage = "If you enjoy using this app, would you mind taking a moment to rate it? It won't take more than a minute. Thanks for your support!"
    var alertRateTitle = "Rate it now"
    var alertRateLaterTitle = "Remind me later"
    var alertCancelTitle = "No, thanks"
    
    var delegate: AppRaterDelegate?
    
    //MARK: - Init
    class var sharedInstance: AppRater {
        struct Static {
            static let instance: AppRater = AppRater()
        }
        return Static.instance
    }

    //MARK: - Alert criteria
    private func ratingAlertIsAppropriate() -> Bool {
        return connectedToNetwork() && !userHasDeclinedToRate() && !userHasRatedCurrentVersion() && (ratingAlert == nil || (ratingAlert != nil && !ratingAlert!.visible))
    }
    
    private func connectedToNetwork() -> Bool {
        //TODO: check for network connection
        return true
    }
    
    private func userHasDeclinedToRate() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(appRaterDeclinedToRateKey)
    }
    
    private func userHasRatedCurrentVersion() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(appRaterRatedCurrentVersionKey)
    }
    
    private func ratingConditionsHaveBeenMet() -> Bool {
        if debug {return true}
        
        let defaults = NSUserDefaults.standardUserDefaults()
        
        let dateOfFirstLaunch = NSDate(timeIntervalSince1970: defaults.doubleForKey(appRaterFirstUseDateKey))
        let timeSinceFirstLaunch = NSDate().timeIntervalSinceDate(dateOfFirstLaunch)
        let timeUntilRate = NSTimeInterval(60 * 60 * 24 * daysUntilPrompt)
        if timeSinceFirstLaunch < timeUntilRate {return false}
        
        let useCount = defaults.integerForKey(appRaterUseCountKey)
        if useCount < usesUntilPrompt {return false}
        
        let significantEventCount = defaults.integerForKey(appRaterSignificantEventCountKey)
        if significantEventCount < significantEventsUntilPrompt {return false}
        
        let reminderReuqestDate = NSDate(timeIntervalSince1970: defaults.doubleForKey(appRaterReminderRequestDate))
        let timeSinceReminderRequest = NSDate().timeIntervalSinceDate(reminderReuqestDate)
        let timeUntilReminder = NSTimeInterval(60 * 60 * 24 * daysBeforeReminding)
        if timeSinceReminderRequest < timeUntilReminder {return false}
        
        return true
    }
    
    private func incrementUseCount() {
        let version = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        
        let defaults = NSUserDefaults.standardUserDefaults()
        var trackingVersion = defaults.stringForKey(appRaterCurrentVersionKey)
        
        if trackingVersion == nil {
            trackingVersion = version
            defaults.setObject(version, forKey: appRaterCurrentVersionKey)
        }
        
        //if debug {
            println("[AppRater] tracking version \(version)")
        //}
        
        //version exists
        if trackingVersion == version {
            var timeInterval = defaults.doubleForKey(appRaterFirstUseDateKey) as NSTimeInterval
            if timeInterval == 0 {
                timeInterval = NSDate().timeIntervalSince1970
                defaults.setDouble(timeInterval, forKey: appRaterFirstUseDateKey)
            }
            
            var useCount = defaults.integerForKey(appRaterUseCountKey)
            useCount++
            defaults.setInteger(useCount, forKey: appRaterUseCountKey)
            
            //if debug {
                println("[AppRater] use count = \(useCount)")
            //}
        }
        
        //new version
        else {
            defaults.setObject(version, forKey: appRaterCurrentVersionKey)
            
            if resetOnNewAppVersion || (resetDismissedOnNewAppVersion && defaults.boolForKey(appRaterDeclinedToRateKey)) {
                defaults.setDouble(NSDate().timeIntervalSince1970, forKey: appRaterFirstUseDateKey)
                defaults.setInteger(1, forKey: appRaterUseCountKey)
                defaults.setInteger(0, forKey: appRaterSignificantEventCountKey)
                defaults.setBool(false, forKey: appRaterRatedCurrentVersionKey)
                defaults.setBool(false, forKey: appRaterDeclinedToRateKey)
                defaults.setDouble(0, forKey: appRaterReminderRequestDate)
            }
        }
        
        defaults.synchronize()
    }
    
    private func incrementSignificantEventCount() {
        let version = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        
        let defaults = NSUserDefaults.standardUserDefaults()
        var trackingVersion = defaults.stringForKey(appRaterCurrentVersionKey)
        
        if trackingVersion == nil {
            trackingVersion = version
            defaults.setObject(version, forKey: appRaterCurrentVersionKey)
        }
        
        //if debug {
            println("[AppRater] tracking version \(version)")
        //}
        
        //version exists
        if trackingVersion == version {
            var timeInterval = defaults.doubleForKey(appRaterFirstUseDateKey) as NSTimeInterval
            if timeInterval == 0 {
                timeInterval = NSDate().timeIntervalSince1970
                defaults.setDouble(timeInterval, forKey: appRaterFirstUseDateKey)
            }
            
            var significantEventCount = defaults.integerForKey(appRaterSignificantEventCountKey)
            significantEventCount++
            defaults.setInteger(significantEventCount, forKey: appRaterSignificantEventCountKey)
            
            //if debug {
                println("[AppRater] significant event count = \(significantEventCount)")
            //}
        }
            
        //new version
        else {
            defaults.setObject(version, forKey: appRaterCurrentVersionKey)
            
            if resetOnNewAppVersion || (resetDismissedOnNewAppVersion && defaults.boolForKey(appRaterDeclinedToRateKey)) {
                defaults.setDouble(0, forKey: appRaterFirstUseDateKey)
                defaults.setInteger(0, forKey: appRaterUseCountKey)
                defaults.setInteger(1, forKey: appRaterSignificantEventCountKey)
                defaults.setBool(false, forKey: appRaterRatedCurrentVersionKey)
                defaults.setBool(false, forKey: appRaterDeclinedToRateKey)
                defaults.setDouble(0, forKey: appRaterReminderRequestDate)
            }
        }
        
        defaults.synchronize()
    }
    
    private func incrementAndRate(#canPromptForRating: Bool) {
        incrementUseCount()
        
        if canPromptForRating && ratingConditionsHaveBeenMet() && ratingAlertIsAppropriate() {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.showRatingAlert()
            })
        }
    }
    
    private func incrementSignificantEventAndRate(#canPromptForRating: Bool) {
        incrementSignificantEventCount()
        
        if canPromptForRating && ratingConditionsHaveBeenMet() && ratingAlertIsAppropriate() {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.showRatingAlert()
            })
        }
    }
    
    //MARK: - Show alert
    
    func appLaunched() {
        appLaunched(canPromptForRating: true)
    }
    
    func appLaunched(#canPromptForRating: Bool) {
        if debug {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.showRatingAlert()
            })
        } else {
            incrementAndRate(canPromptForRating: canPromptForRating)
        }
    }
    
    func userDidSignificantEvent(#canPromptForRating: Bool) {
        if debug {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.showRatingAlert()
            })
        } else {
            incrementSignificantEventAndRate(canPromptForRating: canPromptForRating)
        }
    }
    
    func showRatingAlert(#showRateLaterButton: Bool) {
        var controller: UIAlertView?
        if showRateLaterButton {
            controller = UIAlertView(title: alertTitle, message: alertMessage, delegate: self, cancelButtonTitle: alertCancelTitle, otherButtonTitles: alertRateTitle, alertRateLaterTitle)
        } else {
            controller = UIAlertView(title: alertTitle, message: alertMessage, delegate: self, cancelButtonTitle: alertCancelTitle, otherButtonTitles: alertRateTitle)
        }
        
        ratingAlert = controller
        controller?.show()
    }
    
    func showRatingAlert() {
        showRatingAlert(showRateLaterButton: true)
    }
    
    //MARK: - UIAlertViewDelegate
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        //no thanks
        if buttonIndex == 0 {
            //if debug {
                println("[AppRater] did decline to rate")
            //}
            delegate?.appRaterDidDeclineToRate(self)
            defaults.setBool(true, forKey: appRaterDeclinedToRateKey)
            defaults.synchronize()
        }
        
        //rate
        else if buttonIndex == 1 {
            //if debug {
                println("[AppRater] did opt to rate")
            //}
            delegate?.appRaterDidOptToRate(self)
            rateApp()
        }
        
        //remind me later
        else if buttonIndex == 2 {
            //if debug {
                println("[AppRater] did opt to remind later")
            //}
            delegate?.appRaterDidOptToRemindLater(self)
            defaults.setDouble(NSDate().timeIntervalSince1970, forKey: appRaterReminderRequestDate)
            defaults.synchronize()
        }
    }
    
    //MARK: - Rating
    
    private func rateApp() {
        if appID == nil {return}
        
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(true, forKey: appRaterRatedCurrentVersionKey)
        defaults.synchronize()
        
        let systemVersion = NSString(string: UIDevice.currentDevice().systemVersion).doubleValue
        var reviewURL = templateReviewURL.stringByReplacingOccurrencesOfString("APP_ID", withString: appID!)
        if systemVersion >= 7.0 && systemVersion < 8.0 {
            reviewURL = templateReviewURLiOS7.stringByReplacingOccurrencesOfString("APP_ID", withString: appID!)
        } else if systemVersion >= 8.0 {
            reviewURL = templateReviewURLiOS8.stringByReplacingOccurrencesOfString("APP_ID", withString: appID!)
        }
       
        UIApplication.sharedApplication().openURL(NSURL(string: reviewURL)!)
    }
}











