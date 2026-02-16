//
//  Services/ImageUploadService.swift
//  MediaCloset
//
//  Handles compressing and uploading cover images to S3 via presigned URLs.
//

import UIKit

enum ImageUploadError: LocalizedError {
    case compressionFailed
    case uploadFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed(let code):
            return "Upload failed with status \(code)"
        case .invalidResponse:
            return "Invalid response from upload"
        }
    }
}

/// Compresses, uploads images to S3 via presigned URLs, and returns the public URL.
final class ImageUploadService {
    static let shared = ImageUploadService()
    private init() {}

    private let maxBytes = 500 * 1024 // 500 KB target
    private let maxDimension: CGFloat = 1200

    /// Uploads a UIImage to S3 and returns the permanent public URL.
    /// The image is resized to max 1200px and compressed to JPEG under 500 KB.
    func upload(_ image: UIImage) async throws -> String {
        let resized = resize(image, maxDimension: maxDimension)

        guard let data = compressToJPEG(resized, maxBytes: maxBytes) else {
            throw ImageUploadError.compressionFailed
        }

        #if DEBUG
        print("[ImageUploadService] Compressed image: \(data.count) bytes (\(data.count / 1024) KB)")
        #endif

        let uploadInfo = try await MediaClosetAPIClient.shared.requestImageUploadURL(contentType: "image/jpeg")

        guard let uploadURL = URL(string: uploadInfo.uploadUrl) else {
            throw ImageUploadError.invalidResponse
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageUploadError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ImageUploadError.uploadFailed(statusCode: httpResponse.statusCode)
        }

        #if DEBUG
        print("[ImageUploadService] Upload successful: \(uploadInfo.imageUrl)")
        #endif

        return uploadInfo.imageUrl
    }

    // MARK: - Private Helpers

    /// Resizes an image so neither dimension exceeds the given limit.
    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Progressively lowers JPEG quality to fit under the byte limit.
    private func compressToJPEG(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.85
        while quality >= 0.1 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }
        // Last resort: lowest quality
        return image.jpegData(compressionQuality: 0.1)
    }
}
