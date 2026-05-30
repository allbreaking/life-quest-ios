
//
//  LocationLibraryView.swift
//  lifequest-ios
//

import SwiftUI

struct LocationLibraryView: View {
    @Environment(RoutineStore.self) private var store
    private var sessionManager: PhoneSessionManager { PhoneSessionManager.shared }

    @State private var showingAddSheet = false
    @State private var editingLocation: RoutineLocation? = nil
    @State private var newLocationName: String = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.locations) { location in
                    Text(location.name)
                        .onTapGesture {
                            editingLocation = location
                            newLocationName = location.name
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteLocation(id: location.id)
                                sessionManager.sendRoutinesToWatch()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newLocationName = ""
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                locationFormSheet(title: "New Location", name: $newLocationName) {
                    let trimmed = newLocationName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.addLocation(RoutineLocation(name: trimmed))
                    sessionManager.sendRoutinesToWatch()
                    showingAddSheet = false
                } onCancel: {
                    showingAddSheet = false
                }
            }
            .sheet(item: $editingLocation) { loc in
                locationFormSheet(title: "Edit Location", name: $newLocationName) {
                    let trimmed = newLocationName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    var updated = loc
                    updated.name = trimmed
                    store.updateLocation(updated)
                    sessionManager.sendRoutinesToWatch()
                    editingLocation = nil
                } onCancel: {
                    editingLocation = nil
                }
            }
        }
    }

    @ViewBuilder
    private func locationFormSheet(
        title: String,
        name: Binding<String>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            Form {
                Section("Location Name") {
                    TextField("Name", text: name)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(name.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    LocationLibraryView()
        .environment(RoutineStore())
}
