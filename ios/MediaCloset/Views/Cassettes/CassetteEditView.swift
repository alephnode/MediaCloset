//
//  Views/Cassettes/CassetteEditView.swift
//  MediaCloset
//
import SwiftUI

struct CassetteEditView: View {
    let cassetteId: String
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var artist = ""
    @State private var album = ""
    @State private var year: Int? = nil
    @State private var selectedTapeType: TapeTypeOption = .standard
    @State private var genresCSV = ""
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
                }

                Section("Tape Type") {
                    Picker("Type", selection: $selectedTapeType) {
                        ForEach(TapeTypeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Cover Image") {
                    CoverImagePicker(existingURL: coverURL.isEmpty ? nil : coverURL, selectedImage: $selectedCoverImage)
                }

                Section("Metadata") {
                    TextField("Genres (comma-separated)", text: $genresCSV)
                }
            }
            .disabled(isLoading || isSaving)
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle("Edit Cassette")
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

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let cassette = try await MediaClosetAPIClient.shared.fetchCassette(id: cassetteId) else {
                print("[CassetteEditView] Cassette not found")
                return
            }
            artist = cassette.artist
            album = cassette.album
            year = cassette.year
            coverURL = cassette.coverURL ?? ""

            if let tapeType = cassette.tapeType {
                selectedTapeType = TapeTypeOption.allCases.first { $0.rawValue == tapeType } ?? .standard
            }
            if let genres = cassette.genres {
                genresCSV = genres.joined(separator: ", ")
            }
        } catch {
            print("[CassetteEditView] Load error:", error)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var finalCoverUrl: String? = coverURL.isEmpty ? nil : coverURL
        if let image = selectedCoverImage {
            savingStatus = "Uploading cover image..."
            do {
                finalCoverUrl = try await ImageUploadService.shared.upload(image)
            } catch {
                #if DEBUG
                print("[CassetteEditView] Image upload failed: \(error)")
                #endif
                errorAlert = "Failed to upload image: \(error.localizedDescription)"
                showingErrorAlert = true
                return
            }
        }

        savingStatus = "Saving changes..."

        let genresArray: [String]? = genresCSV.isEmpty ? nil : genresCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            let response = try await MediaClosetAPIClient.shared.updateCassette(
                id: cassetteId,
                artist: artist,
                album: album,
                year: year,
                label: nil,
                genres: genresArray,
                coverUrl: finalCoverUrl,
                tapeType: selectedTapeType.rawValue
            )

            if response.success {
                onSaved()
                dismiss()
            } else {
                let errorMsg = response.error ?? "Unknown error"
                #if DEBUG
                print("[CassetteEditView] Failed to update cassette: \(errorMsg)")
                #endif
                errorAlert = errorMsg
                showingErrorAlert = true
            }
        } catch {
            #if DEBUG
            print("[CassetteEditView] Save error:", error)
            #endif
            errorAlert = "Failed to save: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}
