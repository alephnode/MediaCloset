//
//  Views/Records/RecordEditView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct RecordEditView: View {
    let recordId: String
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // Editable fields
    @State private var artist = ""
    @State private var album = ""
    @State private var year: Int? = nil
    @State private var colorVariant = ""
    @State private var genresCSV = ""   // comma-separated in the UI
    @State private var notes = ""
    @State private var coverURL = ""

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isFetchingArt = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Main") {
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                    TextField("Color variant", text: $colorVariant)
                }
                Section("Metadata") {
                    TextField("Genres (comma-separated)", text: $genresCSV)
                    HStack {
                        TextField("Cover URL (optional)", text: $coverURL)
                        Button("Fetch Art") {
                            Task { await fetchAlbumArt() }
                        }
                        .disabled(artist.isEmpty || album.isEmpty || isFetchingArt)
                        if isFetchingArt {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .disabled(isLoading || isSaving)
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle("Edit Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(artist.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  album.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .task { await load() }
    }
    
    private func fetchAlbumArt() async {
        guard !artist.isEmpty && !album.isEmpty else { return }
        
        isFetchingArt = true
        defer { isFetchingArt = false }
        
        if let coverUrl = await MusicBrainzService.fetchAlbumArtURL(
            artist: artist,
            album: album,
            timeout: 3.0
        ) {
            coverURL = coverUrl
        }
    }

    // Load current values from Hasura
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await GraphQLHTTPClient.shared.execute(
                operationName: "Record",
                query: GQL.recordDetail,
                variables: ["id": recordId]
            )
            guard let r = res.data?["records_by_pk"] as? [String: Any] else { return }
            artist = (r["artist"] as? String) ?? ""
            album  = (r["album"] as? String) ?? ""
            year   = r["year"] as? Int
            colorVariant = (r["color_variant"] as? String) ?? ""
            coverURL = (r["cover_url"] as? String) ?? ""
            notes   = (r["notes"] as? String) ?? ""
            if let arr = r["genres"] as? [String] { genresCSV = arr.joined(separator: ", ") }
        } catch {
            print("edit load err:", error)
        }
    }

    // Save updates using Hasura's _set
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let trimmedGenres = genresCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var set: [String: Any] = [
            "artist": artist,
            "album": album,
            "year": year as Any,
            "genres": trimmedGenres
        ]
        // Only send optional fields if user provided something
        set["color_variant"] = colorVariant.isEmpty ? NSNull() : colorVariant
        set["notes"] = notes.isEmpty ? NSNull() : notes
        set["cover_url"] = coverURL.isEmpty ? NSNull() : coverURL

        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "UpdateRecord",
                query: GQL.updateRecord,
                variables: ["id": recordId, "set": set]
            )
            onSaved()
            dismiss()
        } catch {
            print("edit save err:", error)
        }
    }
}
