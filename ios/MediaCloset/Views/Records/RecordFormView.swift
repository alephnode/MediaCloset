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
    @State private var color = ""
    @State private var genres = ""
    @State private var tracks: [TrackRow] = []
    @State private var isSaving = false
    @State private var showingBarcodeScanner = false
    @State private var isFetchingBarcodeData = false
    @State private var barcodeErrorMessage: String? = nil
    @State private var showBarcodeResult = false

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
                
                Section("Main") {
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Year", value: $year, formatter: NumberFormatter())
                    TextField("Color variant (e.g. Clear)", text: $color)
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
                            Text("Fetching album art")
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
        
        // Fetch album art URL from MusicBrainz (with 3-second timeout)
        let coverUrl = await MusicBrainzService.fetchAlbumArtURL(
            artist: artist,
            album: album,
            timeout: 3.0
        )
        
        // Map UI -> snake_case object for Hasura
        let trackObjects: [[String: Any]]? = tracks.isEmpty ? nil : tracks.map {
            [
                "title": $0.title,
                "duration_sec": $0.durationSec as Any,
                "track_no": $0.trackNo as Any
            ]
        }

        let object: [String: Any] = [
            "artist": artist,
            "album": album,
            "year": year as Any,
            "color_variant": color.isEmpty ? NSNull() : color,
            "genres": genres
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) },
            "cover_url": coverUrl ?? NSNull(),
            // Nested tracks insert
            "tracks": trackObjects == nil ? NSNull() : [ "data": trackObjects! ]
        ]

        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "InsertRecord",
                query: GQL.insertRecord,
                variables: ["object": object]
            )
            onSaved()
            dismiss()
        } catch {
            print("save err", error)
        }
        
        isSaving = false
    }
    
    func handleBarcodeScanned(_ barcode: String) async {
        await MainActor.run {
            isFetchingBarcodeData = true
            barcodeErrorMessage = nil
            showBarcodeResult = false
        }
        
        // Use improved barcode service for better music data
        if let albumData = await ImprovedBarcodeService.lookupAlbumByBarcode(barcode) {
            // Populate form fields with structured data
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
                if let fetchedLabel = albumData.label, color.isEmpty {
                    color = fetchedLabel // Using color field for label info
                    fieldsPopulated += 1
                }
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
            print("[RecordFormView] Populated form with improved barcode data:")
            print("  Artist: \(albumData.artist ?? "nil")")
            print("  Album: \(albumData.album ?? "nil")")
            print("  Year: \(albumData.year?.description ?? "nil")")
            print("  Label: \(albumData.label ?? "nil")")
            print("  Genres: \(albumData.genres?.joined(separator: ", ") ?? "nil")")
            #endif
        } else {
            #if DEBUG
            print("[RecordFormView] No album data found for barcode: \(barcode)")
            #endif
            
            await MainActor.run {
                barcodeErrorMessage = "Album not found in music databases. Try entering details manually."
            }
        }
        
        await MainActor.run {
            isFetchingBarcodeData = false
        }
    }

}
