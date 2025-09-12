//
//  NotificationName+Extensions.swift
//  myTomatoBar
//
//  Created by Dmitriy Moiseev on 12.09.2025.
//

import Foundation

extension Notification.Name {
    // Уведомления таймера
    static let timerUpdated = Notification.Name("TimerUpdated")
    static let timerStateChanged = Notification.Name("TimerStateChanged")
    static let timerModeChanged = Notification.Name("TimerModeChanged")
    
    // Уведомления для Pomodoro (если нужны дополнительные)
    static let pomodoroCompleted = Notification.Name("PomodoroCompleted")
    static let breakCompleted = Notification.Name("BreakCompleted")
    
    // Уведомления для секундомера
    static let stopwatchStarted = Notification.Name("StopwatchStarted")
    static let stopwatchStopped = Notification.Name("StopwatchStopped")
}
