//
//  Views/Cassettes/CassetteFormView.swift
//  MediaCloset
//
import SwiftUI

struct CassetteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var artist = ""
    @State private var album = ""
    @State private var year: Int? = nil
    @State private var selectedTapeType: TapeTypeOption = .standard
    @State private var genres = ""
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
                Section {
                    Button {
                        showingBarcodeScanner = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if isFetchingBarcodeData {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Looking up cassette information...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage = barcodeErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showBarcodeResult && !artist.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Cassette information found and populated")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Main") {
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Year", value: $year, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                    TextField("Genres (comma-separated)", text: $genres)
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
                    CoverImagePicker(existingURL: nil, selectedImage: $selectedCoverImage)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                        .disabled(artist.isEmpty || album.isEmpty)
                    }
                }
            }
            .navigationTitle("New Cassette")
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
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Saving cassette...")
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
    }

    func save() async {
        isSaving = true

        do {
            var coverUrl: String? = nil
            if let image = selectedCoverImage {
                savingStatus = "Uploading cover image..."
                coverUrl = try await ImageUploadService.shared.upload(image)
            }

            savingStatus = selectedCoverImage != nil ? "Saving cassette..." : "Fetching album art..."

            let genresArray: [String]? = genres.isEmpty ? nil : genres
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let response = try await MediaClosetAPIClient.shared.saveCassette(
                artist: artist,
                album: album,
                year: year,
                label: nil,
                genres: genresArray,
                coverUrl: coverUrl,
                tapeType: selectedTapeType.rawValue
            )

            if response.success {
                #if DEBUG
                print("[CassetteFormView] Cassette saved successfully")
                #endif
                onSaved()
                dismiss()
            } else {
                let errorMessage = response.error ?? "Unknown error occurred"
                #if DEBUG
                print("[CassetteFormView] Save failed: \(errorMessage)")
                #endif
                errorAlert = errorMessage
                showingErrorAlert = true
            }
        } catch {
            #if DEBUG
            print("[CassetteFormView] Save error: \(error)")
            #endif
            errorAlert = "Failed to save cassette: \(error.localizedDescription)"
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
            let albumData = try await MediaClosetAPIClient.shared.fetchCassetteByBarcode(barcode: barcode)

            guard let albumData else {
                #if DEBUG
                print("[CassetteFormView] No data found for barcode: \(barcode)")
                #endif
                await MainActor.run {
                    barcodeErrorMessage = "Cassette not found. Try entering details manually."
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
                if let fetchedGenres = albumData.genres, genres.isEmpty {
                    genres = fetchedGenres.joined(separator: ", ")
                    fieldsPopulated += 1
                }

                showBarcodeResult = fieldsPopulated > 0

                if fieldsPopulated == 0 {
                    barcodeErrorMessage = "Data found but no new information could be added to empty fields"
                }
            }
        } catch {
            #if DEBUG
            print("[CassetteFormView] Barcode lookup failed: \(error)")
            #endif
            await MainActor.run {
                barcodeErrorMessage = "Failed to fetch data: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isFetchingBarcodeData = false
        }
    }
}
