//
//  Views/Components/CachedAsyncImage.swift
//  MediaCloset
//
//  A drop-in replacement for AsyncImage that uses ImageCache for persistent caching
//

import SwiftUI

/// Loading state for cached image
enum CachedImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

/// A view that asynchronously loads and displays an image with caching
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (CachedImagePhase) -> Content
    
    @State private var phase: CachedImagePhase = .empty
    
    init(url: URL?, @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }
    
    private func loadImage() async {
        phase = .empty
        
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }
        
        if let uiImage = await ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: uiImage))
        } else {
            phase = .failure(URLError(.cannotLoadFromNetwork))
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == _ConditionalContent<_ConditionalContent<ProgressView<EmptyView, EmptyView>, Image>, Image> {
    /// Convenience initializer with default placeholder and error views
    init(url: URL?) {
        self.init(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable()
            case .failure:
                Image(systemName: "photo")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CachedAsyncImage(url: URL(string: "https://example.com/image.jpg")) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 200, height: 200)
    }
}
