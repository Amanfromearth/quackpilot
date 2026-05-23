import SwiftUI

/// Form to create or edit a single CustomReminder. Used as a .sheet from the
/// settings panel.
struct CustomReminderFormView: View {
    /// The reminder being edited. If this is a NEW reminder it has a default id;
    /// the store treats add vs update by checking whether `id` already exists.
    @State private var draft: CustomReminder
    @State private var repeatKind: RepeatKind
    @State private var customMinutes: Int

    private let isNew: Bool
    let onSave: (CustomReminder) -> Void
    let onCancel: () -> Void

    /// Snapshot of the original schedule, captured at init time, so the save
    /// handler can detect a schedule change and reset `lastFiredAt`.
    private let originalSchedule: (firstFireAt: Date, repeatRule: RepeatRule)?

    init(existing: CustomReminder?, onSave: @escaping (CustomReminder) -> Void, onCancel: @escaping () -> Void) {
        let initial = existing ?? CustomReminder(
            title: "",
            urlString: "",
            firstFireAt: Date().addingTimeInterval(60),
            repeatRule: .once,
            enabled: true
        )
        let kind: RepeatKind
        let minutes: Int
        switch initial.repeatRule {
        case .once:                kind = .once;         minutes = 15
        case .everyMinutes(let m): kind = .everyMinutes; minutes = m
        case .hourly:              kind = .hourly;       minutes = 15
        case .daily:               kind = .daily;        minutes = 15
        case .weekly:              kind = .weekly;       minutes = 15
        }
        _draft = State(initialValue: initial)
        _repeatKind = State(initialValue: kind)
        _customMinutes = State(initialValue: minutes)
        self.isNew = (existing == nil)
        self.originalSchedule = existing.map { ($0.firstFireAt, $0.repeatRule) }
        self.onSave = onSave
        self.onCancel = onCancel
    }

    enum RepeatKind: String, CaseIterable, Identifiable {
        case once = "Once"
        case everyMinutes = "Every N minutes"
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "New Reminder" : "Edit Reminder").font(.title3).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledField("Title") {
                        TextField("e.g. Stand up & stretch", text: $draft.title)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField("URL (optional)") {
                        TextField("https://… opened when banner clicked", text: $draft.urlString)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            GroupBox("Schedule") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledField("First fire") {
                        DatePicker("", selection: $draft.firstFireAt,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    LabeledField("Repeat") {
                        Picker("", selection: $repeatKind) {
                            ForEach(RepeatKind.allCases) { k in
                                Text(k.rawValue).tag(k)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    if repeatKind == .everyMinutes {
                        LabeledField("Every") {
                            HStack {
                                Stepper(value: $customMinutes, in: 1...1440) {
                                    Text("\(customMinutes) min")
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }

            Toggle("Enabled", isOn: $draft.enabled)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    draft.repeatRule = composeRule()
                    // If the user changed the schedule (date/time or repeat rule),
                    // reset lastFiredAt so the new schedule actually fires.
                    // Without this, editing a .once reminder that already fired
                    // would silently never fire again.
                    if let original = originalSchedule,
                       original.firstFireAt != draft.firstFireAt || original.repeatRule != draft.repeatRule {
                        draft.lastFiredAt = nil
                    }
                    onSave(draft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func composeRule() -> RepeatRule {
        switch repeatKind {
        case .once:         return .once
        case .everyMinutes: return .everyMinutes(customMinutes)
        case .hourly:       return .hourly
        case .daily:        return .daily
        case .weekly:       return .weekly
        }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.secondary)
            content
        }
    }
}
