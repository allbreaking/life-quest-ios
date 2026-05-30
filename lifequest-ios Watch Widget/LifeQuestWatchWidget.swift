
//
//  LifeQuestWatchWidget.swift
//  lifequest-ios Watch Widget
//
//  SETUP (one-time in Xcode):
//  1. File → New → Target → Widget Extension (watchOS platform)
//     Name: "lifequest-ios Watch Widget", uncheck "Include Configuration App Intent"
//  2. Watch App target → Signing & Capabilities → + App Groups → "group.com.lifequest.shared"
//  3. Widget target   → Signing & Capabilities → + App Groups → "group.com.lifequest.shared"
//  4. Add Models.swift (from Watch App) to the Widget target via File Inspector → Target Membership
//

import WidgetKit
import SwiftUI

// MARK: - Shared App Group key (must match RoutineStore.swift)

private let kAppGroupId  = "group.com.lifequest.shared"
private let kAppStateKey = "LQAppState"

// MARK: - Timeline Entry

struct ActiveTaskEntry: TimelineEntry {
    let date: Date
    let taskName: String?
    let locationName: String?
    let subtaskName: String?
    let progress: String?      // "2/5"

    static let placeholder = ActiveTaskEntry(
        date: Date(),
        taskName: "Morning Routine",
        locationName: "Home",
        subtaskName: "Meditate",
        progress: "1/3"
    )

    static let allDone = ActiveTaskEntry(
        date: Date(),
        taskName: nil,
        locationName: nil,
        subtaskName: nil,
        progress: nil
    )
}

// MARK: - Timeline Provider

struct ActiveTaskProvider: TimelineProvider {

    func placeholder(in context: Context) -> ActiveTaskEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ActiveTaskEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveTaskEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 10 minutes as a fallback; data changes trigger explicit reload via WidgetCenter
        let refresh = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    // MARK: Read from shared App Group UserDefaults

    private func currentEntry() -> ActiveTaskEntry {
        let defaults = UserDefaults(suiteName: kAppGroupId) ?? .standard
        guard
            let data  = defaults.data(forKey: kAppStateKey),
            let state = try? JSONDecoder().decode(AppState.self, from: data)
        else {
            return .allDone
        }

        guard let routine = state.routines.todaysSorted().first(where: { !$0.completionStatus }) else {
            return .allDone
        }

        let locationName = routine.locationId.flatMap { id in
            state.locations.first { $0.id == id }?.name
        }

        let subtaskName: String? = routine.nextSubtaskIndex.map { routine.subtasks[$0] }

        let progress: String? = routine.subtasks.isEmpty
            ? nil
            : "\(routine.completedSubtaskIndices.count)/\(routine.subtasks.count)"

        return ActiveTaskEntry(
            date: Date(),
            taskName: routine.name,
            locationName: locationName,
            subtaskName: subtaskName,
            progress: progress
        )
    }
}

// MARK: - Complication Views

struct ActiveTaskComplicationView: View {
    var entry: ActiveTaskEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangularView
        case .accessoryInline:      inlineView
        case .accessoryCircular:    circularView
        default:                    rectangularView
        }
    }

    // MARK: Rectangular — most information

    @ViewBuilder
    private var rectangularView: some View {
        if let name = entry.taskName {
            VStack(alignment: .leading, spacing: 2) {
                // Row 1: task name + progress
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "circle")
                        .font(.caption2)
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                    if let p = entry.progress {
                        Spacer(minLength: 4)
                        Text(p)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                // Row 2: current subtask
                if let sub = entry.subtaskName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                // Row 3: location
                if let loc = entry.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(loc)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("All Done!")
                    .font(.headline)
            }
        }
    }

    // MARK: Inline — single line

    @ViewBuilder
    private var inlineView: some View {
        if let name = entry.taskName {
            if let sub = entry.subtaskName {
                Label("\(name): \(sub)", systemImage: "circle")
            } else {
                Label(name, systemImage: "circle")
            }
        } else {
            Label("All Done!", systemImage: "checkmark.circle.fill")
        }
    }

    // MARK: Circular — icon + abbreviated name

    @ViewBuilder
    private var circularView: some View {
        if let name = entry.taskName {
            VStack(spacing: 1) {
                Image(systemName: "circle")
                    .font(.body)
                Text(name)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
        }
    }
}

// MARK: - Widget Configuration

struct LifeQuestActiveTaskWidget: Widget {
    let kind = "LifeQuestActiveTask"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveTaskProvider()) { entry in
            ActiveTaskComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Active Task")
        .description("Shows your current active routine and subtask.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}

// MARK: - Widget Bundle (@main for the extension target)

@main
struct LifeQuestWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeQuestActiveTaskWidget()
    }
}
