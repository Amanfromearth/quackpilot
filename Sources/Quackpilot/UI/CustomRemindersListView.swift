import SwiftUI

/// List of user-defined reminders + an Add button. Add/Edit opens
/// CustomReminderFormView as a .sheet.
struct CustomRemindersListView: View {
    @ObservedObject var store: CustomRemindersStore = .shared

    @State private var showingAddSheet = false
    @State private var editingReminder: CustomReminder?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Custom Reminders").font(.headline)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            if store.reminders.isEmpty {
                Text("No custom reminders yet — add one to schedule the plane.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.reminders) { r in
                        row(for: r)
                        if r.id != store.reminders.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomReminderFormView(
                existing: nil,
                onSave: { reminder in
                    store.add(reminder)
                    showingAddSheet = false
                },
                onCancel: { showingAddSheet = false }
            )
        }
        .sheet(item: $editingReminder) { reminder in
            CustomReminderFormView(
                existing: reminder,
                onSave: { updated in
                    store.update(updated)
                    editingReminder = nil
                },
                onCancel: { editingReminder = nil }
            )
        }
    }

    @ViewBuilder
    private func row(for r: CustomReminder) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { r.enabled },
                set: { store.setEnabled(id: r.id, $0) }
            )).labelsHidden().toggleStyle(.switch).controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(r.title.isEmpty ? "(untitled)" : r.title)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle(for: r))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                editingReminder = r
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit")

            Button {
                store.delete(id: r.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .opacity(r.enabled ? 1 : 0.55)
    }

    private func subtitle(for r: CustomReminder) -> String {
        let dateStr = Self.formatter.string(from: r.firstFireAt)
        return "\(r.repeatRule.label) · first \(dateStr)"
    }
}
