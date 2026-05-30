
//
//  lifequest_iosApp.swift
//  lifequest-ios Watch App
//

import SwiftUI

@main
struct lifequest_ios_Watch_AppApp: App {
    @State private var store = RoutineStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .onAppear {
                    WatchSessionManager.shared.store = store
                    WatchSessionManager.shared.onSyncReceived = {
                        NotificationManager.shared.rescheduleForActiveRoutine(store: store)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.performDailyResetIfNeeded()
                        NotificationManager.shared.rescheduleForActiveRoutine(store: store)
                        // Push any completed/partial tasks to phone in case prior message was missed
                        WatchSessionManager.shared.pushTodaysCompletionToPhone(store: store)
                    }
                }
        }
    }
}
