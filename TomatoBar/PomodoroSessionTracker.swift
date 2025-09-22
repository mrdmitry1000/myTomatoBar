//
//  PomodoroSessionTracker.swift
//  myTomatoBar
//
//  Created by Assistant on [Date]
//

import Foundation
import SwiftUI

// MARK: - Session Tracker
class PomodoroSessionTracker: ObservableObject {
    static let shared = PomodoroSessionTracker()
    
    // MARK: - Published Properties
    @Published private(set) var currentWorkInterval: Int = 0
    @Published private(set) var completedSessions: [PomodoroSession] = []
    @Published private(set) var currentSession: PomodoroSession?
    @Published private(set) var todayStats: PomodoroStats = PomodoroStats()
    
    weak var delegate: PomodoroSessionDelegate?
    
    // MARK: - Private Properties
    private let sessionsKey = "PomodoroSessions"
    private let currentIntervalKey = "CurrentWorkInterval"
    private let lastResetDateKey = "LastStatsResetDate"
    
    // MARK: - Initialization
    private init() {
        loadSavedData()
        resetDailyStatsIfNeeded()
        logger.append(event: TBLogEventSessionTrackerInitialized())
    }
    
    // MARK: - Session Management
    
    /// Начать новую рабочую сессию
    func startWorkSession() {
        guard currentSession == nil else {
            logger.append(event: TBLogEventSessionError(error: "Work session already active"))
            return
        }
        
        let session = PomodoroSession(
            type: .work,
            startTime: Date(),
            expectedDuration: PomodoroConfigurationManager.shared.getWorkDurationInSeconds()
        )
        
        currentSession = session
        delegate?.sessionDidStart(session)
        
        logger.append(event: TBLogEventSessionStarted(
            sessionType: session.type.rawValue,
            expectedDuration: session.expectedDuration
        ))
    }
    
    /// Начать сессию отдыха
    func startBreakSession(type: BreakType) {
        guard currentSession == nil else {
            logger.append(event: TBLogEventSessionError(error: "Break session already active"))
            return
        }
        
        let sessionType: PomodoroSession.SessionType = type == .long ? .longBreak : .shortBreak
        let duration = type == .long ?
            PomodoroConfigurationManager.shared.getLongBreakDurationInSeconds() :
            PomodoroConfigurationManager.shared.getShortBreakDurationInSeconds()
        
        let session = PomodoroSession(
            type: sessionType,
            startTime: Date(),
            expectedDuration: duration
        )
        
        currentSession = session
        delegate?.sessionDidStart(session)
        
        logger.append(event: TBLogEventSessionStarted(
            sessionType: session.type.rawValue,
            expectedDuration: session.expectedDuration
        ))
    }
    
    /// Завершить текущую сессию как успешную
    func completeCurrentSession() {
        guard let session = currentSession else {
            logger.append(event: TBLogEventSessionError(error: "No active session to complete"))
            return
        }
        
        session.endTime = Date()
        session.isCompleted = true
        completedSessions.append(session)
        
        // Обновляем счетчик рабочих интервалов
        if session.type == .work {
            currentWorkInterval += 1
            savePersistentData()
        }
        
        // Обновляем статистику
        updateTodayStats()
        
        delegate?.sessionDidComplete(session)
        currentSession = nil
        
        logger.append(event: TBLogEventSessionCompleted(
            sessionType: session.type.rawValue,
            actualDuration: session.actualDuration,
            completionPercentage: session.completionPercentage
        ))
    }
    
    /// Отменить текущую сессию
    func cancelCurrentSession() {
        guard let session = currentSession else {
            logger.append(event: TBLogEventSessionError(error: "No active session to cancel"))
            return
        }
        
        session.endTime = Date()
        session.isCancelled = true
        completedSessions.append(session)
        
        updateTodayStats()
        
        delegate?.sessionDidCancel(session)
        currentSession = nil
        
        logger.append(event: TBLogEventSessionCancelled(
            sessionType: session.type.rawValue,
            actualDuration: session.actualDuration
        ))
    }
    
    /// Определить нужен ли длинный перерыв
    func shouldTakeLongBreak() -> Bool {
        let config = PomodoroConfigurationManager.shared
        return currentWorkInterval >= config.workIntervalsInSet
    }
    
    /// Сбросить цикл (после длинного перерыва)
    func resetCycle() {
        currentWorkInterval = 0
        savePersistentData()
        
        logger.append(event: TBLogEventCycleReset())
    }
    
    // MARK: - Statistics
    
    /// Получить статистику за сегодня
    func getTodayStats() -> PomodoroStats {
        return todayStats
    }
    
    /// Получить статистику за период
    func getStatsForPeriod(from startDate: Date, to endDate: Date) -> PomodoroStats {
        let periodSessions = completedSessions.filter { session in
            guard let endTime = session.endTime else { return false }
            return endTime >= startDate && endTime <= endDate
        }
        
        return calculateStats(for: periodSessions)
    }
    
    /// Получить статистику за неделю
    func getWeekStats() -> PomodoroStats {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return getStatsForPeriod(from: weekAgo, to: now)
    }
    
    /// Получить все сессии за сегодня
    func getTodaySessions() -> [PomodoroSession] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return completedSessions.filter { session in
            guard let endTime = session.endTime else { return false }
            return endTime >= today && endTime < tomorrow
        }
    }
    
    // MARK: - Private Methods
    
    private func updateTodayStats() {
        let todaySessions = getTodaySessions()
        todayStats = calculateStats(for: todaySessions)
    }
    
    private func calculateStats(for sessions: [PomodoroSession]) -> PomodoroStats {
        let workSessions = sessions.filter { $0.type == .work }
        let breakSessions = sessions.filter { $0.type != .work }
        
        let completedWorkSessions = workSessions.filter { $0.isCompleted }
        let totalFocusTime = workSessions.reduce(0) { $0 + $1.actualDuration }
        let totalBreakTime = breakSessions.reduce(0) { $0 + $1.actualDuration }
        
        return PomodoroStats(
            completedWorkSessions: completedWorkSessions.count,
            totalWorkSessions: workSessions.count,
            totalFocusTime: totalFocusTime,
            totalBreakTime: totalBreakTime,
            averageSessionDuration: workSessions.isEmpty ? 0 : totalFocusTime / Double(workSessions.count),
            completionRate: workSessions.isEmpty ? 0 : Double(completedWorkSessions.count) / Double(workSessions.count)
        )
    }
    
    private func resetDailyStatsIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date {
            let lastResetDay = calendar.startOfDay(for: lastResetDate)
            
            if today > lastResetDay {
                // Новый день - обнуляем статистику
                todayStats = PomodoroStats()
                UserDefaults.standard.set(today, forKey: lastResetDateKey)
            }
        } else {
            // Первый запуск
            UserDefaults.standard.set(today, forKey: lastResetDateKey)
        }
    }
    
    // MARK: - Persistence
    
    private func loadSavedData() {
        // Загружаем текущий интервал
        currentWorkInterval = UserDefaults.standard.integer(forKey: currentIntervalKey)
        
        // Загружаем сессии
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let sessions = try? JSONDecoder().decode([PomodoroSession].self, from: data) {
            completedSessions = sessions
        }
        
        updateTodayStats()
    }
    
    private func savePersistentData() {
        // Сохраняем текущий интервал
        UserDefaults.standard.set(currentWorkInterval, forKey: currentIntervalKey)
        
        // Сохраняем сессии (только последние 100 для экономии места)
        let sessionsToSave = Array(completedSessions.suffix(100))
        if let data = try? JSONEncoder().encode(sessionsToSave) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
    
    /// Очистить все данные (для отладки)
    func clearAllData() {
        completedSessions.removeAll()
        currentWorkInterval = 0
        currentSession = nil
        todayStats = PomodoroStats()
        
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: currentIntervalKey)
        UserDefaults.standard.removeObject(forKey: lastResetDateKey)
        
        logger.append(event: TBLogEventSessionDataCleared())
    }
}

// MARK: - Session Model
class PomodoroSession: ObservableObject, Identifiable, Codable {
    let id = UUID()
    let type: SessionType
    let startTime: Date
    let expectedDuration: TimeInterval
    
    @Published var endTime: Date?
    @Published var isCompleted = false
    @Published var isCancelled = false
    
    enum SessionType: String, Codable, CaseIterable {
        case work = "work"
        case shortBreak = "short_break"
        case longBreak = "long_break"
        
        var displayName: String {
            switch self {
            case .work:
                return NSLocalizedString("Work", comment: "Work session")
            case .shortBreak:
                return NSLocalizedString("Short Break", comment: "Short break session")
            case .longBreak:
                return NSLocalizedString("Long Break", comment: "Long break session")
            }
        }
        
        var icon: String {
            switch self {
            case .work: return "🍅"
            case .shortBreak: return "☕️"
            case .longBreak: return "🌴"
            }
        }
    }
    
    init(type: SessionType, startTime: Date, expectedDuration: TimeInterval) {
        self.type = type
        self.startTime = startTime
        self.expectedDuration = expectedDuration
    }
    
    // MARK: - Codable
    enum CodingKeys: CodingKey {
        case id, type, startTime, expectedDuration, endTime, isCompleted, isCancelled
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decode(SessionType.self, forKey: .type)
        startTime = try container.decode(Date.self, forKey: .startTime)
        expectedDuration = try container.decode(TimeInterval.self, forKey: .expectedDuration)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        isCancelled = try container.decode(Bool.self, forKey: .isCancelled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(expectedDuration, forKey: .expectedDuration)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(isCancelled, forKey: .isCancelled)
    }
    
    // MARK: - Computed Properties
    
    var actualDuration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var completionPercentage: Double {
        let actual = actualDuration
        return min(actual / expectedDuration, 1.0)
    }
    
    var isActive: Bool {
        return endTime == nil && !isCancelled
    }
}

// MARK: - Statistics Model
struct PomodoroStats {
    let completedWorkSessions: Int
    let totalWorkSessions: Int
    let totalFocusTime: TimeInterval
    let totalBreakTime: TimeInterval
    let averageSessionDuration: TimeInterval
    let completionRate: Double // 0.0 - 1.0
    
    init(
        completedWorkSessions: Int = 0,
        totalWorkSessions: Int = 0,
        totalFocusTime: TimeInterval = 0,
        totalBreakTime: TimeInterval = 0,
        averageSessionDuration: TimeInterval = 0,
        completionRate: Double = 0
    ) {
        self.completedWorkSessions = completedWorkSessions
        self.totalWorkSessions = totalWorkSessions
        self.totalFocusTime = totalFocusTime
        self.totalBreakTime = totalBreakTime
        self.averageSessionDuration = averageSessionDuration
        self.completionRate = completionRate
    }
}

// MARK: - Session Delegate
protocol PomodoroSessionDelegate: AnyObject {
    func sessionDidStart(_ session: PomodoroSession)
    func sessionDidComplete(_ session: PomodoroSession)
    func sessionDidCancel(_ session: PomodoroSession)
}

// MARK: - Session Logging Events
class TBLogEventSessionTrackerInitialized: TBLogEvent {
    let type = "session_tracker_initialized"
    let timestamp = Date()
}

class TBLogEventSessionStarted: TBLogEvent {
    let type = "session_started"
    let timestamp = Date()
    let sessionType: String
    let expectedDuration: TimeInterval
    
    init(sessionType: String, expectedDuration: TimeInterval) {
        self.sessionType = sessionType
        self.expectedDuration = expectedDuration
    }
}

class TBLogEventSessionCompleted: TBLogEvent {
    let type = "session_completed"
    let timestamp = Date()
    let sessionType: String
    let actualDuration: TimeInterval
    let completionPercentage: Double
    
    init(sessionType: String, actualDuration: TimeInterval, completionPercentage: Double) {
        self.sessionType = sessionType
        self.actualDuration = actualDuration
        self.completionPercentage = completionPercentage
    }
}

class TBLogEventSessionCancelled: TBLogEvent {
    let type = "session_cancelled"
    let timestamp = Date()
    let sessionType: String
    let actualDuration: TimeInterval
    
    init(sessionType: String, actualDuration: TimeInterval) {
        self.sessionType = sessionType
        self.actualDuration = actualDuration
    }
}

class TBLogEventSessionError: TBLogEvent {
    let type = "session_error"
    let timestamp = Date()
    let error: String
    
    init(error: String) {
        self.error = error
    }
}

class TBLogEventCycleReset: TBLogEvent {
    let type = "cycle_reset"
    let timestamp = Date()
}

class TBLogEventSessionDataCleared: TBLogEvent {
    let type = "session_data_cleared"
    let timestamp = Date()
}
