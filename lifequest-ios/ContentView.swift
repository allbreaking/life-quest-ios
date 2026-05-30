
//
//  ContentView.swift
//  lifequest-ios
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RoutineListView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.clipboard")
                }

            LocationLibraryView()
                .tabItem {
                    Label("Locations", systemImage: "mappin.and.ellipse")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(RoutineStore())
}
