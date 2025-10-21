//
//  Views/VHS/VHSDetailView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import SwiftUI

struct VHSDetailView: View {
    let vhsId: String
    @State private var vhs: VHSDetail? = nil
    @State private var isLoading = true
    @State private var showingEdit = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let vhs = vhs {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Large cover art spanning across the view with padding
                        if let coverUrl = vhs.coverUrl {
                            AsyncImage(url: URL(string: coverUrl)) { phase in
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
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                        }
                        
                        // Title
                        Text(vhs.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                        
                        // Details
                        VStack(alignment: .leading, spacing: 8) {
                            if let director = vhs.director {
                                DetailRow(label: "Director", value: director)
                            }
                            
                            if let year = vhs.year {
                                DetailRow(label: "Year", value: String(year))
                            }
                            
                            if let genre = vhs.genre {
                                DetailRow(label: "Genre", value: genre)
                            }
                            
                            if let notes = vhs.notes, !notes.isEmpty {
                                DetailRow(label: "Notes", value: notes)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .padding()
                }
            } else {
                Text("VHS not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("VHS Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let vhs = vhs {
                VHSEditView(vhs: vhs) {
                    Task { await loadVHS() }
                }
            }
        }
        .task {
            await loadVHS()
        }
    }
    
    private func loadVHS() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await GraphQLHTTPClient.shared.execute(
                operationName: "VHSDetail",
                query: GQL.vhsDetail,
                variables: ["id": vhsId]
            )
            
            if let data = response.data?["vhs_by_pk"] as? [String: Any] {
                vhs = VHSDetail(from: data)
            }
        } catch {
            print("Error loading VHS detail:", error)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct VHSDetail {
    let id: String
    let title: String
    let director: String?
    let year: Int?
    let genre: String?
    let coverUrl: String?
    let notes: String?
    
    init(from data: [String: Any]) {
        self.id = data["id"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.director = data["director"] as? String
        self.year = data["year"] as? Int
        self.genre = data["genre"] as? String
        self.coverUrl = data["cover_url"] as? String
        self.notes = data["notes"] as? String
    }
}
