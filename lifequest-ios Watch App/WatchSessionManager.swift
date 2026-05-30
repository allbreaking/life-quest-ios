
//
//  WatchSessionManager.swift
//  lifequest-ios Watch App
//

import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    weak var store: RoutineStore?
    var onSyncReceived: (() -> Void)?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send Completion Update to Phone

    func sendCompletionUpdate(routine: Routine) {
        guard let subtaskData = try? JSONEncoder().encode(routine.completedSubtaskIndices) else { return }

        let message: [String: Any] = [
            "type": "completion",
            "routineId": routine.id.uuidString,
            "completionStatus": routine.completionStatus,
            "completedSubtaskIndices": subtaskData,
            "completionUpdatedAt": routine.completionUpdatedAt.timeIntervalSince1970
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { [weak self] _ in
                self?.transferCompletionUpdate(message)
            })
        } else {
            transferCompletionUpdate(message)
        }
    }

    private func transferCompletionUpdate(_ info: [String: Any]) {
        WCSession.default.transferUserInfo(info)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        // Request a full sync from phone on every activation (covers reinstall / data loss)
        Task { @MainActor in self.requestSyncFromPhone() }
    }

    func requestSyncFromPhone() {
        let message: [String: Any] = ["type": "requestSync"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { [weak self] _ in
                self?.transferRequestSync()
            })
        } else {
            transferRequestSync()
        }
    }

    private func transferRequestSync() {
        WCSession.default.transferUserInfo(["type": "requestSync"])
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler(["status": "ok"])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }

    // MARK: - Message Handling

    private nonisolated func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        Task { @MainActor in
            switch type {
            case "fullSync":
                self.handleFullSync(message)
            default:
                break
            }
        }
    }

    @MainActor
    private func handleFullSync(_ message: [String: Any]) {
        guard
            let routinesData = message["routines"] as? Data,
            let locationsData = message["locations"] as? Data,
            let newRoutines = try? JSONDecoder().decode([Routine].self, from: routinesData),
            let newLocations = try? JSONDecoder().decode([RoutineLocation].self, from: locationsData)
        else { return }

        store?.applyFullSync(routines: newRoutines, locations: newLocations)
        onSyncReceived?()
    }
}
