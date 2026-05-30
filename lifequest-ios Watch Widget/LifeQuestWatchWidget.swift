
//
//  LifeQuestWatchWidget.swift
//  lifequest-ios Watch Widget
//
//  SETUP (one-time in Xcode):
//  1. File → New → Target → Widget Extension (watchOS platform)
//     Name: "lifequest-ios Watch Widget", uncheck "Include Configuration App Intent"
//  2. Watch App target → Signing & Capabilities → + App Groups → "group.com.xx.lifequest-ios.shared"
//  3. Widget target   → Signing & Capabilities → + App Groups → "group.com.xx.lifequest-ios.shared"
//  4. Add Models.swift (from Watch App) to the Widget target via File Inspector → Target Membership
//

import WidgetKit
import SwiftUI

// MARK: - Shared App Group key (must match RoutineStore.swift)

private let kAppGroupId  = "group.com.xx.lifequest-ios.shared"
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

    /// All tasks completed today
    static let allDone = ActiveTaskEntry(
        date: Date(),
        taskName: nil,
        locationName: nil,
        subtaskName: nil,
        progress: nil
    )

    /// Could not read data from App Group (not configured or empty)
    static let noData = ActiveTaskEntry(
        date: Date(),
        taskName: "—",
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
            // App Group not configured or no data written yet — show placeholder dash
            return .noData
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

// MARK: - Brand Colors

private extension Color {
    static let espresso  = Color(red: 0.227, green: 0.180, blue: 0.149)  // #3A2E26 — main title
    static let walnut    = Color(red: 0.361, green: 0.306, blue: 0.251)  // #5C4E40 — body
    static let driftwood = Color(red: 0.620, green: 0.557, blue: 0.494)  // #9E8E7E — secondary/label
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
        if entry.taskName == nil {
            // All tasks completed
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("All Done!")
                    .font(.headline)
                    .foregroundStyle(Color.espresso)
            }
        } else if let name = entry.taskName, name != "—" {
            VStack(alignment: .leading, spacing: 2) {
                // Row 1: task name + progress
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "circle")
                        .font(.caption2)
                        .foregroundStyle(Color.walnut)
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(Color.espresso)
                        .lineLimit(1)
                    if let p = entry.progress {
                        Spacer(minLength: 4)
                        Text(p)
                            .font(.caption2)
                            .foregroundStyle(Color.driftwood)
                    }
                }
                // Row 2: current subtask
                if let sub = entry.subtaskName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(Color.driftwood)
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(Color.walnut)
                            .lineLimit(1)
                    }
                }
                // Row 3: location
                if let loc = entry.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundStyle(Color.driftwood)
                        Text(loc)
                            .font(.caption2)
                            .foregroundStyle(Color.driftwood)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // No data from App Group yet
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.driftwood)
                Text("Open app to sync")
                    .font(.caption)
                    .foregroundStyle(Color.driftwood)
            }
        }
    }

    // MARK: Inline — single line

    @ViewBuilder
    private var inlineView: some View {
        if let name = entry.taskName, name != "—" {
            if let sub = entry.subtaskName {
                Label("\(name): \(sub)", systemImage: "circle")
                    .foregroundStyle(Color.espresso)
            } else {
                Label(name, systemImage: "circle")
                    .foregroundStyle(Color.espresso)
            }
        } else if entry.taskName == nil {
            Label("All Done!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.espresso)
        } else {
            Label("Open app to sync", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(Color.driftwood)
        }
    }

    // MARK: Circular — icon + abbreviated name

    @ViewBuilder
    private var circularView: some View {
        if let name = entry.taskName, name != "—" {
            VStack(spacing: 1) {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(Color.walnut)
                Text(name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.espresso)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        } else if entry.taskName == nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        } else {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(Color.driftwood)
        }
    }
}

// MARK: - Widget Configuration

struct LifeQuestActiveTaskWidget: Widget {
    let kind = "LifeQuestActiveTask"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveTaskProvider()) { entry in
            ActiveTaskComplicationView(entry: entry)
                .containerBackground(
                    Color(red: 0.980, green: 0.973, blue: 0.961),
                    for: .widget
                )
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
