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
    @State private var selectedSizeOption: VinylSizeOption = .twelve
    @State private var customSizeText = ""
    @State private var colorVariantsArray: [String] = []
    @State private var genresCSV = ""   // comma-separated in the UI
    @State private var notes = ""
    @State private var coverURL = ""
    @State private var selectedCoverImage: UIImage? = nil

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var savingStatus = ""
    @State private var errorAlert: String? = nil
    @State private var showingErrorAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Main") {
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    ColorVariantTagEditor(variants: $colorVariantsArray)
                }

                Section("Vinyl Size") {
                    Picker("Size", selection: $selectedSizeOption) {
                        ForEach(VinylSizeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedSizeOption == .other {
                        TextField("Size (inches)", text: $customSizeText)
                            .keyboardType(.numberPad)
                    }
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
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(artist.trimmingCharacters(in: .whitespaces).isEmpty ||
                                      album.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorAlert ?? "An unknown error occurred")
            }
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Saving changes...")
                            .font(.headline)
                        if !savingStatus.isEmpty {
                            Text(savingStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
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

            // Populate size picker from existing data
            let sizeOption = VinylSizeOption.from(size: record.size)
            selectedSizeOption = sizeOption
            if sizeOption == .other, let size = record.size {
                customSizeText = "\(size)"
            }
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
            savingStatus = "Uploading cover image..."
            do {
                finalCoverUrl = try await ImageUploadService.shared.upload(image)
            } catch {
                #if DEBUG
                print("[RecordEditView] Image upload failed: \(error)")
                #endif
                errorAlert = "Failed to upload image: \(error.localizedDescription)"
                showingErrorAlert = true
                return
            }
        }

        savingStatus = "Saving changes..."

        // Use tag editor array directly; convert genres from CSV
        let colorVariants: [String]? = colorVariantsArray.isEmpty ? nil : colorVariantsArray

        let genresArray: [String]? = genresCSV.isEmpty ? nil : genresCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Resolve vinyl size from picker
        let resolvedSize: Int? = {
            if selectedSizeOption == .other {
                return Int(customSizeText)
            }
            return selectedSizeOption.inches
        }()

        do {
            let response = try await MediaClosetAPIClient.shared.updateAlbum(
                id: recordId,
                artist: artist,
                album: album,
                year: year,
                label: nil,
                colorVariants: colorVariants,
                genres: genresArray,
                coverUrl: finalCoverUrl,
                size: resolvedSize
            )

            if response.success {
                onSaved()
                dismiss()
            } else {
                let errorMsg = response.error ?? "Unknown error"
                #if DEBUG
                print("[RecordEditView] Failed to update album: \(errorMsg)")
                #endif
                errorAlert = errorMsg
                showingErrorAlert = true
            }
        } catch {
            #if DEBUG
            print("[RecordEditView] Save error:", error)
            #endif
            errorAlert = "Failed to save: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}
