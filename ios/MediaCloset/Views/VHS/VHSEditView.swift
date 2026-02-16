//
//  Views/VHS/VHSEditView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import SwiftUI

struct VHSEditView: View {
    let vhs: VHSDetail
    let onSaved: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var director: String
    @State private var year: Int?
    @State private var genre: String
    @State private var notes: String
    @State private var coverURL: String
    @State private var selectedCoverImage: UIImage? = nil
    @State private var isSaving = false
    @State private var savingStatus = ""
    @State private var errorAlert: String? = nil
    @State private var showingErrorAlert = false
    
    init(vhs: VHSDetail, onSaved: @escaping () -> Void) {
        self.vhs = vhs
        self.onSaved = onSaved
        self._title = State(initialValue: vhs.title)
        self._director = State(initialValue: vhs.director ?? "")
        self._year = State(initialValue: vhs.year)
        self._genre = State(initialValue: vhs.genre ?? "")
        self._notes = State(initialValue: vhs.notes ?? "")
        self._coverURL = State(initialValue: vhs.coverUrl ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Director", text: $director)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    TextField("Genre", text: $genre)
                }

                Section("Cover Image") {
                    CoverImagePicker(
                        existingURL: coverURL.isEmpty ? nil : coverURL,
                        selectedImage: $selectedCoverImage
                    )
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit VHS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(title.isEmpty)
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorAlert ?? "An unknown error occurred")
            }
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Saving changes...")
                            .font(.headline)
                        if !savingStatus.isEmpty {
                            Text(savingStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
    
    private func save() async {
        isSaving = true

        do {
            // Upload new cover image if selected
            var finalCoverUrl: String? = coverURL.isEmpty ? nil : coverURL
            if let image = selectedCoverImage {
                savingStatus = "Uploading cover image..."
                finalCoverUrl = try await ImageUploadService.shared.upload(image)
            }

            savingStatus = "Saving changes..."
            let response = try await MediaClosetAPIClient.shared.updateMovie(
                id: vhs.id,
                title: title,
                director: director.isEmpty ? nil : director,
                year: year,
                genre: genre.isEmpty ? nil : genre,
                coverUrl: finalCoverUrl
            )

            if response.success {
                onSaved()
                dismiss()
            } else {
                let errorMsg = response.error ?? "Unknown error"
                #if DEBUG
                print("[VHSEditView] Failed to update movie: \(errorMsg)")
                #endif
                errorAlert = errorMsg
                showingErrorAlert = true
            }
        } catch {
            #if DEBUG
            print("[VHSEditView] Update VHS error:", error)
            #endif
            errorAlert = "Failed to save: \(error.localizedDescription)"
            showingErrorAlert = true
        }

        isSaving = false
    }
}
