//
//  Views/Records/RecordFormView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct RecordFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var artist = ""
    @State private var album = ""
    @State private var year: Int? = nil
    @State private var colorVariantsArray: [String] = []
    @State private var genres = ""
    @State private var tracks: [TrackRow] = []
    @State private var isSaving = false
    @State private var savingStatus = ""
    @State private var showingBarcodeScanner = false
    @State private var isFetchingBarcodeData = false
    @State private var barcodeErrorMessage: String? = nil
    @State private var showBarcodeResult = false
    @State private var errorAlert: String? = nil
    @State private var showingErrorAlert = false
    @State private var selectedCoverImage: UIImage? = nil

    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Barcode Scanner") {
                    Button("Scan Barcode") {
                        showingBarcodeScanner = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    if isFetchingBarcodeData {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Looking up album information...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let errorMessage = barcodeErrorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if showBarcodeResult && !artist.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Album information found and populated")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Cover Image") {
                    CoverImagePicker(existingURL: nil, selectedImage: $selectedCoverImage)
                }

                Section("Main") {
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Year", value: $year, formatter: NumberFormatter())
                    ColorVariantTagEditor(variants: $colorVariantsArray)
                    TextField("Genres (comma-separated)", text: $genres)
                }
                Section("Tracks") {
                    ForEach($tracks) { $row in
                        HStack {
                            TextField("#", value: $row.trackNo, formatter: NumberFormatter()).frame(width: 40)
                            TextField("Title", text: $row.title)
                            TextField("Duration sec", value: $row.durationSec, formatter: NumberFormatter()).frame(width: 120)
                        }
                    }
                    Button("Add Track") { tracks.append(TrackRow()) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                  Button("Save") { Task { await save() } }
                    .disabled(artist.isEmpty || album.isEmpty || isSaving)
                }
            }
            .navigationTitle("New Record")
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorAlert ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView { barcode in
                    Task {
                        await handleBarcodeScanned(barcode)
                    }
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Saving album...")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(savingStatus)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    func save() async {
        isSaving = true

        do {
            // Upload cover image if the user selected one
            var coverUrl: String? = nil
            if let image = selectedCoverImage {
                savingStatus = "Uploading cover image..."
                coverUrl = try await ImageUploadService.shared.upload(image)
            }

            savingStatus = selectedCoverImage != nil ? "Saving album..." : "Fetching album art..."

            // Use tag editor array directly; convert genres from CSV
            let colorVariants: [String]? = colorVariantsArray.isEmpty ? nil : colorVariantsArray

            let genresArray: [String]? = genres.isEmpty ? nil : genres
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Use MediaCloset API to save the album (auto-fetches cover if none provided)
            let response = try await MediaClosetAPIClient.shared.saveAlbum(
                artist: artist,
                album: album,
                year: year,
                label: nil,
                colorVariants: colorVariants,
                genres: genresArray,
                coverUrl: coverUrl
            )

            if response.success {
                #if DEBUG
                print("[RecordFormView] Album saved successfully")
                if let album = response.album {
                    print("[RecordFormView] Saved album: \(album.artist) - \(album.album), coverUrl: \(album.coverUrl ?? "none")")
                }
                #endif

                // TODO: Handle tracks separately - they're not part of the saveAlbum mutation yet
                // For now, we're just saving the album without tracks
                if !tracks.isEmpty {
                    print("[RecordFormView] Warning: Tracks are not yet supported in saveAlbum mutation")
                }

                onSaved()
                dismiss()
            } else {
                // Show error from API
                let errorMessage = response.error ?? "Unknown error occurred"
                #if DEBUG
                print("[RecordFormView] Save failed: \(errorMessage)")
                #endif
                errorAlert = errorMessage
                showingErrorAlert = true
            }
        } catch {
            // Show network/connection error
            #if DEBUG
            print("[RecordFormView] Save error: \(error)")
            #endif
            errorAlert = "Failed to save album: \(error.localizedDescription)"
            showingErrorAlert = true
        }

        isSaving = false
    }
    
    func handleBarcodeScanned(_ barcode: String) async {
        await MainActor.run {
            isFetchingBarcodeData = true
            barcodeErrorMessage = nil
            showBarcodeResult = false
        }

        do {
            let albumData = try await MediaClosetAPIClient.shared.fetchAlbumByBarcode(barcode: barcode)

            guard let albumData else {
                #if DEBUG
                print("[RecordFormView] No album data found for barcode: \(barcode)")
                #endif
                await MainActor.run {
                    barcodeErrorMessage = "Album not found in MediaCloset. Try entering details manually."
                }
                return
            }

            await MainActor.run {
                var fieldsPopulated = 0

                if let fetchedArtist = albumData.artist, artist.isEmpty {
                    artist = fetchedArtist
                    fieldsPopulated += 1
                }
                if let fetchedAlbum = albumData.album, album.isEmpty {
                    album = fetchedAlbum
                    fieldsPopulated += 1
                }
                if let fetchedYear = albumData.year, year == nil {
                    year = fetchedYear
                    fieldsPopulated += 1
                }
                // Note: barcode lookup doesn't provide color variant info
                if let fetchedGenres = albumData.genres, genres.isEmpty {
                    genres = fetchedGenres.joined(separator: ", ")
                    fieldsPopulated += 1
                }

                showBarcodeResult = fieldsPopulated > 0

                if fieldsPopulated == 0 {
                    barcodeErrorMessage = "Album found but no new information could be added to empty fields"
                }
            }

            #if DEBUG
            print("[RecordFormView] Populated form from MediaCloset API barcode lookup (source: \(albumData.source ?? "unknown"))")
            print("  Artist: \(albumData.artist ?? "nil")")
            print("  Album: \(albumData.album ?? "nil")")
            print("  Year: \(albumData.year?.description ?? "nil")")
            print("  Label: \(albumData.label ?? "nil")")
            print("  Genres: \(albumData.genres?.joined(separator: ", ") ?? "nil")")
            #endif
        } catch {
            #if DEBUG
            print("[RecordFormView] Barcode lookup failed: \(error)")
            #endif
            await MainActor.run {
                barcodeErrorMessage = "Failed to fetch album: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isFetchingBarcodeData = false
        }
    }

}
