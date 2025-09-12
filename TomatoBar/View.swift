import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

// MARK: - Timer Mode Selection
private struct TimerModeView: View {
    @StateObject private var timerManager = TimerManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("TimerMode.title", comment: "Timer Mode"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Picker("Timer Mode", selection: Binding(
                get: { timerManager.currentMode },
                set: { timerManager.switchMode(to: $0) }
            )) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Text(mode.localizedDisplayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }
}

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
}

private struct IntervalsView: View {
    @EnvironmentObject var timer: TBTimer
    private var minStr = NSLocalizedString("IntervalsView.min", comment: "min")

    var body: some View {
        VStack {
            Stepper(value: $timer.workIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalLength.label",
                                           comment: "Work interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.workIntervalLength))
                }
            }
            Stepper(value: $timer.shortRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.shortRestIntervalLength.label",
                                           comment: "Short rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.shortRestIntervalLength))
                }
            }
            Stepper(value: $timer.longRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.longRestIntervalLength.label",
                                           comment: "Long rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.longRestIntervalLength))
                }
            }
            .help(NSLocalizedString("IntervalsView.longRestIntervalLength.help",
                                    comment: "Long rest interval hint"))
            Stepper(value: $timer.workIntervalsInSet, in: 1 ... 10) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalsInSet.label",
                                           comment: "Work intervals in a set label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.workIntervalsInSet)")
                }
            }
            .help(NSLocalizedString("IntervalsView.workIntervalsInSet.help",
                                    comment: "Work intervals in set hint"))
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var timer: TBTimer
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $timer.stopAfterBreak) {
                Text(NSLocalizedString("SettingsView.stopAfterBreak.label",
                                       comment: "Stop after break label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $timer.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: timer.showTimerInMenuBar) { _ in
                    timer.updateTimeLeft()
                }
            Toggle(isOn: $launchAtLogin.isEnabled) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                       comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct VolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        Slider(value: $volume, in: 0...2) {
            Text(String(format: "%.1f", volume))
        }.gesture(TapGesture(count: 2).onEnded({
            volume = 1.0
        }))
    }
}

private struct SoundsView: View {
    @EnvironmentObject var player: TBPlayer

    private var columns = [
        GridItem(.flexible()),
        GridItem(.fixed(110))
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("SoundsView.isWindupEnabled.label",
                                   comment: "Windup label"))
            VolumeSlider(volume: $player.windupVolume)
            Text(NSLocalizedString("SoundsView.isDingEnabled.label",
                                   comment: "Ding label"))
            VolumeSlider(volume: $player.dingVolume)
            Text(NSLocalizedString("SoundsView.isTickingEnabled.label",
                                   comment: "Ticking label"))
            VolumeSlider(volume: $player.tickingVolume)
        }.padding(4)
        Spacer().frame(minHeight: 0)
    }
}

private enum ChildView {
    case timerMode    // Новый случай
    case intervals
    case settings
    case sounds
}

struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer.shared
    @StateObject private var timerManager = TimerManager.shared
    @State private var buttonHovered = false
    @State private var activeChildView = ChildView.timerMode

    private var startLabel = NSLocalizedString("TBPopoverView.start.label", comment: "Start label")
    private var stopLabel = NSLocalizedString("TBPopoverView.stop.label", comment: "Stop label")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Главная кнопка старт/стоп
            Button {
                handleStartStopAction()
                TBStatusItem.shared.closePopover(nil)
            } label: {
                Text(getButtonText())
                    .foregroundColor(Color.white)
                    .font(.system(.body).monospacedDigit())
                    .frame(maxWidth: .infinity)
            }
            .onHover { over in
                buttonHovered = over
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            // Picker для вкладок
            Picker("", selection: $activeChildView) {
                Text("🍅⏱️").tag(ChildView.timerMode)
                Text(NSLocalizedString("TBPopoverView.intervals.label",
                                       comment: "Intervals label")).tag(ChildView.intervals)
                Text(NSLocalizedString("TBPopoverView.settings.label",
                                       comment: "Settings label")).tag(ChildView.settings)
                Text(NSLocalizedString("TBPopoverView.sounds.label",
                                       comment: "Sounds label")).tag(ChildView.sounds)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .pickerStyle(.segmented)

            // Адаптивный контент без GroupBox для экономии места
            contentForActiveTab()

            // Нижнее меню
            VStack(spacing: 4) {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                } label: {
                    HStack {
                        Text(NSLocalizedString("TBPopoverView.about.label", comment: "About label"))
                        Spacer()
                        Text("⌘ A").foregroundColor(Color.gray)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("a")
                
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    HStack {
                        Text(NSLocalizedString("TBPopoverView.quit.label", comment: "Quit label"))
                        Spacer()
                        Text("⌘ Q").foregroundColor(Color.gray)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
        }
        .frame(width: 240) // Только ширина фиксирована
        .padding(12)
        .fixedSize(horizontal: false, vertical: true) // Ключевая строка для адаптивной высоты
    }
    
    // MARK: - Content Methods
    
    @ViewBuilder
    private func contentForActiveTab() -> some View {
        switch activeChildView {
        case .timerMode:
            TimerModeView()
                .padding(.vertical, 4)
                
        case .intervals:
            if timerManager.currentMode == .pomodoro {
                IntervalsView()
                    .environmentObject(timer)
                    .padding(.vertical, 4)
            } else {
                StopwatchInfoView()
                    .padding(.vertical, 4)
            }
            
        case .settings:
            SettingsView()
                .environmentObject(timer)
                .padding(.vertical, 4)
                
        case .sounds:
            if timerManager.currentMode == .pomodoro {
                SoundsView()
                    .environmentObject(timer.player)
                    .padding(.vertical, 4)
            } else {
                VStack {
                    Text("Sound settings are available only for Pomodoro mode")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
    }
    
    // Ваши helper методы остаются без изменений...
    private func handleStartStopAction() {
        switch timerManager.currentMode {
        case .pomodoro:
            timer.startStop()
        case .stopwatch:
            if timerManager.activeTimer.isRunning {
                timerManager.pauseActiveTimer()
            } else {
                timerManager.startActiveTimer()
            }
        }
    }
    
    private func getButtonText() -> String {
        switch timerManager.currentMode {
        case .pomodoro:
            return timer.timer != nil ?
                (buttonHovered ? stopLabel : timer.timeLeftString) :
                startLabel
        case .stopwatch:
            let stopwatch = timerManager.activeTimer
            if stopwatch.isRunning {
                return buttonHovered ?
                    NSLocalizedString("Stopwatch.pause", comment: "Pause") :
                    stopwatch.displayText
            } else {
                return stopwatch.currentTime > 0 ?
                    NSLocalizedString("Stopwatch.resume", comment: "Resume") :
                    NSLocalizedString("Stopwatch.start", comment: "Start")
            }
        }
    }
}

// MARK: - Stopwatch Info View
private struct StopwatchInfoView: View {
    @ObservedObject private var timerManager = TimerManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("TimerMode.stopwatch", comment: "Stopwatch"))
                    .font(.headline)
                Spacer()
                Text(timerManager.activeTimer.isRunning ?
                     NSLocalizedString("Stopwatch.running", comment: "Running") :
                     NSLocalizedString("Stopwatch.stopped", comment: "Stopped"))
                    .font(.caption)
                    .foregroundColor(timerManager.activeTimer.isRunning ? .green : .secondary)
            }
            
            if let stopwatch = timerManager.activeTimer as? Stopwatch {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Stopwatch.currentTime", comment: "Current Time:"))
                        Spacer()
                        Text(stopwatch.displayText)
                            .font(.system(.body).monospacedDigit())
                    }
                    
                    HStack {
                        Button(NSLocalizedString("Stopwatch.reset", comment: "Reset")) {
                            stopwatch.reset()
                        }
                        .disabled(stopwatch.currentTime == 0 && !stopwatch.isRunning)
                        
                        Spacer()
                        
                        if stopwatch.isRunning {
                            Button(NSLocalizedString("Stopwatch.pause", comment: "Pause")) {
                                stopwatch.pause()
                            }
                        } else {
                            Button(stopwatch.currentTime > 0 ?
                                   NSLocalizedString("Stopwatch.resume", comment: "Resume") :
                                   NSLocalizedString("Stopwatch.start", comment: "Start")) {
                                stopwatch.start()
                            }
                        }
                    }
                }
            }
            
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

