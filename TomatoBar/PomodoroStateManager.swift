//
//  PomodoroStateManager.swift
//  myTomatoBar
//
//  Created by Assistant on [Date]
//

import Foundation
import SwiftState

// MARK: - State Manager
class PomodoroStateManager {
    
    // MARK: - Properties
    private var stateMachine: TBStateMachine
    private var currentTimer: DispatchSourceTimer?
    private var finishTime: Date?
    private let timerQueue = DispatchQueue(label: "pomodoro.timer", qos: .userInteractive)
    
    weak var delegate: PomodoroStateDelegate?
    
    // MARK: - Public Properties
    var currentState: TBStateMachineStates {
        return stateMachine.state
    }
    
    var isRunning: Bool {
        return currentTimer != nil
    }
    
    var timeRemaining: TimeInterval {
        guard let finishTime = finishTime else { return 0 }
        return max(0, finishTime.timeIntervalSince(Date()))
    }
    
    // MARK: - Initialization
    init() {
        self.stateMachine = TBStateMachine(state: .idle)
        setupStateMachine()
        logger.append(event: TBLogEventStateManagerInitialized())
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - State Machine Setup
    private func setupStateMachine() {
        // Define state transitions
        stateMachine.addRoutes(event: .startStop, transitions: [
            .idle => .work,
            .work => .idle,
            .rest => .idle
        ])
        
        stateMachine.addRoutes(event: .timerFired, transitions: [
            .work => .rest
        ])
        
        // Conditional transitions based on configuration
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .idle]) { _ in
            return PomodoroConfigurationManager.shared.stopAfterBreak
        }
        
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .work]) { _ in
            return !PomodoroConfigurationManager.shared.stopAfterBreak
        }
        
        stateMachine.addRoutes(event: .skipRest, transitions: [
            .rest => .work
        ])
        
        // Add state handlers
        stateMachine.addAnyHandler(.any => .work, order: 0, handler: onWorkStart)
        stateMachine.addAnyHandler(.work => .rest, order: 0, handler: onWorkFinish)
        stateMachine.addAnyHandler(.work => .any, order: 1, handler: onWorkEnd)
        stateMachine.addAnyHandler(.any => .rest, order: 0, handler: onRestStart)
        stateMachine.addAnyHandler(.rest => .work, order: 0, handler: onRestFinish)
        stateMachine.addAnyHandler(.rest => .idle, order: 0, handler: onRestEnd)
        stateMachine.addAnyHandler(.any => .idle, order: 1, handler: onIdleStart)
        
        // Add transition logging
        stateMachine.addAnyHandler(.any => .any, order: 255, handler: { [weak self] ctx in
            self?.logStateTransition(context: ctx)
        })
        
        // Error handling
        stateMachine.addErrorHandler { [weak self] ctx in
            let error = TimerError.invalidState
            self?.delegate?.stateDidEncounterError(error)
            ErrorReporter.shared.report(error, context: "State machine error: \(ctx)")
        }
    }
    
    // MARK: - Public Interface
    
    /// Запустить/остановить таймер
    func startStop() throws {
        logger.append(event: TBLogEventStateAction(action: "start_stop_requested", currentState: currentState.rawValue))
        
        // Убираем try-catch, так как <-! не throws
        stateMachine <-! .startStop
    }
    
    /// Пропустить отдых
    func skipRest() throws {
        guard currentState == .rest else {
            throw TimerError.invalidState
        }
        
        logger.append(event: TBLogEventStateAction(action: "skip_rest_requested", currentState: currentState.rawValue))
        
        // Убираем try-catch, так как <-! не throws
        stateMachine <-! .skipRest
    }
    
    /// Принудительно остановить таймер (для экстренных случаев)
    func forceStop() {
        logger.append(event: TBLogEventStateAction(action: "force_stop", currentState: currentState.rawValue))
        
        stopTimer()
        // Используем правильный способ установки состояния
        stateMachine <-! .startStop // Переведем в idle через событие
        delegate?.stateDidBecomeIdle()
    }
    
    // MARK: - Timer Management
    
    private func startTimer(duration: TimeInterval) throws {
        guard duration > 0 else {
            throw TimerError.invalidDuration
        }
        
        // Stop existing timer if any
        stopTimer()
        
        // Set finish time
        finishTime = Date().addingTimeInterval(duration)
        
        // Create new timer
        currentTimer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        
        guard let timer = currentTimer else {
            throw TimerError.timerCreationFailed
        }
        
        // Configure timer
        timer.schedule(
            deadline: .now(),
            repeating: .seconds(Int(AppConstants.Timer.timerTickInterval)),
            leeway: AppConstants.Timer.timerLeeway
        )
        
        timer.setEventHandler { [weak self] in
            self?.onTimerTick()
        }
        
        timer.setCancelHandler { [weak self] in
            self?.onTimerCancel()
        }
        
        // Start timer
        timer.resume()
        
        logger.append(event: TBLogEventTimerStarted(duration: duration, state: currentState.rawValue))
    }
    
    private func stopTimer() {
        currentTimer?.cancel()
        currentTimer = nil
        finishTime = nil
    }
    
    // MARK: - Timer Events
    
    private func onTimerTick() {
        guard let finishTime = finishTime else { return }
        
        let timeLeft = finishTime.timeIntervalSince(Date())
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update delegate with current time
            self.delegate?.stateDidUpdateTime(timeLeft: max(0, timeLeft))
            
            // Check if timer finished
            if timeLeft <= 0 {
                self.handleTimerCompletion(overrun: timeLeft)
            }
        }
    }
    
    private func handleTimerCompletion(overrun: TimeInterval) {
        // Handle overrun protection
        if overrun < AppConstants.Timer.overrunLimit {
            logger.append(event: TBLogEventTimerOverrun(overrun: abs(overrun)))
            
            // Force stop if overrun is too much (system was sleeping)
            // Используем события state machine для перехода в idle
            stateMachine <-! .startStop
        } else {
            // Normal completion
            stateMachine <-! .timerFired
        }
    }
    
    private func onTimerCancel() {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.stateDidUpdateTime(timeLeft: 0)
        }
    }
    
    // MARK: - State Handlers
    
    private func onWorkStart(context: TBStateMachine.Context) {
        do {
            let duration = PomodoroConfigurationManager.shared.getWorkDurationInSeconds()
            try startTimer(duration: duration)
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.stateDidStartWork()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.stateDidEncounterError(error)
            }
        }
    }
    
    private func onWorkFinish(context: TBStateMachine.Context) {
        // Увеличиваем временный счетчик завершенных рабочих интервалов
        let currentCount = UserDefaults.standard.integer(forKey: "tempWorkIntervalsDone")
        UserDefaults.standard.set(currentCount + 1, forKey: "tempWorkIntervalsDone")
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.stateDidFinishWork()
        }
    }
    
    private func onWorkEnd(context: TBStateMachine.Context) {
        // Called when leaving work state (either to rest or idle)
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.stateDidEndWork()
        }
    }
    
    private func onRestStart(context: TBStateMachine.Context) {
        do {
            // Временная логика определения длинного перерыва
            // TODO: Заменить на SessionTracker когда создадим
            let workIntervalsDone = UserDefaults.standard.integer(forKey: "tempWorkIntervalsDone")
            let isLongBreak = workIntervalsDone >= PomodoroConfigurationManager.shared.workIntervalsInSet
            
            let duration: TimeInterval
            let breakType: BreakType
            
            if isLongBreak {
                duration = PomodoroConfigurationManager.shared.getLongBreakDurationInSeconds()
                breakType = .long
                // Сбрасываем счетчик после длинного перерыва
                UserDefaults.standard.set(0, forKey: "tempWorkIntervalsDone")
            } else {
                duration = PomodoroConfigurationManager.shared.getShortBreakDurationInSeconds()
                breakType = .short
            }
            
            try startTimer(duration: duration)
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.stateDidStartBreak(breakType)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.stateDidEncounterError(error)
            }
        }
    }
    
    private func onRestFinish(context: TBStateMachine.Context) {
        let wasSkipped = context.event == .skipRest
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.stateDidFinishBreak(wasSkipped: wasSkipped)
        }
    }
    
    private func onRestEnd(context: TBStateMachine.Context) {
        // Called when leaving rest state
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.stateDidEndBreak()
        }
    }
    
    private func onIdleStart(context: TBStateMachine.Context) {
        stopTimer()
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.stateDidBecomeIdle()
        }
    }
    
    // MARK: - Logging
    
    private func logStateTransition(context: TBStateMachine.Context) {
        logger.append(event: TBLogEventTransition(fromContext: context))
    }
}

// MARK: - State Manager Delegate
protocol PomodoroStateDelegate: AnyObject {
    func stateDidStartWork()
    func stateDidFinishWork()
    func stateDidEndWork()
    func stateDidStartBreak(_ type: BreakType)
    func stateDidFinishBreak(wasSkipped: Bool)
    func stateDidEndBreak()
    func stateDidBecomeIdle()
    func stateDidUpdateTime(timeLeft: TimeInterval)
    func stateDidEncounterError(_ error: Error)
}

// MARK: - Break Type
enum BreakType {
    case short
    case long
    
    var displayName: String {
        switch self {
        case .short:
            return NSLocalizedString("Short Break", comment: "Short break")
        case .long:
            return NSLocalizedString("Long Break", comment: "Long break")
        }
    }
}

// MARK: - State Logging Events
class TBLogEventStateManagerInitialized: TBLogEvent {
    let type = "state_manager_initialized"
    let timestamp = Date()
}

class TBLogEventStateAction: TBLogEvent {
    let type = "state_action"
    let timestamp = Date()
    let action: String
    let currentState: String
    
    init(action: String, currentState: String) {
        self.action = action
        self.currentState = currentState
    }
}

class TBLogEventTimerStarted: TBLogEvent {
    let type = "timer_started"
    let timestamp = Date()
    let duration: TimeInterval
    let state: String
    
    init(duration: TimeInterval, state: String) {
        self.duration = duration
        self.state = state
    }
}

class TBLogEventTimerOverrun: TBLogEvent {
    let type = "timer_overrun"
    let timestamp = Date()
    let overrun: TimeInterval
    
    init(overrun: TimeInterval) {
        self.overrun = overrun
    }
}

// MARK: - Extensions
extension TBStateMachineStates {
    var rawValue: String {
        switch self {
        case .idle: return "idle"
        case .work: return "work"
        case .rest: return "rest"
        }
    }
}
