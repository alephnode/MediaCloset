//
//  Views/Components/CoverImagePicker.swift
//  MediaCloset
//
//  Reusable component for selecting a cover image from the camera or photo library.
//

import SwiftUI
import PhotosUI

/// A component that displays the current cover image and provides options to
/// take a new photo, choose from the library, or remove the current image.
struct CoverImagePicker: View {
    /// The existing cover URL (from the database). Shown when no new image is selected.
    let existingURL: String?

    /// The newly selected image (not yet uploaded). Nil means no change from existing.
    @Binding var selectedImage: UIImage?

    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    private var hasImage: Bool {
        selectedImage != nil || (existingURL != nil && !existingURL!.isEmpty)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                } else if let existingURL, !existingURL.isEmpty, let url = URL(string: existingURL) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure:
                            placeholderContent
                        }
                    }
                } else {
                    placeholderContent
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                showingActionSheet = true
            }

            // Actions
            HStack(spacing: 12) {
                Button {
                    showingActionSheet = true
                } label: {
                    Label(hasImage ? "Change Photo" : "Add Photo", systemImage: "camera")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                if hasImage {
                    Button(role: .destructive) {
                        selectedImage = nil
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingActionSheet) {
            Button("Take Photo") {
                showingCamera = true
            }

            Button("Choose from Library") {
                showingPhotoPicker = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(image: $selectedImage)
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = uiImage
                    }
                }
            }
        }
    }

    private var placeholderContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Tap to add a cover image")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Camera UIKit Wrapper

/// UIImagePickerController wrapper for taking photos with the camera.
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
