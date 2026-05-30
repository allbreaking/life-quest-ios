
//
//  ActiveTaskView.swift
//  lifequest-ios Watch App
//

import SwiftUI
import WatchKit

// MARK: - Design Tokens

private extension Color {
    // Backgrounds
    static let bgMain      = Color(red: 0.980, green: 0.973, blue: 0.961) // #FAF8F5
    static let bgCream     = Color(red: 0.992, green: 0.922, blue: 0.827) // #FDEBD3
    static let divider     = Color(red: 0.910, green: 0.886, blue: 0.855) // #E8E2DA
    // Primary
    static let apricot     = Color(red: 0.957, green: 0.518, blue: 0.373) // #F4845F
    static let peach       = Color(red: 0.976, green: 0.663, blue: 0.478) // #F9A97A
    // Accent
    static let sage        = Color(red: 0.784, green: 0.851, blue: 0.643) // #C8D9A4
    // Typography
    static let espresso    = Color(red: 0.227, green: 0.180, blue: 0.149) // #3A2E26
    static let walnut      = Color(red: 0.361, green: 0.306, blue: 0.251) // #5C4E40
    static let driftwood   = Color(red: 0.620, green: 0.557, blue: 0.494) // #9E8E7E
}

struct ActiveTaskView: View {
    @Environment(RoutineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var sessionManager: WatchSessionManager { WatchSessionManager.shared }

    @State private var routineId: UUID
    let onAllDone: (() -> Void)?

    init(routineId: UUID, onAllDone: (() -> Void)? = nil) {
        _routineId = State(initialValue: routineId)
        self.onAllDone = onAllDone
    }

    @State private var showingFireworks = false
    @State private var isLongPressing = false
    @State private var longPressProgress: CGFloat = 0.0

    private var routine: Routine? {
        store.routines.first { $0.id == routineId }
    }

    private var location: RoutineLocation? {
        guard let locationId = routine?.locationId else { return nil }
        return store.locations.first { $0.id == locationId }
    }

    var body: some View {
        Group {
            if let routine = routine {
                mainContent(routine: routine)
            } else {
                Text("Routine not found")
                    .foregroundStyle(Color.driftwood)
            }
        }
        .onChange(of: routineId) { _, _ in
            isLongPressing = false
            longPressProgress = 0
        }
    }

    @ViewBuilder
    private func mainContent(routine: Routine) -> some View {
        ZStack {
            Color.bgMain.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Location + time header
                    if location != nil || routine.hasScheduledTime {
                        HStack {
                            if let loc = location {
                                Label(loc.name, systemImage: "mappin.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.driftwood)
                            }
                            Spacer()
                            if routine.hasScheduledTime {
                                Text(routine.scheduledTimeString)
                                    .font(.caption2)
                                    .foregroundStyle(Color.driftwood)
                            }
                        }
                    }

                    // Routine name
                    Text(routine.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.espresso)

                    Divider()
                        .overlay(Color.divider)

                    // Subtask or instruction
                    if routine.completionStatus {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sage)
                            Text("Completed!")
                                .foregroundStyle(Color.sage)
                        }
                        .font(.subheadline)
                    } else if routine.subtasks.isEmpty {
                        Text("Tap & Hold to Complete")
                            .font(.subheadline)
                            .foregroundStyle(Color.driftwood)
                            .multilineTextAlignment(.center)
                    } else if let nextIdx = routine.nextSubtaskIndex {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.subtasks[nextIdx])
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.walnut)
                            Text("\(routine.completedSubtaskIndices.count)/\(routine.subtasks.count)")
                                .font(.caption2)
                                .foregroundStyle(Color.driftwood)
                        }
                    }

                    Spacer(minLength: 8)

                    // Long-press button area
                    if !routine.completionStatus {
                        longPressButton(routine: routine)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Fireworks overlay
            if showingFireworks {
                FireworksView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func longPressButton(routine: Routine) -> some View {
        let label: String = {
            if routine.subtasks.isEmpty {
                return "Hold to Complete"
            } else if let nextIdx = routine.nextSubtaskIndex {
                return "Hold: \(routine.subtasks[nextIdx])"
            }
            return "Hold to Complete"
        }()

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.bgCream)
                .frame(height: 44)

            // Progress overlay
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.apricot.opacity(0.75))
                    .frame(width: geo.size.width * longPressProgress, height: 44)
            }
            .frame(height: 44)

            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.espresso)
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
        .frame(height: 44)
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    isLongPressing = true
                    withAnimation(.linear(duration: 0.5)) {
                        longPressProgress = 1.0
                    }
                }
                .onEnded { _ in
                    isLongPressing = false
                    longPressProgress = 0
                    handleLongPress(routine: routine)
                }
        )
        .onChange(of: isLongPressing) { _, pressing in
            if !pressing {
                withAnimation {
                    longPressProgress = 0
                }
            }
        }
    }

    // MARK: - Actions

    private func handleLongPress(routine: Routine) {
        if routine.subtasks.isEmpty {
            completeRoutine(routine: routine)
        } else if let nextIdx = routine.nextSubtaskIndex {
            WKInterfaceDevice.current().play(.notification)
            store.markSubtaskComplete(routineId: routineId, subtaskIndex: nextIdx)

            if let updated = store.routines.first(where: { $0.id == routineId }),
               updated.allSubtasksCompleted {
                completeRoutine(routine: updated)
            } else {
                // Refresh notifications so body reflects the new next subtask
                if let updated = store.routines.first(where: { $0.id == routineId }) {
                    NotificationManager.shared.scheduleNotifications(for: updated)
                    sessionManager.sendCompletionUpdate(routine: updated)
                }
            }
        }
    }

    private func completeRoutine(routine: Routine) {
        WKInterfaceDevice.current().play(.success)
        store.markComplete(routineId: routineId)

        if let updated = store.routines.first(where: { $0.id == routineId }) {
            sessionManager.sendCompletionUpdate(routine: updated)
        }

        NotificationManager.shared.cancelAllNotifications(for: routineId)
        // Schedule notifications for the next active routine (if any)
        NotificationManager.shared.rescheduleForActiveRoutine(store: store)

        showingFireworks = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingFireworks = false
            if store.allDoneToday {
                onAllDone?()
            } else if let next = store.activeRoutine {
                routineId = next.id  // Stay on this view, switch to next task
            } else {
                dismiss()
            }
        }
    }
}

#Preview {
    let store = RoutineStore()
    let routine = Routine(name: "Morning Meditation", subtasks: ["Sit quietly", "Breathe deeply"])
    let routine2 = Routine(name: "Morning Meditation2", subtasks: ["Sit quietly", "Breathe deeply"])
    store.addRoutine(routine)
    store.addRoutine(routine2)
    return NavigationStack {
        ActiveTaskView(routineId: routine.id, onAllDone: {})
            .environment(store)
    }
}

// MARK: - RoutineStore preview helper
private extension RoutineStore {
    func addRoutine(_ routine: Routine) {
        routines.append(routine)
    }
}
