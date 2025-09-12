//
//  TimerManager.swift
//  myTomatoBar
//
//  Created by Dmitriy Moiseev on 12.09.2025.
//

import Foundation
import Combine

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentMode: TimerMode = .pomodoro {
        didSet {
            if oldValue != currentMode {
                saveCurrentMode()
            }
        }
    }
    
    @Published private(set) var isActiveTimerRunning: Bool = false
    @Published private(set) var activeTimerDisplayText: String = "25:00"
    
    // MARK: - Computed Properties
    
    var activeTimer: TimerProtocol {
        switch currentMode {
        case .pomodoro:
            return TBTimer.shared
        case .stopwatch:
            return Stopwatch.shared
        }
    }
    
    var currentModeDisplayName: String {
        return currentMode.displayName
    }
    
    var statusBarPrefix: String {
        return currentMode.statusBarPrefix
    }
    
    var statusBarText: String {
        return "\(statusBarPrefix) \(activeTimerDisplayText)"
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSavedMode()
        setupNotifications()
        updatePublishedProperties()
    }
    
    // MARK: - Public Methods
    
    func switchMode(to mode: TimerMode) {
        guard mode != currentMode else {
            return
        }
        
        // Останавливаем текущий таймер
        if activeTimer.isRunning {
            activeTimer.stop()
        }
        
        let oldMode = currentMode
        
        // Переключаем режим
        currentMode = mode
        
        // Обновляем опубликованные свойства
        updatePublishedProperties()
        
        // Уведомляем об изменении
        NotificationCenter.default.post(
            name: .timerModeChanged,
            object: self,
            userInfo: [
                "oldMode": oldMode,
                "newMode": mode
            ]
        )
    }
    
    func toggleMode() {
        let nextMode: TimerMode = currentMode == .pomodoro ? .stopwatch : .pomodoro
        switchMode(to: nextMode)
    }
    
    // MARK: - Timer Control Helpers
    
    func startActiveTimer() {
        activeTimer.start()
        updatePublishedProperties()
    }
    
    func pauseActiveTimer() {
        activeTimer.pause()
        updatePublishedProperties()
    }
    
    func stopActiveTimer() {
        activeTimer.stop()
        updatePublishedProperties()
    }
    
    func resetActiveTimer() {
        activeTimer.reset()
        updatePublishedProperties()
    }
    
    // MARK: - Private Methods
    
    private func updatePublishedProperties() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isActiveTimerRunning = self.activeTimer.isRunning
            self.activeTimerDisplayText = self.activeTimer.displayText
        }
    }
    
    // MARK: - Persistence
    
    private func saveCurrentMode() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: "CurrentTimerMode")
    }
    
    private func loadSavedMode() {
        guard let savedModeString = UserDefaults.standard.string(forKey: "CurrentTimerMode"),
              let savedMode = TimerMode(rawValue: savedModeString) else {
            return
        }
        
        currentMode = savedMode
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timerStateChanged),
            name: .timerStateChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timerUpdated),
            name: .timerUpdated,
            object: nil
        )
    }
    
    @objc private func timerStateChanged(_ notification: Notification) {
        updatePublishedProperties()
    }
    
    @objc private func timerUpdated(_ notification: Notification) {
        updatePublishedProperties()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Extensions for convenience

extension TimerManager {
    /// Получить все доступные режимы для UI
    var availableModes: [TimerMode] {
        return TimerMode.allCases
    }
    
    /// Проверить является ли режим текущим
    func isCurrentMode(_ mode: TimerMode) -> Bool {
        return currentMode == mode
    }
    
    /// Получить статистику текущего таймера
    func getCurrentTimerStats() -> [String: Any] {
        var stats: [String: Any] = [
            "mode": currentMode.rawValue,
            "isRunning": activeTimer.isRunning,
            "currentTime": activeTimer.currentTime,
            "displayText": activeTimer.displayText
        ]
        
        // Добавляем специфичную информацию для секундомера
        if currentMode == .stopwatch, let stopwatch = activeTimer as? Stopwatch {
            stats.merge(stopwatch.getDetailedStats()) { _, new in new }
        }
        
        return stats
    }
}

