
//
//  RoutineStore.swift
//  lifequest-ios Watch App
//

import Foundation
import WidgetKit

// App Group must be enabled in both the Watch App and Watch Widget targets in Xcode
// (Signing & Capabilities → + App Groups → add this identifier)
let kAppGroupId  = "group.com.xx.lifequest-ios.shared"
private let kAppStateKey = "LQAppState"

private var sharedDefaults: UserDefaults {
    UserDefaults(suiteName: kAppGroupId) ?? .standard
}

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
            sharedDefaults.set(data, forKey: kAppStateKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func load() {
        guard let data = sharedDefaults.data(forKey: kAppStateKey),
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
            routines[i].completionUpdatedAt = Date()
        }
        lastResetDate = today
        save()
    }

    // MARK: - Completion

    func markComplete(routineId: UUID) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[idx].completionStatus = true
        routines[idx].lastCompletedDate = Calendar.current.startOfDay(for: Date())
        routines[idx].updatedAt = Date()
        routines[idx].completionUpdatedAt = Date()
        save()
    }

    func markSubtaskComplete(routineId: UUID, subtaskIndex: Int) {
        guard let idx = routines.firstIndex(where: { $0.id == routineId }) else { return }
        if !routines[idx].completedSubtaskIndices.contains(subtaskIndex) {
            routines[idx].completedSubtaskIndices.append(subtaskIndex)
            routines[idx].updatedAt = Date()
            routines[idx].completionUpdatedAt = Date()
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
                routines[idx].lastCompletedDate = Calendar.current.startOfDay(for: Date())
            }
        }
        routines[idx].updatedAt = Date()
        routines[idx].completionUpdatedAt = Date()
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
        routines = newRoutines.map { phoneRoutine in
            guard let local = routines.first(where: { $0.id == phoneRoutine.id }) else {
                return phoneRoutine  // new routine from phone, take as-is
            }
            var result = phoneRoutine  // always use phone's definition fields
            // Only keep local completion status if it's newer
            if local.completionUpdatedAt > phoneRoutine.completionUpdatedAt {
                result.completionStatus = local.completionStatus
                result.completedSubtaskIndices = local.completedSubtaskIndices
                result.completionUpdatedAt = local.completionUpdatedAt
                result.lastCompletedDate = local.lastCompletedDate
            }
            return result
        }
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
