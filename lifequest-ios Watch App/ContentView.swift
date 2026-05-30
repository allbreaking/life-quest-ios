
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
            if let routineId = notification.userInfo?["routineId"] as? UUID {
                store.markComplete(routineId: routineId)
            }
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
