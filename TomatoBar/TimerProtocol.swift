//
//  TimerProtocol.swift
//  TomatoBar
//

import Foundation

protocol TimerProtocol: AnyObject {
    var isRunning: Bool { get }
    var currentTime: TimeInterval { get }
    var displayText: String { get }
    
    func start()
    func pause()
    func stop()
    func reset()
}

enum TimerMode: String, CaseIterable {
    case pomodoro = "pomodoro"
    case stopwatch = "stopwatch"
    
    var displayName: String {
        switch self {
        case .pomodoro:
            return "🍅 Pomodoro Timer"
        case .stopwatch:
            return "⏱️ Stopwatch"
        }
    }
    
    // Добавляем локализованную версию
    var localizedDisplayName: String {
        switch self {
        case .pomodoro:
            return NSLocalizedString("TimerMode.pomodoro", comment: "Pomodoro Timer")
        case .stopwatch:
            return NSLocalizedString("TimerMode.stopwatch", comment: "Stopwatch")
        }
    }
    
    var menuIcon: String {
        switch self {
        case .pomodoro:
            return "🍅"
        case .stopwatch:
            return "⏱️"
        }
    }
    
    var statusBarPrefix: String {
        switch self {
        case .pomodoro:
            return "🍅"
        case .stopwatch:
            return "⏱️"
        }
    }
}
