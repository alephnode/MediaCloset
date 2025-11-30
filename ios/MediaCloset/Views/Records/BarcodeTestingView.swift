//
//  Testing/BarcodeTestingView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 11/16/25.
//

import SwiftUI

struct BarcodeTestingView: View {
    @State private var testBarcode = "602537988334" // Example UPC for testing
    @State private var isLookingUp = false
    @State private var results: String = "No results yet"
    
    // Some common music UPCs for testing
    private let testBarcodes = [
        "602537988334", // Example album UPC
        "075021029811", // Another example
        "093624945093", // Another example
        "888837723329", // Another example
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Text("Barcode API Testing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Barcode:")
                        .font(.headline)
                    
                    TextField("Enter barcode (UPC/EAN)", text: $testBarcode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    
                    // Quick select buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(testBarcodes, id: \.self) { barcode in
                                Button(barcode) {
                                    testBarcode = barcode
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Button(action: testLookup) {
                    HStack {
                        if isLookingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLookingUp ? "Looking up..." : "Test Barcode Lookup")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLookingUp || testBarcode.isEmpty)
                
                ScrollView {
                    Text(results)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Barcode Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testLookup() {
        Task {
            await MainActor.run {
                isLookingUp = true
                results = "Looking up barcode: \(testBarcode)...\n"
            }
            
            // Test the improved barcode service
            let startTime = Date()
            
            if let albumData = await ImprovedBarcodeService.lookupAlbumByBarcode(testBarcode) {
                let duration = Date().timeIntervalSince(startTime)
                
                let resultText = """
                ✅ SUCCESS (took \(String(format: "%.1f", duration))s)
                
                Artist: \(albumData.artist ?? "nil")
                Album: \(albumData.album ?? "nil")
                Year: \(albumData.year?.description ?? "nil")
                Label: \(albumData.label ?? "nil")
                Genres: \(albumData.genres?.joined(separator: ", ") ?? "nil")
                Cover URL: \(albumData.coverUrl ?? "nil")
                
                Raw Data:
                \(albumData.toDictionary())
                """
                
                await MainActor.run {
                    results = resultText
                }
                
            } else {
                let duration = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    results = """
                    ❌ NOT FOUND (took \(String(format: "%.1f", duration))s)
                    
                    No album data found for barcode: \(testBarcode)
                    
                    Possible reasons:
                    • Barcode not in music databases
                    • Album is too new or obscure
                    • Barcode format not recognized
                    • API rate limiting or network issues
                    
                    Try with a different barcode or check the barcode format.
                    """
                }
            }
            
            await MainActor.run {
                isLookingUp = false
            }
        }
    }
}

#if DEBUG
struct BarcodeTestingView_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeTestingView()
    }
}
#endif