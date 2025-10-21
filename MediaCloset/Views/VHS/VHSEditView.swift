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
    @State private var isFetchingData = false
    
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
                    Button("Fetch Movie Data") {
                        Task { await fetchMovieData() }
                    }
                    .disabled(title.isEmpty || isFetchingData)
                    if isFetchingData {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Fetching movie data...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
        
        // Fetch movie poster URL from OMDB if coverURL is empty (with 3-second timeout)
        var finalCoverURL = coverURL
        if finalCoverURL.isEmpty {
            finalCoverURL = await OMDBService.fetchMoviePosterURL(
                title: title,
                director: director.isEmpty ? nil : director,
                year: year,
                timeout: 3.0
            ) ?? ""
        }
        
        let object: [String: Any] = [
            "title": title,
            "director": director.isEmpty ? NSNull() : director,
            "year": year as Any,
            "genre": genre.isEmpty ? NSNull() : genre,
            "notes": notes.isEmpty ? NSNull() : notes,
            "cover_url": finalCoverURL.isEmpty ? NSNull() : finalCoverURL
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
        
        isSaving = false
    }
    
    private func fetchMovieData() async {
        isFetchingData = true
        
        let movieData = await OMDBService.fetchMovieData(
            title: title,
            director: director.isEmpty ? nil : director,
            year: year
        )
        
        if let data = movieData {
            // Update fields with fetched data
            if let fetchedDirector = data["Director"] as? String, director.isEmpty {
                director = fetchedDirector
            }
            if let fetchedYear = data["Year"] as? String, year == nil {
                year = Int(fetchedYear)
            }
            if let fetchedGenre = data["Genre"] as? String, genre.isEmpty {
                genre = fetchedGenre
            }
            if let fetchedPoster = data["Poster"] as? String, coverURL.isEmpty {
                coverURL = fetchedPoster
            }
        }
        
        isFetchingData = false
    }
}
