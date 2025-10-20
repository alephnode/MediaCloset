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

    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
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
                    .disabled(artist.isEmpty || album.isEmpty)
                }
            }
            .navigationTitle("New Record")
        }
    }

    func save() async {
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
            // TODO add optional fields
            // "cover_url": NSNull(),
            // "notes": NSNull(),
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
    }


}
