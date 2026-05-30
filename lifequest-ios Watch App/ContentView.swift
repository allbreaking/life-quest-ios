
//
//  ContentView.swift
//  lifequest-ios Watch App
//

import SwiftUI

struct ContentView: View {
    @Environment(RoutineStore.self) private var store

    var body: some View {
        NavigationStack {
            TaskListView()
        }
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: .markRoutineDoneFromNotification)) { notification in
            if let routineId = notification.userInfo?["routineId"] as? UUID {
                store.markComplete(routineId: routineId)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(RoutineStore())
}
