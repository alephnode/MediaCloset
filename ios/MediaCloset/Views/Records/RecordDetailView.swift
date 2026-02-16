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
                VStack(alignment: .leading, spacing: 16) {
                    // Large album art spanning across the view with padding
                    Spacer().frame(height: 8)
                    CachedAsyncImage(url: URL(string: obj["cover_url"] as? String ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.15))
                                    .aspectRatio(1, contentMode: .fit)
                                ProgressView()
                                    .scaleEffect(1.5)
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.15))
                                    .aspectRatio(1, contentMode: .fit)
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(obj["artist"] as? String ?? "")")
                            .font(.title.bold())
                        
                        Text("\(obj["album"] as? String ?? "")")
                            .font(.title2)

                        HStack(spacing: 8) {
                            if let y = normalizedYear(from: obj["year"]) {
                                Text(y, format: .number.grouping(.never))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            if let size = obj["size"] as? Int {
                                Text("·")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("\(size)\"")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                if let genres = obj["genres"] as? [String], !genres.isEmpty {
                    Text(genres.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let colorVariants = obj["color_variants"] as? [String], !colorVariants.isEmpty {
                    WrappingHStack(spacing: 6) {
                        ForEach(colorVariants, id: \.self) { variant in
                            ColorVariantBadge(variant: variant)
                        }
                    }
                }

                if let notes = obj["notes"] as? String, !notes.isEmpty {
                    Text(notes)
                        .padding(.top, 8)
                }
                    }
                    .padding(.horizontal, 16)

                    if let tracks = obj["tracks"] as? [[String: Any]], !tracks.isEmpty {
                        Divider()
                            .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tracks").font(.headline)
                                .padding(.horizontal, 16)

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
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
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
            if let album = try await MediaClosetAPIClient.shared.fetchAlbum(id: recordId) {
                // Convert Album to dictionary format for the view
                var dict: [String: Any] = [
                    "id": album.id,
                    "artist": album.artist,
                    "album": album.album
                ]
                if let year = album.year {
                    dict["year"] = year
                }
                if let label = album.label {
                    dict["label"] = label
                }
                if let genres = album.genres {
                    dict["genres"] = genres
                }
                if let colorVariants = album.colorVariants {
                    dict["color_variants"] = colorVariants
                }
                if let size = album.size {
                    dict["size"] = size
                }
                if let coverURL = album.coverURL {
                    dict["cover_url"] = coverURL
                }
                if let createdAt = album.createdAt {
                    dict["created_at"] = createdAt
                }
                if let updatedAt = album.updatedAt {
                    dict["updated_at"] = updatedAt
                }
                recordJSON = dict
            }
        } catch {
            print("[RecordDetailView] Load error:", error)
        }
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
