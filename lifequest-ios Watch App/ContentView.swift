
//
//  ContentView.swift
//  lifequest-ios Watch App
//

import SwiftUI

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case activeTask(UUID)
    case celebration
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(RoutineStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [AppDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            TaskListView()
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .activeTask(let id):
                        ActiveTaskView(routineId: id, onAllDone: {
                            path = [.celebration]
                        })
                    case .celebration:
                        CelebrationView()
                    }
                }
        }
        .preferredColorScheme(.light)
        .onAppear {
            resetToCurrentState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                resetToCurrentState()
            }
        }
        .onChange(of: store.allDoneToday) { _, allDone in
            if allDone {
                path = [.celebration]
            } else if let active = store.activeRoutine {
                // New task added while celebrating — switch to it
                path = [.activeTask(active.id)]
            } else {
                path = []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .markRoutineDoneFromNotification)) { notification in
            guard let routineId = notification.userInfo?["routineId"] as? UUID else { return }

            if let routine = store.routines.first(where: { $0.id == routineId }),
               let nextIdx = routine.nextSubtaskIndex {
                // Has an incomplete subtask — mark it (auto-completes parent if last subtask)
                store.toggleSubtask(routineId: routineId, subtaskIndex: nextIdx)
            } else {
                // No subtasks, or all subtasks already done — mark whole routine complete
                store.markComplete(routineId: routineId)
            }

            // Sync to phone and reschedule notifications for the new active routine
            if let updated = store.routines.first(where: { $0.id == routineId }) {
                WatchSessionManager.shared.sendCompletionUpdate(routine: updated)
            }
            NotificationManager.shared.rescheduleForActiveRoutine(store: store)

            // Navigate: celebration if all done, otherwise jump to the new active task
            resetToCurrentState()
        }
    }

    private func resetToCurrentState() {
        if store.allDoneToday {
            path = [.celebration]
        } else if let active = store.activeRoutine {
            path = [.activeTask(active.id)]
        } else {
            path = []
        }
    }
}

#Preview {
    ContentView()
        .environment(RoutineStore())
}
