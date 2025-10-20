//
//  ViewModels/RecordsVM.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation

@MainActor
final class RecordsVM: ObservableObject {
    @Published var items: [RecordListItem] = []
    @Published var search = ""
    @Published var isLoading = false

    func load() async {
        isLoading = true; defer { isLoading = false }

        // Always send a non-null pattern; "%%" matches all
        let pattern = search.isEmpty ? "%%" : "%\(search)%"

        let vars: [String: Any] = [
            "pattern": pattern as String,
            "limit": 50 as Int,
            "offset": 0 as Int
        ]

        do {
            let res = try await GraphQLHTTPClient.shared.execute(
                operationName: "Records",
                query: GQL.queryRecords,
                variables: vars
            )
            guard let rows = res.data?["records"] as? [[String: Any]] else { return }
            items = rows.map { r in
                RecordListItem(
                    id: r["id"] as? String ?? UUID().uuidString,
                    artist: r["artist"] as? String ?? "",
                    album: r["album"] as? String ?? "",
                    year: r["year"] as? Int,
                    colorVariant: r["color_variant"] as? String,
                    genres: r["genres"] as? [String] ?? [],
                    coverUrl: r["cover_url"] as? String
                )
            }
        } catch {
            print("Records fetch error:", error)
        }
    }


    func delete(id: String) async {
        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "DeleteRecord",
                query: GQL.deleteRecord,
                variables: ["id": id] as [String: Any]
            )
            items.removeAll { $0.id == id }
        } catch {
            print("Delete error:", error)
        }
    }
}

