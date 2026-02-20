//
//  Views/Cassettes/CassetteDetailView.swift
//  MediaCloset
//
import SwiftUI

struct CassetteDetailView: View {
    let cassetteId: String
    @State private var cassetteJSON: [String: Any]? = nil
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let obj = cassetteJSON {
                VStack(alignment: .leading, spacing: 16) {
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
                        Text(obj["artist"] as? String ?? "")
                            .font(.title.bold())

                        Text(obj["album"] as? String ?? "")
                            .font(.title2)

                        HStack(spacing: 8) {
                            if let y = normalizedYear(from: obj["year"]) {
                                Text(y, format: .number.grouping(.never))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            if let tapeType = obj["tape_type"] as? String, !tapeType.isEmpty {
                                if obj["year"] != nil {
                                    Text("·")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(tapeType)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let label = obj["label"] as? String, !label.isEmpty {
                            Text(label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let genres = obj["genres"] as? [String], !genres.isEmpty {
                            Text(genres.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
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
            CassetteEditView(cassetteId: cassetteId) {
                Task { await load() }
            }
        }
        .task { await load() }
    }

    func load() async {
        do {
            if let cassette = try await MediaClosetAPIClient.shared.fetchCassette(id: cassetteId) {
                var dict: [String: Any] = [
                    "id": cassette.id,
                    "artist": cassette.artist,
                    "album": cassette.album
                ]
                if let year = cassette.year {
                    dict["year"] = year
                }
                if let label = cassette.label {
                    dict["label"] = label
                }
                if let genres = cassette.genres {
                    dict["genres"] = genres
                }
                if let tapeType = cassette.tapeType {
                    dict["tape_type"] = tapeType
                }
                if let coverURL = cassette.coverURL {
                    dict["cover_url"] = coverURL
                }
                cassetteJSON = dict
            }
        } catch {
            print("[CassetteDetailView] Load error:", error)
        }
    }

    private func normalizedYear(from value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String {
            let digits = s.filter(\.isNumber)
            return Int(digits)
        }
        return nil
    }
}
