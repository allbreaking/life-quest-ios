
//
//  RoutineStore.swift
//  lifequest-ios Watch App
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

    // MARK: - Completion

    func markComplete(routineId: UUID) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[idx].completionStatus = true
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

    var allDoneToday: Bool {
        let today = todaysRoutines
        return !today.isEmpty && today.allSatisfy { $0.completionStatus }
    }

    // MARK: - Sync: Apply full sync from phone

    func applyFullSync(routines newRoutines: [Routine], locations newLocations: [RoutineLocation]) {
        // Merge by updatedAt (last-write-wins per routine)
        var merged: [Routine] = newRoutines
        for local in routines {
            if let remoteIdx = merged.firstIndex(where: { $0.id == local.id }) {
                if local.updatedAt > merged[remoteIdx].updatedAt {
                    merged[remoteIdx] = local
                }
            }
        }
        routines = merged
        locations = newLocations
        save()
    }

    // MARK: - Serialization helpers

    func encodedRoutines() -> Data? {
        try? JSONEncoder().encode(routines)
    }

    func encodedLocations() -> Data? {
        try? JSONEncoder().encode(locations)
    }
}
