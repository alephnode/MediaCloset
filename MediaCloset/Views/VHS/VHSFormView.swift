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

    var body: some View {
        Form {
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
            "cover_url": finalCoverURL.isEmpty ? NSNull() : finalCoverURL
        ]

        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "InsertVHS",
                query: GQL.insertVHS,
                variables: ["object": object]
            )
            onSaved()
            dismiss()
        } catch {
            print("save VHS error:", error)
        }
        
        isSaving = false
    }
    
    func fetchMovieData() async {
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
