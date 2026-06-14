
//
//  Models.swift
//  lifequest-ios Watch App
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
    /// Tracks when completion status last changed; used for bidirectional last-write-wins sync.
    var completionUpdatedAt: Date
    /// The date the user actually completed this routine (start of day). Not cleared by daily reset.
    /// Used by isDueToday() to carry forward incomplete weekly/biweekly/monthly tasks.
    var lastCompletedDate: Date?

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
        reminderIntervalMinutes: Int = 5,
        completionUpdatedAt: Date = Date(timeIntervalSince1970: 0),
        lastCompletedDate: Date? = nil
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
        self.completionUpdatedAt = completionUpdatedAt
        self.lastCompletedDate = lastCompletedDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        subtasks = try c.decode([String].self, forKey: .subtasks)
        scheduledHour = try c.decodeIfPresent(Int.self, forKey: .scheduledHour)
        scheduledMinute = try c.decodeIfPresent(Int.self, forKey: .scheduledMinute)
        locationId = try c.decodeIfPresent(UUID.self, forKey: .locationId)
        recurrence = try c.decode(RecurrenceType.self, forKey: .recurrence)
        selectedDays = try c.decode([Int].self, forKey: .selectedDays)
        selectedDates = try c.decode([Int].self, forKey: .selectedDates)
        completionStatus = try c.decode(Bool.self, forKey: .completionStatus)
        completedSubtaskIndices = try c.decode([Int].self, forKey: .completedSubtaskIndices)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        reminderIntervalMinutes = try c.decode(Int.self, forKey: .reminderIntervalMinutes)
        completionUpdatedAt = (try? c.decode(Date.self, forKey: .completionUpdatedAt)) ?? Date(timeIntervalSince1970: 0)
        lastCompletedDate = try? c.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
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
        let todayStart = cal.startOfDay(for: today)
        let lastDone = lastCompletedDate ?? Date(timeIntervalSince1970: 0)

        switch recurrence {
        case .daily:
            return true

        case .weekly:
            let days = selectedDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : selectedDays
            for offset in 0...6 {
                guard let checkDate = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                let checkWeekday = cal.component(.weekday, from: checkDate)
                if days.contains(checkWeekday) {
                    return cal.startOfDay(for: lastDone) < checkDate
                }
            }
            return false

        case .biweekly:
            let days = selectedDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : selectedDays
            let creationWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: createdAt))!
            for offset in 0...13 {
                guard let checkDate = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                let checkWeekday = cal.component(.weekday, from: checkDate)
                if days.contains(checkWeekday) {
                    let checkWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkDate))!
                    let weeks = cal.dateComponents([.weekOfYear], from: creationWeekStart, to: checkWeekStart).weekOfYear ?? 0
                    if weeks % 2 == 0 {
                        return cal.startOfDay(for: lastDone) < checkDate
                    }
                }
            }
            return false

        case .monthly:
            let dates = selectedDates.isEmpty ? Array(1...31) : selectedDates
            for offset in 0...30 {
                guard let checkDate = cal.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                let checkDayOfMonth = cal.component(.day, from: checkDate)
                if dates.contains(checkDayOfMonth) {
                    return cal.startOfDay(for: lastDone) < checkDate
                }
            }
            return false
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
