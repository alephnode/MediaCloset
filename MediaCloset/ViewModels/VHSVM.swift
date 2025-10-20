//
//  ViewModels/VHSVM.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation

@MainActor
final class VHSVM: ObservableObject {
    @Published var items: [VHSListItem] = []
    @Published var search = ""
    @Published var isLoading = false

    func load() async {
        isLoading = true; defer { isLoading = false }

        // Always provide a non-nil string for $pattern
        let pattern = search.isEmpty ? "%%" : "%\(search)%"

        let vars: [String: Any] = [
            "pattern": pattern,
            "limit": 50,
            "offset": 0
        ]

        do {
            let res = try await GraphQLHTTPClient.shared.execute(
                operationName: "VHSList",
                query: GQL.queryVHSList,
                variables: vars
            )

            guard let rows = res.data?["vhs"] as? [[String: Any]] else { return }

            self.items = rows.map { r in
                VHSListItem(
                    id: r["id"] as? String ?? UUID().uuidString,
                    title: r["title"] as? String ?? "",
                    director: (r["director"] as? String) ?? "",
                    year: r["year"] as? Int,
                    genre: r["genre"] as? String,
                    coverUrl: r["cover_url"] as? String
                )
            }
        } catch {
            print("VHS fetch error:", error)
        }
    }

    func delete(id: String) async {
        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "DeleteVHS",
                query: GQL.deleteVHS,
                variables: ["id": id]
            )
            self.items.removeAll { $0.id == id }
        } catch {
            print("Delete VHS error:", error)
        }
    }
}
