
//
//  TaskListView.swift
//  lifequest-ios Watch App
//

import SwiftUI

// MARK: - Design Tokens

private extension Color {
    // Backgrounds
    static let bgMain      = Color(red: 0.980, green: 0.973, blue: 0.961) // #FAF8F5
    static let bgCard      = Color(red: 0.949, green: 0.929, blue: 0.906) // #F2EDE7
    // Primary
    static let apricot     = Color(red: 0.957, green: 0.518, blue: 0.373) // #F4845F
    static let sage        = Color(red: 0.784, green: 0.851, blue: 0.643) // #C8D9A4
    // Typography
    static let espresso    = Color(red: 0.227, green: 0.180, blue: 0.149) // #3A2E26
    static let walnut      = Color(red: 0.361, green: 0.306, blue: 0.251) // #5C4E40
    static let driftwood   = Color(red: 0.620, green: 0.557, blue: 0.494) // #9E8E7E
}

struct TaskListView: View {
    @Environment(RoutineStore.self) private var store

    var body: some View {
        let sorted = store.todaysRoutines
        let incomplete = sorted.filter { !$0.completionStatus }
        let complete = sorted.filter { $0.completionStatus }

        List {
            if sorted.isEmpty {
                Text("No routines today")
                    .foregroundStyle(Color.driftwood)
                    .font(.caption)
                    .listRowBackground(Color.bgCard)
            } else {
                ForEach(incomplete) { routine in
                    NavigationLink(destination: ActiveTaskView(routineId: routine.id)) {
                        RoutineRowView(routine: routine)
                    }
                    .listRowBackground(Color.bgCard)
                }
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

struct RoutineRowView: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(Color.espresso)
                    .lineLimit(1)
                if routine.hasScheduledTime {
                    Text(routine.scheduledTimeString)
                        .font(.caption2)
                        .foregroundStyle(Color.driftwood)
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
