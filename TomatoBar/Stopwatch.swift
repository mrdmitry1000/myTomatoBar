//
//  Stopwatch.swift
//  myTomatoBar
//
//  Created by Dmitriy Moiseev on 12.09.2025.
//

import Foundation

class Stopwatch: TimerProtocol {
    static let shared = Stopwatch()
    
    // MARK: - Private Properties
    private var timer: Foundation.Timer?
    private var startTime: Date?
    private var elapsedTime: TimeInterval = 0
    private var isPaused = false
    
    private init() {}
    
    // MARK: - TimerProtocol Implementation
    
    var isRunning: Bool {
        return timer != nil && !isPaused
    }
    
    var currentTime: TimeInterval {
        guard let startTime = startTime else { return elapsedTime }
        return elapsedTime + Date().timeIntervalSince(startTime)
    }
    
    var displayText: String {
        return formatTime(currentTime)
    }
    
    func start() {
        if isPaused {
            // Возобновление после паузы
            startTime = Date()
            isPaused = false
        } else if timer == nil {
            // Новый старт
            startTime = Date()
            elapsedTime = 0
        }
        
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        
        // Убрали логирование
        NotificationCenter.default.post(name: .timerStateChanged, object: self)
        NotificationCenter.default.post(name: .stopwatchStarted, object: self)
    }
    
    func pause() {
        guard let startTime = startTime else { return }
        
        elapsedTime += Date().timeIntervalSince(startTime)
        timer?.invalidate()
        timer = nil
        isPaused = true
        self.startTime = nil
        
        // Убрали логирование
        NotificationCenter.default.post(name: .timerStateChanged, object: self)
    }
    
    func stop() {
        let finalTime = currentTime
        
        timer?.invalidate()
        timer = nil
        startTime = nil
        elapsedTime = 0
        isPaused = false
        
        // Убрали логирование
        NotificationCenter.default.post(name: .timerStateChanged, object: self)
        NotificationCenter.default.post(name: .stopwatchStopped, object: finalTime)
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        elapsedTime = 0
        isPaused = false
        
        // Отправляем уведомления
        NotificationCenter.default.post(name: .timerStateChanged, object: self)
        NotificationCenter.default.post(name: .timerUpdated, object: self)
    }
    
    // MARK: - Private Methods
    
    private func timerTick() {
        NotificationCenter.default.post(name: .timerUpdated, object: self)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            // Формат: 1:23:45
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            // Формат: 23:45
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Public Helpers
    
    /// Получить текущее время в формате для экспорта
    func getFormattedCurrentTime() -> String {
        let time = currentTime
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Получить детальную статистику
    func getDetailedStats() -> [String: Any] {
        return [
            "currentTime": currentTime,
            "isRunning": isRunning,
            "isPaused": isPaused,
            "formattedTime": displayText,
            "startTime": startTime?.timeIntervalSince1970 ?? 0
        ]
    }
}
