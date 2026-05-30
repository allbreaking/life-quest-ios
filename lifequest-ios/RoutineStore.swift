
//
//  RoutineStore.swift
//  lifequest-ios
//

import Foundation

private let kAppStateKey = "LQAppState"

@Observable
final class RoutineStore {
    var routines: [Routine] = []
    var locations: [RoutineLocation] = []
    var lastResetDate: Date? = nil

    init() {
        load()
        performDailyResetIfNeeded()
    }

    // MARK: - Persistence

    func save() {
        let state = AppState(routines: routines, locations: locations, lastResetDate: lastResetDate)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: kAppStateKey)
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: kAppStateKey),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return
        }
        routines = state.routines
        locations = state.locations
        lastResetDate = state.lastResetDate
    }

    // MARK: - Daily Reset

    func performDailyResetIfNeeded() {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        guard hour >= 4 else { return }

        let today = cal.startOfDay(for: now)
        if let last = lastResetDate, cal.isDate(last, inSameDayAs: today) { return }

        for i in routines.indices {
            routines[i].completionStatus = false
            routines[i].completedSubtaskIndices = []
        }
        lastResetDate = today
        save()
    }

    // MARK: - CRUD: Routines

    func addRoutine(_ routine: Routine) {
        routines.append(routine)
        save()
    }

    func updateRoutine(_ routine: Routine) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[idx] = routine
        save()
    }

    func deleteRoutine(id: UUID) {
        routines.removeAll { $0.id == id }
        save()
    }

    func deleteRoutines(at offsets: IndexSet, from list: [Routine]) {
        let idsToDelete = offsets.map { list[$0].id }
        routines.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    // MARK: - CRUD: Locations

    func addLocation(_ location: RoutineLocation) {
        locations.append(location)
        save()
    }

    func updateLocation(_ location: RoutineLocation) {
        guard let idx = locations.firstIndex(where: { $0.id == location.id }) else { return }
        locations[idx] = location
        save()
    }

    func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        // Clear locationId from any routines referencing this location
        for i in routines.indices where routines[i].locationId == id {
            routines[i].locationId = nil
        }
        save()
    }

    // MARK: - Completion

    func markComplete(routineId: UUID) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[idx].completionStatus = true
        routines[idx].updatedAt = Date()
        save()
    }

    func uncompleteRoutine(routineId: UUID) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[idx].completionStatus = false
        routines[idx].completedSubtaskIndices = []
        routines[idx].updatedAt = Date()
        save()
    }

    func markSubtaskComplete(routineId: UUID, subtaskIndex: Int) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        if !routines[idx].completedSubtaskIndices.contains(subtaskIndex) {
            routines[idx].completedSubtaskIndices.append(subtaskIndex)
            routines[idx].updatedAt = Date()
        }
        save()
    }

    /// Toggle subtask completion; auto-completes or un-completes the parent routine accordingly.
    func toggleSubtask(routineId: UUID, subtaskIndex: Int) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        if routines[idx].completedSubtaskIndices.contains(subtaskIndex) {
            routines[idx].completedSubtaskIndices.removeAll { $0 == subtaskIndex }
            routines[idx].completionStatus = false
        } else {
            routines[idx].completedSubtaskIndices.append(subtaskIndex)
            if routines[idx].allSubtasksCompleted {
                routines[idx].completionStatus = true
            }
        }
        routines[idx].updatedAt = Date()
        save()
    }

    // MARK: - Today's Routines

    var todaysRoutines: [Routine] {
        routines.todaysSorted()
    }

    var activeRoutine: Routine? {
        todaysRoutines.first { !$0.completionStatus }
    }

    // MARK: - Sync: Apply full sync from phone (watch receives this)

    func applyFullSync(routines newRoutines: [Routine], locations newLocations: [RoutineLocation]) {
        // Merge by updatedAt (last-write-wins per routine)
        var merged: [Routine] = newRoutines
        for local in routines {
            if let remoteIdx = merged.firstIndex(where: { $0.id == local.id }) {
                // Keep whichever was updated more recently
                if local.updatedAt > merged[remoteIdx].updatedAt {
                    merged[remoteIdx] = local
                }
            }
            // If routine only exists locally, it may have been deleted remotely — do not re-add
        }
        routines = merged
        locations = newLocations
        save()
    }

    // MARK: - Sync: Apply completion update from watch

    func applyCompletionUpdate(routineId: UUID, completionStatus: Bool, completedSubtaskIndices: [Int], updatedAt: Date) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        // Last-write-wins
        if updatedAt >= routines[idx].updatedAt {
            routines[idx].completionStatus = completionStatus
            routines[idx].completedSubtaskIndices = completedSubtaskIndices
            routines[idx].updatedAt = updatedAt
            save()
        }
    }

    // MARK: - Serialization helpers for sync

    func encodedRoutines() -> Data? {
        try? JSONEncoder().encode(routines)
    }

    func encodedLocations() -> Data? {
        try? JSONEncoder().encode(locations)
    }

    // MARK: - Export / Import

    func exportData() -> Data? {
        var exportState = AppState(routines: routines, locations: locations)
        for i in exportState.routines.indices {
            exportState.routines[i].completionStatus = false
            exportState.routines[i].completedSubtaskIndices = []
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exportState)
    }

    struct ImportResult {
        let routinesAdded: Int
        let locationsAdded: Int
    }

    func importData(_ data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(AppState.self, from: data)

        var locationsAdded = 0
        for loc in imported.locations where !locations.contains(where: { $0.id == loc.id }) {
            locations.append(loc)
            locationsAdded += 1
        }

        var routinesAdded = 0
        for routine in imported.routines where !routines.contains(where: { $0.id == routine.id }) {
            var r = routine
            r.completionStatus = false
            r.completedSubtaskIndices = []
            routines.append(r)
            routinesAdded += 1
        }

        if routinesAdded > 0 || locationsAdded > 0 { save() }
        return ImportResult(routinesAdded: routinesAdded, locationsAdded: locationsAdded)
    }
}
