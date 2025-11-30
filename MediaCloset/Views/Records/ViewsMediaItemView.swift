//
//  Views/MediaItemView.swift
//  MediaCloset
//
//  Example usage of MediaImageService
//

import SwiftUI

struct MediaItemView: View {
    let mediaItem: MediaItem
    @StateObject private var imageService = MediaImageService()
    @State private var coverImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: mediaItem.coverImageURL ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                            }
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure(_):
                    Rectangle()
                        .fill(.red.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading) {
                Text(mediaItem.title)
                    .font(.headline)
                Text(mediaItem.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .task {
            if mediaItem.coverImageURL?.isEmpty != false {
                await fetchCoverImage()
            }
        }
    }
    
    private func fetchCoverImage() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            coverImage = try await imageService.fetchCoverImage(for: mediaItem)
        } catch {
            print("Failed to fetch cover image: \(error)")
        }
    }
}