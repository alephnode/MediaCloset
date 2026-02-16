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
    @State private var colorVariantsArray: [String] = []
    @State private var genresCSV = ""   // comma-separated in the UI
    @State private var notes = ""
    @State private var coverURL = ""
    @State private var selectedCoverImage: UIImage? = nil

    @State private var isLoading = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Main") {
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                    ColorVariantTagEditor(variants: $colorVariantsArray)
                }
                Section("Cover Image") {
                    CoverImagePicker(existingURL: coverURL.isEmpty ? nil : coverURL, selectedImage: $selectedCoverImage)
                }

                Section("Metadata") {
                    TextField("Genres (comma-separated)", text: $genresCSV)
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

    // Load current values from MediaCloset API
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let record = try await MediaClosetAPIClient.shared.fetchAlbum(id: recordId) else {
                print("[RecordEditView] Album not found")
                return
            }
            artist = record.artist
            album  = record.album
            year   = record.year
            colorVariantsArray = record.colorVariants ?? []
            coverURL = record.coverURL ?? ""
            notes = "" // Not returned by API
            if let genres = record.genres {
                genresCSV = genres.joined(separator: ", ")
            }
        } catch {
            print("[RecordEditView] Load error:", error)
        }
    }

    // Save updates using MediaCloset API
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // Upload new cover image if selected
        var finalCoverUrl: String? = coverURL.isEmpty ? nil : coverURL
        if let image = selectedCoverImage {
            do {
                finalCoverUrl = try await ImageUploadService.shared.upload(image)
            } catch {
                print("[RecordEditView] Image upload failed: \(error)")
                return
            }
        }

        // Use tag editor array directly; convert genres from CSV
        let colorVariants: [String]? = colorVariantsArray.isEmpty ? nil : colorVariantsArray

        let genresArray: [String]? = genresCSV.isEmpty ? nil : genresCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            let response = try await MediaClosetAPIClient.shared.updateAlbum(
                id: recordId,
                artist: artist,
                album: album,
                year: year,
                label: nil, // Not editable in this view
                colorVariants: colorVariants,
                genres: genresArray,
                coverUrl: finalCoverUrl
            )

            if response.success {
                onSaved()
                dismiss()
            } else {
                let errorMsg = response.error ?? "Unknown error"
                print("[RecordEditView] Failed to update album: \(errorMsg)")
            }
        } catch {
            print("[RecordEditView] Save error:", error)
        }
    }
}
