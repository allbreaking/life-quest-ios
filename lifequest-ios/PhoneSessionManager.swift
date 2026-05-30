
//
//  PhoneSessionManager.swift
//  lifequest-ios
//

import Foundation
import WatchConnectivity

final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    weak var store: RoutineStore? {
        didSet { sendRoutinesToWatch() }
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send to Watch

    func sendRoutinesToWatch() {
        guard let store else { return }
        guard let routinesData = store.encodedRoutines(),
              let locationsData = store.encodedLocations() else { return }

        let message: [String: Any] = [
            "type": "fullSync",
            "routines": routinesData,
            "locations": locationsData
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] _ in
                self?.transferUserInfoToWatch(message)
            }
        } else {
            transferUserInfoToWatch(message)
        }
    }

    private func transferUserInfoToWatch(_ info: [String: Any]) {
        WCSession.default.transferUserInfo(info)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in self.sendRoutinesToWatch() }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
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
        guard let type = message["type"] as? String, type == "completion" else { return }
        Task { @MainActor in self.handleCompletionUpdate(message) }
    }

    @MainActor
    private func handleCompletionUpdate(_ message: [String: Any]) {
        guard
            let idString = message["routineId"] as? String,
            let routineId = UUID(uuidString: idString),
            let completionStatus = message["completionStatus"] as? Bool,
            let subtaskData = message["completedSubtaskIndices"] as? Data,
            let subtaskIndices = try? JSONDecoder().decode([Int].self, from: subtaskData),
            let updatedAtInterval = message["updatedAt"] as? Double
        else { return }

        store?.applyCompletionUpdate(
            routineId: routineId,
            completionStatus: completionStatus,
            completedSubtaskIndices: subtaskIndices,
            updatedAt: Date(timeIntervalSince1970: updatedAtInterval)
        )
        sendRoutinesToWatch()
    }
}
