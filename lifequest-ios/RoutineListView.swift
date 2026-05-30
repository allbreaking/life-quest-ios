
//
//  RoutineListView.swift
//  lifequest-ios
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileDocument wrapper for export

struct RoutineExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - RoutineListView

struct RoutineListView: View {
    @Environment(RoutineStore.self) private var store
    private var sessionManager: PhoneSessionManager { PhoneSessionManager.shared }

    @State private var showingEditor = false
    @State private var editingRoutine: Routine? = nil
    @State private var routineToDelete: Routine? = nil
    @State private var showingDeleteAlert = false
    @State private var syncFeedback = false

    // Export / Import
    @State private var showingExporter = false
    @State private var exportDocument: RoutineExportDocument? = nil
    @State private var showingImporter = false
    @State private var importResult: RoutineStore.ImportResult? = nil
    @State private var importError: String? = nil
    @State private var showingImportResult = false

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "lifequest-routines-\(formatter.string(from: Date()))"
    }

    /// Today's routines: incomplete first (sorted by time), complete last.
    /// Non-today routines appended at the end.
    private var displayedRoutines: [Routine] {
        let todayIncomplete = store.todaysRoutines.filter { !$0.completionStatus }
        let todayComplete   = store.todaysRoutines.filter { $0.completionStatus }
        let notToday = store.routines
            .filter { !$0.isDueToday() }
            .sorted { $0.createdAt < $1.createdAt }
        return todayIncomplete + todayComplete + notToday
    }

    private var firstIncompleteId: UUID? {
        store.todaysRoutines.first { !$0.completionStatus }?.id
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(displayedRoutines) { routine in
                    routineRow(routine)
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            if let data = store.exportData() {
                                exportDocument = RoutineExportDocument(data: data)
                                showingExporter = true
                            }
                        } label: {
                            Label("Export Routines", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import Routines", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            sessionManager.sendRoutinesToWatch()
                            syncFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                syncFeedback = false
                            }
                        } label: {
                            Image(systemName: syncFeedback ? "checkmark" : "arrow.triangle.2.circlepath")
                                .foregroundStyle(syncFeedback ? .green : .primary)
                                .animation(.default, value: syncFeedback)
                        }
                        Button {
                            editingRoutine = nil
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditor, onDismiss: {
                editingRoutine = nil
            }) {
                RoutineEditorView(routine: editingRoutine) { saved in
                    if let existing = editingRoutine {
                        var updated = saved
                        updated.id = existing.id
                        updated.createdAt = existing.createdAt
                        updated.updatedAt = Date()
                        store.updateRoutine(updated)
                    } else {
                        store.addRoutine(saved)
                    }
                    sessionManager.sendRoutinesToWatch()
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { _ in
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        let imported = try store.importData(data)
                        sessionManager.sendRoutinesToWatch()
                        importResult = imported
                        importError = nil
                    } catch {
                        importError = error.localizedDescription
                        importResult = nil
                    }
                    showingImportResult = true
                case .failure(let error):
                    importError = error.localizedDescription
                    importResult = nil
                    showingImportResult = true
                }
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = importError {
                    Text("Failed to import: \(error)")
                } else if let result = importResult {
                    Text("Added \(result.routinesAdded) routine(s) and \(result.locationsAdded) location(s).")
                }
            }
            .alert("Delete Routine", isPresented: $showingDeleteAlert, presenting: routineToDelete) { routine in
                Button("Delete", role: .destructive) {
                    store.deleteRoutine(id: routine.id)
                    sessionManager.sendRoutinesToWatch()
                }
                Button("Cancel", role: .cancel) {}
            } message: { routine in
                Text("Are you sure you want to delete \"\(routine.name)\"?")
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func routineRow(_ routine: Routine) -> some View {
        let isExpanded = routine.id == firstIncompleteId && !routine.subtasks.isEmpty

        // Parent row
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(routine.completionStatus ? .secondary : .primary)
                HStack(spacing: 8) {
                    if routine.hasScheduledTime {
                        Label(routine.scheduledTimeString, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(routine.recurrence.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !routine.subtasks.isEmpty {
                        Text("\(routine.completedSubtaskIndices.count)/\(routine.subtasks.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if routine.isDueToday() {
                completionButton(routine: routine)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingRoutine = routine
            showingEditor = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                routineToDelete = routine
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        // Subtask rows (only for the first incomplete task)
        if isExpanded {
            ForEach(routine.subtasks.indices, id: \.self) { idx in
                subtaskRow(
                    title: routine.subtasks[idx],
                    isCompleted: routine.completedSubtaskIndices.contains(idx),
                    onToggle: {
                        store.toggleSubtask(routineId: routine.id, subtaskIndex: idx)
                        sessionManager.sendRoutinesToWatch()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func completionButton(routine: Routine) -> some View {
        Button {
            if routine.completionStatus {
                // Un-complete: clear subtasks too
                store.uncompleteRoutine(routineId: routine.id)
            } else {
                store.markComplete(routineId: routine.id)
            }
            sessionManager.sendRoutinesToWatch()
        } label: {
            Image(systemName: routine.completionStatus ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(routine.completionStatus ? .green : .secondary)
                .font(.title2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subtaskRow(title: String, isCompleted: Bool, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Indent indicator
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2)
                    .padding(.leading, 8)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoutineListView()
        .environment(RoutineStore())
}
