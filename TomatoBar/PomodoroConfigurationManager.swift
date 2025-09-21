//
//  PomodoroConfigurationManager.swift
//  myTomatoBar
//
//  Created by Assistant on [Date]
//

import Foundation
import SwiftUI

// MARK: - Configuration Manager
class PomodoroConfigurationManager: ObservableObject {
    static let shared = PomodoroConfigurationManager()
    
    // MARK: - Timer Settings
    @AppStorage(AppConstants.StorageKeys.workIntervalLength) 
    var workIntervalLength = AppConstants.Timer.defaultWorkInterval {
        didSet { validateAndNotify() }
    }
    
    @AppStorage(AppConstants.StorageKeys.shortRestIntervalLength) 
    var shortRestIntervalLength = AppConstants.Timer.defaultShortBreak {
        didSet { validateAndNotify() }
    }
    
    @AppStorage(AppConstants.StorageKeys.longRestIntervalLength) 
    var longRestIntervalLength = AppConstants.Timer.defaultLongBreak {
        didSet { validateAndNotify() }
    }
    
    @AppStorage(AppConstants.StorageKeys.workIntervalsInSet) 
    var workIntervalsInSet = AppConstants.Timer.defaultWorkIntervalsInSet {
        didSet { validateAndNotify() }
    }
    
    // MARK: - Behavior Settings
    @AppStorage(AppConstants.StorageKeys.stopAfterBreak) 
    var stopAfterBreak = false {
        didSet { notifyConfigurationChanged() }
    }
    
    @AppStorage(AppConstants.StorageKeys.showTimerInMenuBar) 
    var showTimerInMenuBar = true {
        didSet { notifyConfigurationChanged() }
    }
    
    // MARK: - Private Properties
    private let validationQueue = DispatchQueue(label: "config.validation", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        validateConfiguration()
        logger.append(event: TBLogEventConfigurationLoaded())
    }
    
    // MARK: - Validation
    private func validateConfiguration() {
        var hasChanges = false
        
        // Validate work interval
        let validWorkInterval = max(
            AppConstants.Timer.minInterval, 
            min(workIntervalLength, AppConstants.Timer.maxWorkInterval)
        )
        if validWorkInterval != workIntervalLength {
            workIntervalLength = validWorkInterval
            hasChanges = true
        }
        
        // Validate short rest interval
        let validShortRest = max(
            AppConstants.Timer.minInterval, 
            min(shortRestIntervalLength, AppConstants.Timer.maxBreakInterval)
        )
        if validShortRest != shortRestIntervalLength {
            shortRestIntervalLength = validShortRest
            hasChanges = true
        }
        
        // Validate long rest interval
        let validLongRest = max(
            AppConstants.Timer.minInterval, 
            min(longRestIntervalLength, AppConstants.Timer.maxLongBreakInterval)
        )
        if validLongRest != longRestIntervalLength {
            longRestIntervalLength = validLongRest
            hasChanges = true
        }
        
        // Validate work intervals in set
        let validWorkIntervalsInSet = max(
            1, 
            min(workIntervalsInSet, AppConstants.Timer.maxWorkIntervalsInSet)
        )
        if validWorkIntervalsInSet != workIntervalsInSet {
            workIntervalsInSet = validWorkIntervalsInSet
            hasChanges = true
        }
        
        if hasChanges {
            logger.append(event: TBLogEventConfigurationValidated())
        }
    }
    
    private func validateAndNotify() {
        validationQueue.async { [weak self] in
            self?.validateConfiguration()
            DispatchQueue.main.async {
                self?.notifyConfigurationChanged()
            }
        }
    }
    
    private func notifyConfigurationChanged() {
        NotificationCenter.default.post(
            name: .pomodoroConfigurationChanged, 
            object: self
        )
        logger.append(event: TBLogEventConfigurationChanged())
    }
    
    // MARK: - Public Methods
    
    /// Сбросить все настройки к значениям по умолчанию
    func resetToDefaults() {
        logger.append(event: TBLogEventConfigurationReset())
        
        workIntervalLength = AppConstants.Timer.defaultWorkInterval
        shortRestIntervalLength = AppConstants.Timer.defaultShortBreak
        longRestIntervalLength = AppConstants.Timer.defaultLongBreak
        workIntervalsInSet = AppConstants.Timer.defaultWorkIntervalsInSet
        stopAfterBreak = false
        showTimerInMenuBar = true
        
        notifyConfigurationChanged()
    }
    
    /// Получить текущую конфигурацию для экспорта
    func exportConfiguration() -> [String: Any] {
        let config: [String: Any] = [
            "workIntervalLength": workIntervalLength,
            "shortRestIntervalLength": shortRestIntervalLength,
            "longRestIntervalLength": longRestIntervalLength,
            "workIntervalsInSet": workIntervalsInSet,
            "stopAfterBreak": stopAfterBreak,
            "showTimerInMenuBar": showTimerInMenuBar,
            "exportDate": Date().timeIntervalSince1970,
            "version": "1.0"
        ] as [String : Any]
        
        logger.append(event: TBLogEventConfigurationExported())
        return config
    }
    
    /// Импортировать конфигурацию
    func importConfiguration(_ config: [String: Any]) throws {
        // Validate required fields
        guard let work = config["workIntervalLength"] as? Int,
              let shortRest = config["shortRestIntervalLength"] as? Int,
              let longRest = config["longRestIntervalLength"] as? Int,
              let intervals = config["workIntervalsInSet"] as? Int else {
            throw ConfigurationError.missingRequiredFields
        }
        
        // Validate ranges
        guard work >= AppConstants.Timer.minInterval && work <= AppConstants.Timer.maxWorkInterval,
              shortRest >= AppConstants.Timer.minInterval && shortRest <= AppConstants.Timer.maxBreakInterval,
              longRest >= AppConstants.Timer.minInterval && longRest <= AppConstants.Timer.maxLongBreakInterval,
              intervals >= 1 && intervals <= AppConstants.Timer.maxWorkIntervalsInSet else {
            throw ConfigurationError.invalidValues
        }
        
        // Apply configuration
        workIntervalLength = work
        shortRestIntervalLength = shortRest
        longRestIntervalLength = longRest
        workIntervalsInSet = intervals
        
        // Optional fields
        if let stopAfter = config["stopAfterBreak"] as? Bool {
            stopAfterBreak = stopAfter
        }
        if let showTimer = config["showTimerInMenuBar"] as? Bool {
            showTimerInMenuBar = showTimer
        }
        
        logger.append(event: TBLogEventConfigurationImported())
        notifyConfigurationChanged()
    }
    
    /// Проверить валидность текущей конфигурации
    func validateCurrentConfiguration() -> Bool {
        return workIntervalLength >= AppConstants.Timer.minInterval &&
               workIntervalLength <= AppConstants.Timer.maxWorkInterval &&
               shortRestIntervalLength >= AppConstants.Timer.minInterval &&
               shortRestIntervalLength <= AppConstants.Timer.maxBreakInterval &&
               longRestIntervalLength >= AppConstants.Timer.minInterval &&
               longRestIntervalLength <= AppConstants.Timer.maxLongBreakInterval &&
               workIntervalsInSet >= 1 &&
               workIntervalsInSet <= AppConstants.Timer.maxWorkIntervalsInSet
    }
    
    /// Получить длительность в секундах
    func getWorkDurationInSeconds() -> TimeInterval {
        return TimeInterval(workIntervalLength * AppConstants.Timer.secondsInMinute)
    }
    
    func getShortBreakDurationInSeconds() -> TimeInterval {
        return TimeInterval(shortRestIntervalLength * AppConstants.Timer.secondsInMinute)
    }
    
    func getLongBreakDurationInSeconds() -> TimeInterval {
        return TimeInterval(longRestIntervalLength * AppConstants.Timer.secondsInMinute)
    }
}

// MARK: - Configuration Events для логирования
class TBLogEventConfigurationLoaded: TBLogEvent {
    let type = "configuration_loaded"
    let timestamp = Date()
}

class TBLogEventConfigurationChanged: TBLogEvent {
    let type = "configuration_changed"
    let timestamp = Date()
}

class TBLogEventConfigurationValidated: TBLogEvent {
    let type = "configuration_validated"
    let timestamp = Date()
}

class TBLogEventConfigurationReset: TBLogEvent {
    let type = "configuration_reset"
    let timestamp = Date()
}

class TBLogEventConfigurationExported: TBLogEvent {
    let type = "configuration_exported"
    let timestamp = Date()
}

class TBLogEventConfigurationImported: TBLogEvent {
    let type = "configuration_imported"
    let timestamp = Date()
}

// MARK: - Notification Extension
extension Notification.Name {
    static let pomodoroConfigurationChanged = Notification.Name("PomodoroConfigurationChanged")
}

// MARK: - Configuration Preview для SwiftUI
#if DEBUG
extension PomodoroConfigurationManager {
    static let preview: PomodoroConfigurationManager = {
        let manager = PomodoroConfigurationManager()
        return manager
    }()
}
#endif
