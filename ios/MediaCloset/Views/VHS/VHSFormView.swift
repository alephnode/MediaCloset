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
    @State private var isSaving = false
    @State private var isFetchingData = false
    @State private var showingBarcodeScanner = false
    @State private var isFetchingBarcodeData = false

    var body: some View {
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
                        Text("Looking up barcode data...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Info") {
                TextField("Title", text: $title)
                TextField("Director", text: $director)
                TextField("Year", value: $year, format: .number)
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

            Button("Save") {
                Task { await save() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(isSaving)
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Saving movie...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Fetching movie poster")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
            }
        }
        .navigationTitle(existing == nil ? "New VHS" : "Edit VHS")
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

    func save() async {
        isSaving = true

        do {
            // Use MediaCloset API to save the movie (it will auto-fetch the poster)
            let response = try await MediaClosetAPIClient.shared.saveMovie(
                title: title,
                director: director.isEmpty ? nil : director,
                year: year,
                genre: genre.isEmpty ? nil : genre,
                coverUrl: coverURL.isEmpty ? nil : coverURL
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
                #if DEBUG
                print("[VHSFormView] Save failed: \(response.error ?? "unknown error")")
                #endif
            }
        } catch {
            #if DEBUG
            print("[VHSFormView] Save error: \(error)")
            #endif
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
