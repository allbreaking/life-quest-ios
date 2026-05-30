
//
//  RoutineEditorView.swift
//  lifequest-ios
//

import SwiftUI

struct RoutineEditorView: View {
    @Environment(RoutineStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existingRoutine: Routine?
    let onSave: (Routine) -> Void

    // Form state
    @State private var name: String = ""
    @State private var subtasks: [String] = []
    @State private var newSubtaskText: String = ""
    @State private var hasScheduledTime: Bool = false
    @State private var scheduledTime: Date = defaultTime()
    @State private var locationId: UUID? = nil
    @State private var recurrence: RecurrenceType = .daily
    @State private var selectedDays: Set<Int> = []
    @State private var selectedDates: Set<Int> = []
    @State private var reminderInterval: Int = 5

    @State private var showingNameError = false

    private static func defaultTime() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 8
        comps.minute = 0
        return cal.date(from: comps) ?? Date()
    }

    init(routine: Routine?, onSave: @escaping (Routine) -> Void) {
        self.existingRoutine = routine
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Name
                Section("Name") {
                    TextField("Routine name", text: $name)
                    if showingNameError {
                        Text("Name is required")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                // MARK: Subtasks
                Section {
                    ForEach(Array(subtasks.enumerated()), id: \.offset) { idx, task in
                        Text(task)
                    }
                    .onDelete { offsets in
                        subtasks.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        subtasks.move(fromOffsets: from, toOffset: to)
                    }

                    HStack {
                        TextField("Add subtask", text: $newSubtaskText)
                        Button("Add") {
                            let trimmed = newSubtaskText.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            subtasks.append(trimmed)
                            newSubtaskText = ""
                        }
                        .disabled(newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    HStack {
                        Text("Subtasks")
                        Spacer()
                        EditButton()
                            .font(.caption)
                    }
                }

                // MARK: Scheduled Time
                Section("Scheduled Time") {
                    Toggle("Set scheduled time", isOn: $hasScheduledTime)
                    if hasScheduledTime {
                        DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }
                }

                // MARK: Location
                Section("Location") {
                    Picker("Location", selection: $locationId) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(store.locations) { loc in
                            Text(loc.name).tag(Optional(loc.id))
                        }
                    }
                }

                // MARK: Recurrence
                Section("Recurrence") {
                    Picker("Recurrence", selection: $recurrence) {
                        ForEach(RecurrenceType.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Day Selection (Weekly / Biweekly)
                if recurrence == .weekly || recurrence == .biweekly {
                    Section("Days of Week") {
                        let days = [(1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")]
                        ForEach(days, id: \.0) { (num, label) in
                            Toggle(label, isOn: Binding(
                                get: { selectedDays.contains(num) },
                                set: { on in
                                    if on { selectedDays.insert(num) } else { selectedDays.remove(num) }
                                }
                            ))
                        }
                    }
                }

                // MARK: Date Selection (Monthly)
                if recurrence == .monthly {
                    Section("Days of Month") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(1...31, id: \.self) { day in
                                Button {
                                    if selectedDates.contains(day) {
                                        selectedDates.remove(day)
                                    } else {
                                        selectedDates.insert(day)
                                    }
                                } label: {
                                    Text("\(day)")
                                        .frame(width: 36, height: 36)
                                        .background(selectedDates.contains(day) ? Color.accentColor : Color(.systemGray5))
                                        .foregroundStyle(selectedDates.contains(day) ? .white : .primary)
                                        .clipShape(Circle())
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Reminder Interval
                Section("Reminder Interval") {
                    Picker("Remind every", selection: $reminderInterval) {
                        ForEach([1, 3, 5, 10, 15], id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                }
            }
            .navigationTitle(existingRoutine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveRoutine() }
                }
            }
            .onAppear { populateFields() }
        }
    }

    // MARK: - Helpers

    private func populateFields() {
        guard let r = existingRoutine else { return }
        name = r.name
        subtasks = r.subtasks
        hasScheduledTime = r.hasScheduledTime
        if let h = r.scheduledHour, let m = r.scheduledMinute {
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.hour = h
            comps.minute = m
            scheduledTime = cal.date(from: comps) ?? RoutineEditorView.defaultTime()
        }
        locationId = r.locationId
        recurrence = r.recurrence
        selectedDays = Set(r.selectedDays)
        selectedDates = Set(r.selectedDates)
        reminderInterval = r.reminderIntervalMinutes
    }

    private func saveRoutine() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showingNameError = true
            return
        }
        showingNameError = false

        let cal = Calendar.current
        var h: Int? = nil
        var m: Int? = nil
        if hasScheduledTime {
            h = cal.component(.hour, from: scheduledTime)
            m = cal.component(.minute, from: scheduledTime)
        }

        let routine = Routine(
            id: existingRoutine?.id ?? UUID(),
            name: trimmed,
            subtasks: subtasks,
            scheduledHour: h,
            scheduledMinute: m,
            locationId: locationId,
            recurrence: recurrence,
            selectedDays: Array(selectedDays),
            selectedDates: Array(selectedDates),
            completionStatus: existingRoutine?.completionStatus ?? false,
            completedSubtaskIndices: existingRoutine?.completedSubtaskIndices ?? [],
            createdAt: existingRoutine?.createdAt ?? Date(),
            updatedAt: Date(),
            reminderIntervalMinutes: reminderInterval
        )

        onSave(routine)
        dismiss()
    }
}

#Preview {
    RoutineEditorView(routine: nil) { _ in }
        .environment(RoutineStore())
}
