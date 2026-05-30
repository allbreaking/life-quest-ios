
//
//  NotificationManager.swift
//  lifequest-ios Watch App
//

import Foundation
import UserNotifications
import WatchKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let categoryId = "ROUTINE_REMINDER"
    private let actionId = "MARK_DONE"

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupCategory()
    }

    // MARK: - Setup

    private func setupCategory() {
        let markDoneAction = UNNotificationAction(
            identifier: actionId,
            title: "Mark Done",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [markDoneAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Schedule Notifications

    /// Schedule up to 12 repeat notifications for the active routine.
    /// First notification fires at the routine's scheduled time (or immediately if overdue/no scheduled time),
    /// then repeats every reminderIntervalMinutes.
    func scheduleNotifications(for routine: Routine) {
        cancelAllNotifications(for: routine.id)

        let intervalSeconds = Double(routine.reminderIntervalMinutes) * 60.0
        let maxCount = 12
        let now = Date()

        // Determine when reminders should start
        let startDate: Date
        if let hour = routine.scheduledHour, let minute = routine.scheduledMinute {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            let scheduled = Calendar.current.date(from: comps) ?? now
            // Start at scheduled time; if already past, start from now
            startDate = scheduled > now ? scheduled : now
        } else {
            startDate = now
        }

        for index in 0..<maxCount {
            // index = 0 fires at startDate (the scheduled time itself), then every interval
            let delay = startDate.timeIntervalSince(now) + Double(index) * intervalSeconds
            let fireDelay = max(delay, 1.0) // at least 1 second in the future

            let content = UNMutableNotificationContent()
            content.title = routine.name
            if let nextIdx = routine.nextSubtaskIndex, nextIdx < routine.subtasks.count {
                content.body = routine.subtasks[nextIdx]
            } else {
                content.body = "Time to complete your routine!"
            }
            content.categoryIdentifier = categoryId
            content.userInfo = ["routineId": routine.id.uuidString]
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDelay, repeats: false)
            let identifier = "lq-routine-\(routine.id.uuidString)-\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    /// Schedule a single arrival notification for a future scheduled routine.
    private func scheduleArrivalNotification(for routine: Routine, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = routine.name
        content.body = routine.subtasks.first ?? "Time to start your routine!"
        content.categoryIdentifier = categoryId
        content.userInfo = ["routineId": routine.id.uuidString]
        content.sound = .default

        let delay = date.timeIntervalSince(Date())
        guard delay > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let identifier = "lq-arrival-\(routine.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// Cancel all pending notifications for a specific routine
    func cancelAllNotifications(for routineId: UUID) {
        let idUUID = routineId.uuidString
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter {
                    $0.identifier.hasPrefix("lq-routine-\(idUUID)-") ||
                    $0.identifier == "lq-arrival-\(idUUID)"
                }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// Cancel all pending Life Quest notifications
    func cancelAllLifeQuestNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter {
                    $0.identifier.hasPrefix("lq-routine-") ||
                    $0.identifier.hasPrefix("lq-arrival-")
                }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// Called when app becomes active or active routine changes.
    /// Schedules notifications only for the current active routine.
    func rescheduleForActiveRoutine(store: RoutineStore) {
        cancelAllLifeQuestNotifications()
        if let active = store.activeRoutine {
            scheduleNotifications(for: active)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == actionId {
            let userInfo = response.notification.request.content.userInfo
            if let idString = userInfo["routineId"] as? String,
               let routineId = UUID(uuidString: idString) {
                // Post notification for the app to handle
                NotificationCenter.default.post(
                    name: .markRoutineDoneFromNotification,
                    object: nil,
                    userInfo: ["routineId": routineId]
                )
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let markRoutineDoneFromNotification = Notification.Name("markRoutineDoneFromNotification")
}
