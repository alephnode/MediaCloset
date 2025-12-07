//
//  Views/Components/AsyncCover.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct AsyncCover: View {
    let url: String?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15))
            if let url, let u = URL(string: url) {
                CachedAsyncImage(url: u) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").imageScale(.large)
                    }
                }
            } else {
                Image(systemName: "photo").imageScale(.large)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
