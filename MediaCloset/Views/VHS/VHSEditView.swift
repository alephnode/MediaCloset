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
    
    init(vhs: VHSDetail, onSaved: @escaping () -> Void) {
        self.vhs = vhs
        self.onSaved = onSaved
        self._title = State(initialValue: vhs.title)
        self._director = State(initialValue: vhs.director ?? "")
        self._year = State(initialValue: vhs.year)
        self._genre = State(initialValue: vhs.genre ?? "")
        self._notes = State(initialValue: vhs.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Title", text: $title)
                    TextField("Director", text: $director)
                    TextField("Year", value: $year, format: .number)
                    TextField("Genre", text: $genre)
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
                        .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func save() async {
        let object: [String: Any] = [
            "title": title,
            "director": director.isEmpty ? NSNull() : director,
            "year": year as Any,
            "genre": genre.isEmpty ? NSNull() : genre,
            "notes": notes.isEmpty ? NSNull() : notes
        ]
        
        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "UpdateVHS",
                query: GQL.updateVHS,
                variables: [
                    "id": vhs.id,
                    "set": object
                ]
            )
            onSaved()
            dismiss()
        } catch {
            print("Update VHS error:", error)
        }
    }
}
