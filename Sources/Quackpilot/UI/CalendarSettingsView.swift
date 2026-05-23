import AppKit
import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var status: CalendarAuthorizationStatus = .notDetermined
    @State private var calendars: [CalendarMetadata] = []
    @State private var refreshTick = 0   // bumped to trigger re-read after permission change

    /// Common offset chips. Anything custom can be added via the +/- in the row.
    private let offsetChoices: [Int] = [30, 15, 10, 5, 2, 1, 0]

    var body: some View {
        GroupBox("Calendar") {
            VStack(alignment: .leading, spacing: 10) {
                accessRow
                if status == .fullAccess {
                    Toggle("Enable calendar reminders", isOn: $settings.calendarEnabled)
                    calendarPicker
                    offsetPicker
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear { refresh() }
        .task(id: refreshTick) { await reloadCalendars() }
    }

    // MARK: - Access row

    private var accessRow: some View {
        HStack(spacing: 8) {
            Text("Access:")
            statusLabel
            Spacer()
            switch status {
            case .notDetermined:
                Button("Request Access") {
                    Task {
                        let granted = await calendarService?.requestAccess() ?? false
                        refresh()
                        if granted, settings.selectedCalendarIdentifiers.isEmpty {
                            // First grant: default to watching every calendar.
                            await reloadCalendars()
                            settings.selectedCalendarIdentifiers = Set(calendars.map(\.id))
                        }
                    }
                }
            case .denied, .restricted:
                Button("Open System Settings…") { openSystemPrivacySettings() }
            case .fullAccess:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .fullAccess:    Text("● Granted").foregroundStyle(.green)
        case .denied:        Text("● Denied").foregroundStyle(.red)
        case .restricted:    Text("● Restricted").foregroundStyle(.red)
        case .notDetermined: Text("● Not Determined").foregroundStyle(.secondary)
        }
    }

    // MARK: - Calendars

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendars").font(.subheadline).foregroundStyle(.secondary)
            if calendars.isEmpty {
                Text("No calendars found in Calendar.app.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(calendars) { cal in
                    HStack(spacing: 8) {
                        Toggle("", isOn: binding(for: cal))
                            .labelsHidden().toggleStyle(.checkbox)
                        Circle()
                            .fill(Color(cal.color))
                            .frame(width: 9, height: 9)
                        Text(cal.displayName).font(.body)
                        Spacer()
                    }
                }
            }
        }
    }

    private func binding(for cal: CalendarMetadata) -> Binding<Bool> {
        Binding(
            get: { settings.selectedCalendarIdentifiers.contains(cal.id) },
            set: { isOn in
                if isOn { settings.selectedCalendarIdentifiers.insert(cal.id) }
                else    { settings.selectedCalendarIdentifiers.remove(cal.id) }
            }
        )
    }

    // MARK: - Offsets

    private var offsetPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Alert me before each meeting").font(.subheadline).foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(offsetChoices, id: \.self) { minutes in
                    chip(for: minutes)
                }
            }
            Text("Tip: 0 = right at the meeting start.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func chip(for minutes: Int) -> some View {
        let isOn = settings.alertOffsetsMinutes.contains(minutes)
        return Button(action: { toggleOffset(minutes) }) {
            Text(minutes == 0 ? "At start" : "\(minutes) min")
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(isOn ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isOn ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func toggleOffset(_ m: Int) {
        var current = Set(settings.alertOffsetsMinutes)
        if current.contains(m) { current.remove(m) } else { current.insert(m) }
        settings.alertOffsetsMinutes = current.sorted(by: >)
    }

    // MARK: - Refresh

    private var calendarService: CalendarService? {
        (NSApp.delegate as? AppDelegate)?.calendarService
    }

    private func refresh() {
        status = calendarService?.authorizationStatus ?? .notDetermined
        refreshTick &+= 1
    }

    private func reloadCalendars() async {
        guard let svc = calendarService, status == .fullAccess else {
            calendars = []
            return
        }
        calendars = await svc.availableCalendars()
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private func openSystemPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Minimal flow layout for the offset chips. Lays out children left-to-right,
/// wrapping when they don't fit on the current row.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
