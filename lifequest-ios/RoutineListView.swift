
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.routines) { routine in
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
                    Button {
                        editingRoutine = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
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

    @ViewBuilder
    private func routineRow(_ routine: Routine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    if routine.hasScheduledTime {
                        Label(routine.scheduledTimeString, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(routine.recurrence.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if routine.isDueToday() {
                Image(systemName: routine.completionStatus ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(routine.completionStatus ? .green : .secondary)
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
    }
}

#Preview {
    RoutineListView()
        .environment(RoutineStore())
}
