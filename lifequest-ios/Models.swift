
//
//  Models.swift
//  lifequest-ios
//

import Foundation

// MARK: - RecurrenceType

enum RecurrenceType: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - RoutineLocation

struct RoutineLocation: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Routine

struct Routine: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var subtasks: [String]
    var scheduledHour: Int?
    var scheduledMinute: Int?
    var locationId: UUID?
    var recurrence: RecurrenceType
    /// Weekday values: 1=Sunday ... 7=Saturday
    var selectedDays: [Int]
    /// Day-of-month values: 1-31
    var selectedDates: [Int]
    var completionStatus: Bool
    var completedSubtaskIndices: [Int]
    var createdAt: Date
    var updatedAt: Date
    var reminderIntervalMinutes: Int

    init(
        id: UUID = UUID(),
        name: String,
        subtasks: [String] = [],
        scheduledHour: Int? = nil,
        scheduledMinute: Int? = nil,
        locationId: UUID? = nil,
        recurrence: RecurrenceType = .daily,
        selectedDays: [Int] = [],
        selectedDates: [Int] = [],
        completionStatus: Bool = false,
        completedSubtaskIndices: [Int] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        reminderIntervalMinutes: Int = 5
    ) {
        self.id = id
        self.name = name
        self.subtasks = subtasks
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.locationId = locationId
        self.recurrence = recurrence
        self.selectedDays = selectedDays
        self.selectedDates = selectedDates
        self.completionStatus = completionStatus
        self.completedSubtaskIndices = completedSubtaskIndices
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reminderIntervalMinutes = reminderIntervalMinutes
    }

    // MARK: - Computed Properties

    var hasScheduledTime: Bool {
        scheduledHour != nil && scheduledMinute != nil
    }

    var scheduledTimeString: String {
        guard let h = scheduledHour, let m = scheduledMinute else { return "" }
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour = h
        comps.minute = m
        if let date = cal.date(from: comps) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }
        return String(format: "%02d:%02d", h, m)
    }

    var nextSubtaskIndex: Int? {
        for (idx, _) in subtasks.enumerated() {
            if !completedSubtaskIndices.contains(idx) {
                return idx
            }
        }
        return nil
    }

    var allSubtasksCompleted: Bool {
        guard !subtasks.isEmpty else { return true }
        return completedSubtaskIndices.count >= subtasks.count
    }

    // MARK: - isDueToday

    func isDueToday() -> Bool {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun..7=Sat
        let dayOfMonth = cal.component(.day, from: today)

        switch recurrence {
        case .daily:
            return true

        case .weekly:
            if selectedDays.isEmpty { return true }
            return selectedDays.contains(weekday)

        case .biweekly:
            if !selectedDays.isEmpty && !selectedDays.contains(weekday) { return false }
            let creationWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: createdAt))!
            let currentWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            let weeks = cal.dateComponents([.weekOfYear], from: creationWeekStart, to: currentWeekStart).weekOfYear ?? 0
            return weeks % 2 == 0

        case .monthly:
            if selectedDates.isEmpty { return true }
            return selectedDates.contains(dayOfMonth)
        }
    }
}

// MARK: - AppState (persistence)

struct AppState: Codable {
    var routines: [Routine]
    var locations: [RoutineLocation]
    var lastResetDate: Date?

    init(routines: [Routine] = [], locations: [RoutineLocation] = [], lastResetDate: Date? = nil) {
        self.routines = routines
        self.locations = locations
        self.lastResetDate = lastResetDate
    }
}

// MARK: - Sorting Helper

extension Array where Element == Routine {
    /// Returns routines that are due today, sorted per spec:
    /// 1. Routines with scheduledTime, ascending by time
    /// 2. Routines without scheduledTime, ascending by createdAt
    func todaysSorted() -> [Routine] {
        let due = self.filter { $0.isDueToday() }
        let withTime = due.filter { $0.hasScheduledTime }.sorted {
            let lhMin = ($0.scheduledHour ?? 0) * 60 + ($0.scheduledMinute ?? 0)
            let rhMin = ($1.scheduledHour ?? 0) * 60 + ($1.scheduledMinute ?? 0)
            return lhMin < rhMin
        }
        let withoutTime = due.filter { !$0.hasScheduledTime }.sorted {
            $0.createdAt < $1.createdAt
        }
        return withTime + withoutTime
    }
}
