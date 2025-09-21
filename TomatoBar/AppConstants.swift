//
//  AppConstants.swift
//  myTomatoBar
//
//  Created by Assistant on [Date]
//

import Foundation
import CoreGraphics

// MARK: - Application Constants
enum AppConstants {
    
    // MARK: - UI Constants
    enum UI {
        static let popoverWidth: CGFloat = 240
        static let popoverWidthExpanded: CGFloat = 260
        static let buttonHeight: CGFloat = 44
        static let cornerRadius: CGFloat = 8
        static let spacing: CGFloat = 8
        static let sliderWidth: CGFloat = 110
        
        enum Animation {
            static let defaultDuration: TimeInterval = 0.3
            static let buttonPressDuration: TimeInterval = 0.1
            static let scaleDownFactor: CGFloat = 0.98
        }
    }
    
    // MARK: - Timer Constants
    enum Timer {
        static let secondsInMinute = 60
        static let defaultWorkInterval = 25
        static let defaultShortBreak = 5
        static let defaultLongBreak = 15
        static let defaultWorkIntervalsInSet = 4
        
        // Validation ranges
        static let minInterval = 1
        static let maxWorkInterval = 60
        static let maxBreakInterval = 30
        static let maxLongBreakInterval = 60
        static let maxWorkIntervalsInSet = 10
        
        // Timer precision
        static let timerTickInterval: TimeInterval = 1.0
        static let timerLeeway: DispatchTimeInterval = .milliseconds(100)
        static let overrunLimit: TimeInterval = -60.0
    }
    
    // MARK: - Audio Constants
    enum Audio {
        static let defaultVolume: Double = 1.0
        static let volumeRange = 0.0...2.0
        static let fadeOutDuration: TimeInterval = 0.5
        
        enum AssetNames {
            static let windup = "windup"
            static let ding = "ding"
            static let ticking = "ticking"
        }
    }
    
    // MARK: - Logging Constants
    enum Logging {
        static let maxLogFileSize = 10 * 1024 * 1024 // 10MB
        static let logFileName = "TomatoBar.log"
        static let rotationThreshold = 5 * 1024 * 1024 // 5MB
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let currentTimerMode = "CurrentTimerMode"
        static let workIntervalLength = "workIntervalLength"
        static let shortRestIntervalLength = "shortRestIntervalLength"
        static let longRestIntervalLength = "longRestIntervalLength"
        static let workIntervalsInSet = "workIntervalsInSet"
        static let stopAfterBreak = "stopAfterBreak"
        static let showTimerInMenuBar = "showTimerInMenuBar"
        static let selectedSoundTheme = "selectedSoundTheme"
        static let windupVolume = "windupVolume"
        static let dingVolume = "dingVolume"
        static let tickingVolume = "tickingVolume"
    }
}
