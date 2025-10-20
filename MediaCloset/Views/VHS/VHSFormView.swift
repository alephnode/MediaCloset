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

    var body: some View {
        Form {
            Section("Info") {
                TextField("Title", text: $title)
                TextField("Director", text: $director)
                TextField("Year", value: $year, format: .number)
                TextField("Genre", text: $genre)
            }

            Button("Save") {
                Task { await save() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(existing == nil ? "New VHS" : "Edit VHS")
        .onAppear {
            if let v = existing {
                title = v.title
                director = v.director ?? ""
                year = v.year
                genre = v.genre ?? ""
            }
        }
    }

    func save() async {
        let object: [String: Any] = [
            "title": title,
            "director": director.isEmpty ? NSNull() : director,
            "year": year as Any,
            "genre": genre.isEmpty ? NSNull() : genre
            // TODO add cover_url, notes, etc. later as needed
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
    }

}
