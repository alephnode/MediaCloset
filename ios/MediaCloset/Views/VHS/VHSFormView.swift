//
//  Views/VHS/VHSFormView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct VHSFormView: View {
    var existing: VHSListItem? = nil
    var onSaved: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var director = ""
    @State private var year: Int? = nil
    @State private var genre = ""
    @State private var coverURL = ""
    @State private var selectedCoverImage: UIImage? = nil
    @State private var isSaving = false
    @State private var savingStatus = ""
    @State private var isFetchingData = false
    @State private var showingBarcodeScanner = false
    @State private var isFetchingBarcodeData = false
    @State private var errorAlert: String? = nil
    @State private var showingErrorAlert = false

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
                            Text("Looking up barcode data...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Director", text: $director)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    TextField("Genre", text: $genre)
                }

                if !title.isEmpty {
                    Section {
                        Button {
                            Task { await fetchMovieData() }
                        } label: {
                            HStack(spacing: 8) {
                                if isFetchingData {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text("Auto-fill from Title")
                                    .font(.body.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isFetchingData)
                    } footer: {
                        Text("Fetches director, year, and poster based on the title.")
                    }
                }

                Section("Cover Image") {
                    CoverImagePicker(
                        existingURL: coverURL.isEmpty ? nil : coverURL,
                        selectedImage: $selectedCoverImage
                    )
                }
            }
            .navigationTitle(existing == nil ? "New VHS" : "Edit VHS")
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
                        .disabled(title.isEmpty)
                    }
                }
            }
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
            .onAppear {
                if let v = existing {
                    title = v.title
                    director = v.director ?? ""
                    year = v.year
                    genre = v.genre ?? ""
                    coverURL = v.coverUrl ?? ""
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
                        Text("Saving movie...")
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
            // Upload cover image if the user selected one
            var finalCoverUrl: String? = coverURL.isEmpty ? nil : coverURL
            if let image = selectedCoverImage {
                savingStatus = "Uploading cover image..."
                finalCoverUrl = try await ImageUploadService.shared.upload(image)
            }

            savingStatus = selectedCoverImage != nil ? "Saving movie..." : "Fetching movie poster..."

            // Use MediaCloset API to save the movie (auto-fetches poster if none provided)
            let response = try await MediaClosetAPIClient.shared.saveMovie(
                title: title,
                director: director.isEmpty ? nil : director,
                year: year,
                genre: genre.isEmpty ? nil : genre,
                coverUrl: finalCoverUrl
            )

            if response.success {
                #if DEBUG
                print("[VHSFormView] Movie saved successfully")
                if let movie = response.movie {
                    print("[VHSFormView] Saved movie: \(movie.title), coverUrl: \(movie.coverUrl ?? "none")")
                }
                #endif
                onSaved()
                dismiss()
            } else {
                // Show error from API
                let errorMessage = response.error ?? "Unknown error occurred"
                #if DEBUG
                print("[VHSFormView] Save failed: \(errorMessage)")
                #endif
                errorAlert = errorMessage
                showingErrorAlert = true
            }
        } catch {
            // Show network/connection error
            #if DEBUG
            print("[VHSFormView] Save error: \(error)")
            #endif
            errorAlert = "Failed to save movie: \(error.localizedDescription)"
            showingErrorAlert = true
        }

        isSaving = false
    }
    
    func fetchMovieData() async {
        isFetchingData = true

        do {
            let movieData = try await MediaClosetAPIClient.shared.fetchMovieByTitle(
                title: title,
                director: director.isEmpty ? nil : director,
                year: year
            )

            if let data = movieData {
                // Update fields with fetched data
                if let fetchedDirector = data.director, director.isEmpty {
                    director = fetchedDirector
                }
                if let fetchedYear = data.year, year == nil {
                    year = fetchedYear
                }
                if let fetchedPoster = data.posterURL, coverURL.isEmpty {
                    coverURL = fetchedPoster
                }

                #if DEBUG
                print("[VHSFormView] Fetched movie data from source: \(data.source ?? "unknown")")
                #endif
            }
        } catch {
            #if DEBUG
            print("[VHSFormView] Failed to fetch movie data: \(error)")
            #endif
        }

        isFetchingData = false
    }
    
    func handleBarcodeScanned(_ barcode: String) async {
        isFetchingBarcodeData = true

        // Try to look up movie data from barcode using MediaCloset API
        do {
            let movieData = try await MediaClosetAPIClient.shared.fetchMovieByBarcode(barcode: barcode)

            if let data = movieData {
                // Populate form fields with fetched data
                if let fetchedTitle = data.title, title.isEmpty {
                    title = fetchedTitle
                }
                if let fetchedDirector = data.director, director.isEmpty {
                    director = fetchedDirector
                }
                if let fetchedYear = data.year, year == nil {
                    year = fetchedYear
                }
                if let fetchedPoster = data.posterURL, coverURL.isEmpty {
                    coverURL = fetchedPoster
                }

                #if DEBUG
                print("[VHSFormView] Populated form with barcode data from source: \(data.source ?? "unknown")")
                #endif
            } else {
                #if DEBUG
                print("[VHSFormView] No movie data found for barcode: \(barcode)")
                #endif
            }
        } catch {
            // Movie barcode lookup is not yet implemented on the backend
            #if DEBUG
            print("[VHSFormView] Barcode lookup error: \(error)")
            print("[VHSFormView] Note: Movie barcode lookup is not yet implemented on the backend")
            #endif
        }

        isFetchingBarcodeData = false
    }

}
