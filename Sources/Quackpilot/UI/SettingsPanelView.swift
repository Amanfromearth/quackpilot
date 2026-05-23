import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var showingResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
        }
        .confirmationDialog(
            "Reset all settings to defaults?",
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Custom reminders and Launch-at-login are not affected.")
        }
    }

    @ViewBuilder
    private var content: some View {
            Text("Quackpilot Settings").font(.title2).bold()

            CustomRemindersListView()

            CalendarSettingsView()

            GroupBox("Actions") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Spawn Plane (placeholder)") { action(.spawn) }
                    Button("Trigger Random Reminder") { action(.trigger) }
                    Button("Test Meeting Event") { action(.meeting) }
                    Button("Reload Assets") { action(.reload) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Size") {
                HStack {
                    Text("Plane + Banner")
                    Slider(value: $settings.displayScale, in: 0.2...1.5)
                    Text(String(format: "%.2f×", settings.displayScale)).monospacedDigit().frame(width: 60, alignment: .trailing)
                }
            }

            GroupBox("Speed") {
                HStack {
                    Text("Flight speed")
                    Slider(value: $settings.flightSpeed, in: 30...400)
                    Text(String(format: "%.0f px/s", settings.flightSpeed)).monospacedDigit().frame(width: 70, alignment: .trailing)
                }
            }

            GroupBox("Audio") {
                Toggle("Play plane.mp3 on spawn", isOn: $settings.audioEnabled)
            }

            GroupBox("Startup") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .disabled(!LaunchAtLogin.isAvailable)
                        .onChange(of: launchAtLogin) { newValue in
                            if !LaunchAtLogin.setEnabled(newValue) {
                                // Toggle failed; resync from system state.
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                        }
                    if !LaunchAtLogin.isAvailable {
                        Text("Run from Quackpilot.app (via ./build.sh) to enable this.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            GroupBox("Banner Wave") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Amplitude")
                        Slider(value: $settings.bannerAmplitude, in: 0...4)
                        Text(String(format: "%.2f", settings.bannerAmplitude)).monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                    HStack {
                        Text("Frequency")
                        Slider(value: $settings.bannerFrequency, in: 0.5...10)
                        Text(String(format: "%.2f", settings.bannerFrequency)).monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                    HStack {
                        Text("Phase step")
                        Slider(value: $settings.bannerPhaseStep, in: 0...0.6)
                        Text(String(format: "%.2f", settings.bannerPhaseStep)).monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
            }

            GroupBox("Advanced") {
                Toggle("Show Physics Bounds", isOn: $settings.showPhysicsBounds)
            }

            HStack {
                Button("Reset Settings to Defaults") {
                    showingResetConfirm = true
                }
                .foregroundColor(.red)
                Spacer()
            }
            .padding(.top, 4)

            Text("Hotkeys: ⌘⇧1 spawn  ⌘⇧2 trigger  ⌘⇧3 reload  ⌘⇧4 settings")
                .font(.caption).foregroundStyle(.secondary)
    }

    enum Action { case spawn, trigger, meeting, reload }
    private func action(_ a: Action) {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        switch a {
        case .spawn:   delegate.spawnPlaceholderPlane()
        case .trigger: delegate.triggerRandomReminder()
        case .meeting: delegate.dispatcher.fire(MockReminderCatalog.randomMeeting())
        case .reload:  delegate.reloadAssets()
        }
    }
}
