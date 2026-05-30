
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

    private let maxNotificationCount = 12

    /// Schedule up to 12 repeat notifications for the active routine.
    /// - If the scheduled time is in the future: first notification fires AT that time.
    /// - If the scheduled time has passed: align to the next interval boundary (never fires immediately).
    /// - No scheduled time: first notification fires after one full interval.
    func scheduleNotifications(for routine: Routine) {
        // Synchronous removal by constructing known identifiers — no async race condition.
        cancelAllNotifications(for: routine.id)

        let intervalSeconds = Double(routine.reminderIntervalMinutes) * 60.0
        let now = Date()

        let startDate: Date
        if let hour = routine.scheduledHour, let minute = routine.scheduledMinute {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            let scheduled = Calendar.current.date(from: comps) ?? now
            if scheduled > now {
                // Future: fire exactly at scheduled time
                startDate = scheduled
            } else {
                // Past: advance to the next interval boundary from the scheduled time
                let elapsed = now.timeIntervalSince(scheduled)
                let intervalsElapsed = floor(elapsed / intervalSeconds)
                startDate = scheduled.addingTimeInterval((intervalsElapsed + 1) * intervalSeconds)
            }
        } else {
            // No scheduled time: first reminder after one full interval
            startDate = now.addingTimeInterval(intervalSeconds)
        }

        for index in 0..<maxNotificationCount {
            let delay = startDate.timeIntervalSince(now) + Double(index) * intervalSeconds
            guard delay > 0 else { continue }

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

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let identifier = "lq-routine-\(routine.id.uuidString)-\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    /// Cancel all pending notifications for a specific routine.
    /// Uses direct identifier construction — synchronous, no callback race condition.
    func cancelAllNotifications(for routineId: UUID) {
        let id = routineId.uuidString
        let identifiers = (0..<maxNotificationCount).map { "lq-routine-\(id)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Cancel all pending Life Quest notifications.
    /// Uses removeAllPendingNotificationRequests — synchronous, safe to call before scheduling.
    func cancelAllLifeQuestNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
