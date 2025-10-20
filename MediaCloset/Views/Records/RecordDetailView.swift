//
//  Views/Records/RecordDetailView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct RecordDetailView: View {
    let recordId: String
    @State private var recordJSON: [String: Any]? = nil
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let obj = recordJSON {
                VStack(alignment: .leading, spacing: 12) {
                    AsyncCover(url: obj["cover_url"] as? String)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("\(obj["artist"] as? String ?? "")")
                        .font(.title.bold())
                    
                    Text("\(obj["album"] as? String ?? "")")

                    if let y = normalizedYear(from: obj["year"]) {
                        // fixes formatting with commas
                        Text(y, format: .number.grouping(.never))
                            .font(.headline)
                    }

                    if let genres = obj["genres"] as? [String], !genres.isEmpty {
                        Text(genres.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let notes = obj["notes"] as? String, !notes.isEmpty {
                        Text(notes)
                    }

                    if let tracks = obj["tracks"] as? [[String: Any]], !tracks.isEmpty {
                        Divider()
                        Text("Tracks").font(.headline)

                        // Sort then enumerate so we have a stable Identifiable key (offset)
                        let sorted = tracks.sorted {
                            ( $0["track_no"] as? Int ?? 0 ) < ( $1["track_no"] as? Int ?? 0 )
                        }

                        ForEach(Array(sorted.enumerated()), id: \.offset) { _, t in
                            HStack {
                                Text("\(t["track_no"] as? Int ?? 0).").bold()
                                Text(t["title"] as? String ?? "")
                                Spacer()
                                if let d = t["duration_sec"] as? Int {
                                    Text("\(d/60):\(String(format: "%02d", d%60))")
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            RecordEditView(recordId: recordId) {
                Task { await load() }   // refresh after saving
            }
        }
        .task { await load() }
    }

    func load() async {
        do {
            let res = try await GraphQLHTTPClient.shared.execute(
                operationName: "Record",
                query: GQL.recordDetail,
                variables: ["id": recordId]
            )
            if let dict = res.data?["records_by_pk"] as? [String: Any] {
                recordJSON = dict
            }
        } catch { print("detail err", error) }
    }

    // helper to coerce whatever we get into a plain Int year
    private func normalizedYear(from value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String {
            let digits = s.filter(\.isNumber)   // strips commas, spaces, etc.
            return Int(digits)
        }
        return nil
    }

}
