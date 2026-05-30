
//
//  lifequest_iosApp.swift
//  lifequest-ios
//

import SwiftUI

@main
struct lifequest_iosApp: App {
    @State private var store = RoutineStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .onAppear {
                    PhoneSessionManager.shared.store = store
                }
        }
    }
}
