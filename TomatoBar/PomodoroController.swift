//
//  PomodoroController.swift
//  myTomatoBar
//
//  Created by Assistant on [Date]
//

import Foundation
import SwiftUI
import KeyboardShortcuts

// MARK: - Main Pomodoro Controller
class PomodoroController: ObservableObject {
    static let shared = PomodoroController()
    
    // MARK: - Modules
    private let stateManager: PomodoroStateManager
    private let sessionTracker: PomodoroSessionTracker
    private let configManager: PomodoroConfigurationManager
    private let audioManager: TBPlayer
    private let notificationManager: TBNotificationCenter
    
    // MARK: - Published Properties для UI
    @Published var timeLeftString: String = ""
    @Published var isRunning: Bool = false
    @Published var currentInterval: PomodoroSession.SessionType = .work
    @Published var currentWorkInterval: Int = 0
    @Published var todayStats: PomodoroStats = PomodoroStats()
    
    // MARK: - Private Properties
    private let timeFormatter: DateComponentsFormatter
    private var isInitialized = false
    
    // MARK: - Computed Properties для обратной совместимости
    var timer: DispatchSourceTimer? {
        return stateManager.isRunning ? DispatchSource.makeTimerSource() : nil
    }
    
    // Proxy properties для ConfigurationManager
    var workIntervalLength: Int {
        get { configManager.workIntervalLength }
        set { configManager.workIntervalLength = newValue }
    }
    
    var shortRestIntervalLength: Int {
        get { configManager.shortRestIntervalLength }
        set { configManager.shortRestIntervalLength = newValue }
    }
    
    var longRestIntervalLength: Int {
        get { configManager.longRestIntervalLength }
        set { configManager.longRestIntervalLength = newValue }
    }
    
    var workIntervalsInSet: Int {
        get { configManager.workIntervalsInSet }
        set { configManager.workIntervalsInSet = newValue }
    }
    
    var stopAfterBreak: Bool {
        get { configManager.stopAfterBreak }
        set { configManager.stopAfterBreak = newValue }
    }
    
    var showTimerInMenuBar: Bool {
        get { configManager.showTimerInMenuBar }
        set { configManager.showTimerInMenuBar = newValue }
    }
    
    var player: TBPlayer {
        return audioManager
    }
    
    // MARK: - Initialization
    private init() {
        // Initialize modules
        self.stateManager = PomodoroStateManager()
        self.sessionTracker = PomodoroSessionTracker.shared
        self.configManager = PomodoroConfigurationManager.shared
        self.audioManager = TBPlayer()
        self.notificationManager = TBNotificationCenter()
        
        // Setup time formatter
        self.timeFormatter = DateComponentsFormatter()
        timeFormatter.unitsStyle = .positional
        timeFormatter.allowedUnits = [.minute, .second]
        timeFormatter.zeroFormattingBehavior = .pad
        
        // Setup after all properties are initialized
        DispatchQueue.main.async { [weak self] in
            self?.completeInitialization()
        }
    }
    
    private func completeInitialization() {
        setupDelegates()
        setupNotifications()
        setupKeyboardShortcuts()
        updatePublishedProperties()
        
        isInitialized = true
        logger.append(event: TBLogEventPomodoroControllerInitialized())
    }
    
    private func setupDelegates() {
        stateManager.delegate = self
        sessionTracker.delegate = self
        
        notificationManager.setActionHandler { [weak self] action in
            self?.handleNotificationAction(action)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationChanged),
            name: .pomodoroConfigurationChanged,
            object: nil
        )
    }
    
    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .startStopTimer) { [weak self] in
            self?.startStop()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /// Запустить/остановить таймер (основная функция)
    func startStop() {
        guard isInitialized else {
            logger.append(event: TBLogEventControllerError(error: "Controller not initialized"))
            return
        }
        
        do {
            try stateManager.startStop()
            logger.append(event: TBLogEventControllerAction(action: "start_stop"))
        } catch {
            logger.append(event: TBLogEventControllerError(error: "Start/stop failed: \(error)"))
            ErrorReporter.shared.report(error, context: "PomodoroController.startStop")
        }
    }
    
    /// Пропустить текущий отдых
    func skipRest() {
        do {
            try stateManager.skipRest()
            logger.append(event: TBLogEventControllerAction(action: "skip_rest"))
        } catch {
            logger.append(event: TBLogEventControllerError(error: "Skip rest failed: \(error)"))
            ErrorReporter.shared.report(error, context: "PomodoroController.skipRest")
        }
    }
    
    /// Принудительная остановка (для критических ситуаций)
    func forceStop() {
        stateManager.forceStop()
        logger.append(event: TBLogEventControllerAction(action: "force_stop"))
    }
    
    /// Обновить отображение времени (для совместимости)
    func updateTimeLeft() {
        updatePublishedProperties()
    }
    
    /// Получить текущую статистику
    func getCurrentStats() -> PomodoroStats {
        return sessionTracker.getTodayStats()
    }
    
    /// Получить статистику за неделю
    func getWeekStats() -> PomodoroStats {
        return sessionTracker.getWeekStats()
    }
    
    /// Сбросить все данные (для отладки)
    func resetAllData() {
        stateManager.forceStop()
        sessionTracker.clearAllData()
        configManager.resetToDefaults()
        updatePublishedProperties()
        
        logger.append(event: TBLogEventControllerAction(action: "reset_all_data"))
    }
    
    // MARK: - Private Methods
    
    private func updatePublishedProperties() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isRunning = self.stateManager.isRunning
            self.currentWorkInterval = self.sessionTracker.currentWorkInterval
            self.todayStats = self.sessionTracker.getTodayStats()
            
            // Update time string
            let timeLeft = self.stateManager.timeRemaining
            if timeLeft > 0 {
                self.timeLeftString = self.timeFormatter.string(from: timeLeft) ?? "00:00"
            } else if self.stateManager.currentState == .idle {
                self.timeLeftString = ""
            } else {
                self.timeLeftString = "00:00"
            }
            
            // Update menu bar if needed
            if self.configManager.showTimerInMenuBar && !self.timeLeftString.isEmpty {
                TBStatusItem.shared.setTitle(title: self.timeLeftString)
            } else if self.stateManager.currentState == .idle {
                TBStatusItem.shared.setTitle(title: nil)
            }
            
            // Send notification for UI updates
            NotificationCenter.default.post(name: .timerUpdated, object: self)
        }
    }
    
    @objc private func configurationChanged() {
        logger.append(event: TBLogEventControllerAction(action: "configuration_changed"))
        updateTimeLeft()
    }
    
    private func handleNotificationAction(_ action: TBNotification.Action) {
        switch action {
        case .skipRest:
            if stateManager.currentState == .rest {
                skipRest()
                logger.append(event: TBLogEventControllerAction(action: "notification_skip_rest"))
            }
        }
    }
    
    private func updateStatusBarIcon(for state: TBStateMachineStates) {
        let iconName: NSImage.Name
        
        switch state {
        case .idle:
            iconName = .idle
        case .work:
            iconName = .work
        case .rest:
            // Определяем тип перерыва
            iconName = sessionTracker.shouldTakeLongBreak() ? .longRest : .shortRest
        }
        
        TBStatusItem.shared.setIcon(name: iconName)
    }
}

// MARK: - State Manager Delegate
extension PomodoroController: PomodoroStateDelegate {
    func stateDidStartWork() {
        currentInterval = .work
        updateStatusBarIcon(for: .work)
        
        // Audio feedback
        audioManager.playWindup()
        audioManager.startTicking()
        
        // Start session tracking
        sessionTracker.startWorkSession()
        
        logger.append(event: TBLogEventControllerStateChange(
            state: "work_started",
            context: ["work_interval": currentWorkInterval]
        ))
    }
    
    func stateDidFinishWork() {
        // Audio feedback
        audioManager.playDing()
        
        // Complete session
        sessionTracker.completeCurrentSession()
        
        logger.append(event: TBLogEventControllerStateChange(
            state: "work_finished",
            context: ["work_interval": currentWorkInterval]
        ))
    }
    
    func stateDidEndWork() {
        // Stop ticking sound
        audioManager.stopTicking()
        
        updatePublishedProperties()
    }
    
    func stateDidStartBreak(_ type: BreakType) {
        currentInterval = type == .long ? .longBreak : .shortBreak
        updateStatusBarIcon(for: .rest)
        
        // Start break session
        sessionTracker.startBreakSession(type: type)
        
        // Send notification
        let title = NSLocalizedString("TBTimer.onRestStart.title", comment: "Time's up!")
        let body = type == .long ?
            NSLocalizedString("TBTimer.onRestStart.long.body", comment: "Long break time!") :
            NSLocalizedString("TBTimer.onRestStart.short.body", comment: "Short break time!")
        
        notificationManager.send(title: title, body: body, category: .restStarted)
        
        // Reset cycle after long break
        if type == .long {
            sessionTracker.resetCycle()
        }
        
        logger.append(event: TBLogEventControllerStateChange(
            state: "break_started",
            context: [
                "break_type": type == .long ? "long" : "short",
                "should_reset_cycle": type == .long
            ]
        ))
    }
    
    func stateDidFinishBreak(wasSkipped: Bool) {
        // Complete break session
        if wasSkipped {
            sessionTracker.cancelCurrentSession()
        } else {
            sessionTracker.completeCurrentSession()
            
            // Send completion notification
            let title = NSLocalizedString("TBTimer.onRestFinish.title", comment: "Break is over!")
            let body = NSLocalizedString("TBTimer.onRestFinish.body", comment: "Ready to focus?")
            notificationManager.send(title: title, body: body, category: .restFinished)
        }
        
        logger.append(event: TBLogEventControllerStateChange(
            state: "break_finished",
            context: ["was_skipped": wasSkipped]
        ))
    }
    
    func stateDidEndBreak() {
        updatePublishedProperties()
    }
    
    func stateDidBecomeIdle() {
        currentInterval = .work
        updateStatusBarIcon(for: .idle)
        
        // Stop all audio
        audioManager.stopTicking()
        
        // Cancel any active session
        if sessionTracker.currentSession != nil {
            sessionTracker.cancelCurrentSession()
        }
        
        updatePublishedProperties()
        
        logger.append(event: TBLogEventControllerStateChange(state: "became_idle", context: nil))
    }
    
    func stateDidUpdateTime(timeLeft: TimeInterval) {
        updatePublishedProperties()
    }
    
    func stateDidEncounterError(_ error: Error) {
        logger.append(event: TBLogEventControllerError(error: "State error: \(error)"))
        ErrorReporter.shared.report(error, context: "PomodoroController.stateError")
        
        // Try to recover gracefully
        if stateManager.isRunning {
            forceStop()
        }
    }
}

// MARK: - Session Tracker Delegate
extension PomodoroController: PomodoroSessionDelegate {
    func sessionDidStart(_ session: PomodoroSession) {
        updatePublishedProperties()
        
        logger.append(event: TBLogEventControllerSessionChange(
            action: "session_started",
            sessionType: session.type.rawValue,
            sessionId: session.id.uuidString
        ))
    }
    
    func sessionDidComplete(_ session: PomodoroSession) {
        updatePublishedProperties()
        
        logger.append(event: TBLogEventControllerSessionChange(
            action: "session_completed",
            sessionType: session.type.rawValue,
            sessionId: session.id.uuidString,
            duration: session.actualDuration,
            completionRate: session.completionPercentage
        ))
    }
    
    func sessionDidCancel(_ session: PomodoroSession) {
        updatePublishedProperties()
        
        logger.append(event: TBLogEventControllerSessionChange(
            action: "session_cancelled",
            sessionType: session.type.rawValue,
            sessionId: session.id.uuidString,
            duration: session.actualDuration
        ))
    }
}

// MARK: - TimerProtocol Conformance для совместимости
extension PomodoroController: TimerProtocol {
    var currentTime: TimeInterval {
        return stateManager.timeRemaining
    }
    
    var displayText: String {
        if timeLeftString.isEmpty && stateManager.currentState == .idle {
            return "\(workIntervalLength):00"
        }
        return timeLeftString.isEmpty ? "25:00" : timeLeftString
    }
    
    func start() {
        if stateManager.currentState == .idle {
            startStop()
        }
    }
    
    func pause() {
        if isRunning {
            startStop()
        }
    }
    
    func stop() {
        if stateManager.currentState != .idle {
            startStop()
        }
    }
    
    func reset() {
        if stateManager.currentState != .idle {
            forceStop()
        }
    }
}

// MARK: - Controller Logging Events
class TBLogEventPomodoroControllerInitialized: TBLogEvent {
    let type = "pomodoro_controller_initialized"
    let timestamp = Date()
}

class TBLogEventControllerAction: TBLogEvent {
    let type = "controller_action"
    let timestamp = Date()
    let action: String
    
    init(action: String) {
        self.action = action
    }
}

class TBLogEventControllerError: TBLogEvent {
    let type = "controller_error"
    let timestamp = Date()
    let error: String
    
    init(error: String) {
        self.error = error
    }
}

class TBLogEventControllerStateChange: TBLogEvent {
    let type = "controller_state_change"
    let timestamp = Date()
    let state: String
    let workInterval: Int?
    let breakType: String?
    let wasSkipped: Bool?
    let shouldResetCycle: Bool?
    
    init(state: String, context: [String: Any]?) {
        self.state = state
        self.workInterval = context?["work_interval"] as? Int
        self.breakType = context?["break_type"] as? String
        self.wasSkipped = context?["was_skipped"] as? Bool
        self.shouldResetCycle = context?["should_reset_cycle"] as? Bool
    }
}

class TBLogEventControllerSessionChange: TBLogEvent {
    let type = "controller_session_change"
    let timestamp = Date()
    let action: String
    let sessionType: String
    let sessionId: String
    let duration: TimeInterval?
    let completionRate: Double?
    
    init(action: String, sessionType: String, sessionId: String, duration: TimeInterval? = nil, completionRate: Double? = nil) {
        self.action = action
        self.sessionType = sessionType
        self.sessionId = sessionId
        self.duration = duration
        self.completionRate = completionRate
    }
}
