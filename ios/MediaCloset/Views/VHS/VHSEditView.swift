//
//  Views/VHS/VHSEditView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import SwiftUI

struct VHSEditView: View {
    let vhs: VHSDetail
    let onSaved: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var director: String
    @State private var year: Int?
    @State private var genre: String
    @State private var notes: String
    @State private var coverURL: String
    @State private var isSaving = false
    
    init(vhs: VHSDetail, onSaved: @escaping () -> Void) {
        self.vhs = vhs
        self.onSaved = onSaved
        self._title = State(initialValue: vhs.title)
        self._director = State(initialValue: vhs.director ?? "")
        self._year = State(initialValue: vhs.year)
        self._genre = State(initialValue: vhs.genre ?? "")
        self._notes = State(initialValue: vhs.notes ?? "")
        self._coverURL = State(initialValue: vhs.coverUrl ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Title", text: $title)
                    TextField("Director", text: $director)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                    TextField("Genre", text: $genre)
                }

                Section("Cover Art") {
                    TextField("Cover URL (optional)", text: $coverURL)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit VHS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true

        do {
            let response = try await MediaClosetAPIClient.shared.updateMovie(
                id: vhs.id,
                title: title,
                director: director.isEmpty ? nil : director,
                year: year,
                genre: genre.isEmpty ? nil : genre,
                coverUrl: coverURL.isEmpty ? nil : coverURL
            )

            if response.success {
                onSaved()
                dismiss()
            } else {
                let errorMsg = response.error ?? "Unknown error"
                print("[VHSEditView] Failed to update movie: \(errorMsg)")
            }
        } catch {
            print("[VHSEditView] Update VHS error:", error)
        }

        isSaving = false
    }
}
