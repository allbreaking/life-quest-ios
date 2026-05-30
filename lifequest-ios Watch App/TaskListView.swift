
//
//  TaskListView.swift
//  lifequest-ios Watch App
//

import SwiftUI

// MARK: - Design Tokens

private extension Color {
    static let bgMain      = Color(red: 0.980, green: 0.973, blue: 0.961)
    static let bgCard      = Color(red: 0.949, green: 0.929, blue: 0.906)
    static let bgSubtask   = Color(red: 0.965, green: 0.949, blue: 0.929)
    static let apricot     = Color(red: 0.957, green: 0.518, blue: 0.373)
    static let sage        = Color(red: 0.784, green: 0.851, blue: 0.643)
    static let espresso    = Color(red: 0.227, green: 0.180, blue: 0.149)
    static let walnut      = Color(red: 0.361, green: 0.306, blue: 0.251)
    static let driftwood   = Color(red: 0.620, green: 0.557, blue: 0.494)
}

// MARK: - TaskListView

struct TaskListView: View {
    @Environment(RoutineStore.self) private var store
    private var sessionManager: WatchSessionManager { WatchSessionManager.shared }

    var body: some View {
        let sorted = store.todaysRoutines
        let incomplete = sorted.filter { !$0.completionStatus }
        let complete   = sorted.filter { $0.completionStatus }

        List {
            if sorted.isEmpty {
                Text("No routines today")
                    .foregroundStyle(Color.driftwood)
                    .font(.caption)
                    .listRowBackground(Color.bgCard)
            } else {
                // First incomplete task — expanded with subtasks
                if let first = incomplete.first {
                    NavigationLink(value: AppDestination.activeTask(first.id)) {
                        RoutineRowView(routine: first)
                    }
                    .listRowBackground(Color.bgCard)

                    if !first.subtasks.isEmpty {
                        ForEach(first.subtasks.indices, id: \.self) { idx in
                            WatchSubtaskRowView(
                                title: first.subtasks[idx],
                                isCompleted: first.completedSubtaskIndices.contains(idx)
                            ) {
                                store.toggleSubtask(routineId: first.id, subtaskIndex: idx)
                                if let updated = store.routines.first(where: { $0.id == first.id }) {
                                    sessionManager.sendCompletionUpdate(routine: updated)
                                    if updated.completionStatus {
                                        NotificationManager.shared.rescheduleForActiveRoutine(store: store)
                                    }
                                }
                            }
                            .listRowBackground(Color.bgSubtask)
                        }
                    }
                }

                // Remaining incomplete tasks
                ForEach(incomplete.dropFirst()) { routine in
                    NavigationLink(value: AppDestination.activeTask(routine.id)) {
                        RoutineRowView(routine: routine)
                    }
                    .listRowBackground(Color.bgCard)
                }

                // Completed tasks
                if !complete.isEmpty {
                    Section("Completed") {
                        ForEach(complete) { routine in
                            RoutineRowView(routine: routine)
                                .listRowBackground(Color.bgCard.opacity(0.6))
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgMain)
        .navigationTitle("Today")
    }
}

// MARK: - WatchSubtaskRowView

struct WatchSubtaskRowView: View {
    let title: String
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? Color.sage : Color.driftwood)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isCompleted ? Color.driftwood : Color.walnut)
                    .strikethrough(isCompleted, color: Color.driftwood)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.leading, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RoutineRowView

struct RoutineRowView: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(Color.espresso)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if routine.hasScheduledTime {
                        Text(routine.scheduledTimeString)
                            .font(.caption2)
                            .foregroundStyle(Color.driftwood)
                    }
                    if !routine.subtasks.isEmpty {
                        Text("\(routine.completedSubtaskIndices.count)/\(routine.subtasks.count)")
                            .font(.caption2)
                            .foregroundStyle(Color.driftwood)
                    }
                }
            }
            Spacer()
            if routine.completionStatus {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.sage)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.driftwood)
                    .font(.title3)
            }
        }
        .opacity(routine.completionStatus ? 0.55 : 1.0)
    }
}

#Preview {
    NavigationStack {
        TaskListView()
            .environment(RoutineStore())
    }
}
