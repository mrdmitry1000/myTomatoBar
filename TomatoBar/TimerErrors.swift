//
//  TimerErrors.swift
//  myTomatoBar
//
//  Created by Assistant on [Date]
//

import Foundation

// MARK: - Timer Related Errors
enum TimerError: LocalizedError {
    case invalidState
    case invalidDuration
    case timerCreationFailed
    case timerAlreadyRunning
    case noActiveTimer
    case systemTimerError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidState:
            return NSLocalizedString("Timer is in invalid state", comment: "Timer state error")
        case .invalidDuration:
            return NSLocalizedString("Invalid timer duration", comment: "Duration error")
        case .timerCreationFailed:
            return NSLocalizedString("Failed to create timer", comment: "Timer creation error")
        case .timerAlreadyRunning:
            return NSLocalizedString("Timer is already running", comment: "Timer running error")
        case .noActiveTimer:
            return NSLocalizedString("No active timer found", comment: "No timer error")
        case .systemTimerError(let error):
            return NSLocalizedString("System timer error: \(error.localizedDescription)", comment: "System error")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidState:
            return NSLocalizedString("Try stopping and restarting the timer", comment: "Recovery suggestion")
        case .invalidDuration:
            return NSLocalizedString("Check timer settings and try again", comment: "Recovery suggestion")
        case .timerCreationFailed:
            return NSLocalizedString("Restart the application", comment: "Recovery suggestion")
        case .timerAlreadyRunning:
            return NSLocalizedString("Stop the current timer first", comment: "Recovery suggestion")
        case .noActiveTimer:
            return NSLocalizedString("Start a new timer session", comment: "Recovery suggestion")
        case .systemTimerError:
            return NSLocalizedString("Check system resources and try again", comment: "Recovery suggestion")
        }
    }
}

// MARK: - Configuration Errors
enum ConfigurationError: LocalizedError {
    case invalidFormat
    case invalidValues
    case missingRequiredFields
    case importFailed(String)
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return NSLocalizedString("Invalid configuration format", comment: "Config format error")
        case .invalidValues:
            return NSLocalizedString("Configuration contains invalid values", comment: "Config values error")
        case .missingRequiredFields:
            return NSLocalizedString("Missing required configuration fields", comment: "Config fields error")
        case .importFailed(let reason):
            return NSLocalizedString("Failed to import configuration: \(reason)", comment: "Import error")
        case .exportFailed(let reason):
            return NSLocalizedString("Failed to export configuration: \(reason)", comment: "Export error")
        }
    }
}

// MARK: - Audio Errors
enum AudioError: LocalizedError {
    case assetNotFound(String)
    case playerInitializationFailed
    case playbackFailed
    case volumeAdjustmentFailed
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound(let name):
            return NSLocalizedString("Audio asset '\(name)' not found", comment: "Audio asset error")
        case .playerInitializationFailed:
            return NSLocalizedString("Failed to initialize audio player", comment: "Audio init error")
        case .playbackFailed:
            return NSLocalizedString("Audio playback failed", comment: "Audio playback error")
        case .volumeAdjustmentFailed:
            return NSLocalizedString("Failed to adjust volume", comment: "Volume error")
        }
    }
}

// MARK: - Session Errors
enum SessionError: LocalizedError {
    case noActiveSession
    case sessionAlreadyActive
    case sessionDataCorrupted
    case trackingFailed
    
    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return NSLocalizedString("No active session found", comment: "Session error")
        case .sessionAlreadyActive:
            return NSLocalizedString("A session is already active", comment: "Session active error")
        case .sessionDataCorrupted:
            return NSLocalizedString("Session data is corrupted", comment: "Session data error")
        case .trackingFailed:
            return NSLocalizedString("Failed to track session", comment: "Session tracking error")
        }
    }
}

// MARK: - Error Reporter
class ErrorReporter {
    static let shared = ErrorReporter()
    
    private init() {}
    
    func report(_ error: Error, context: String? = nil) {
        let errorEvent = TBLogEventError(
            error: error,
            context: context ?? "Unknown"
        )
        logger.append(event: errorEvent)
        
        // В debug режиме выводим в консоль
        #if DEBUG
        print("🔴 Error reported: \(error.localizedDescription)")
        if let context = context {
            print("📍 Context: \(context)")
        }
        #endif
    }
    
    func reportAndThrow(_ error: Error, context: String? = nil) throws {
        report(error, context: context)
        throw error
    }
}

// MARK: - Error Logging Event
class TBLogEventError: TBLogEvent {
    let type = "error"  // Тип события для логирования
    let timestamp = Date()
    let errorClassName: String  // Название класса ошибки
    let errorMessage: String
    let context: String
    let stackTrace: String?
    
    init(error: Error, context: String) {
        self.errorClassName = String(describing: Swift.type(of: error))
        self.errorMessage = error.localizedDescription
        self.context = context
        
        // Capture stack trace in debug builds
        #if DEBUG
        self.stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        #else
        self.stackTrace = nil
        #endif
    }
}
