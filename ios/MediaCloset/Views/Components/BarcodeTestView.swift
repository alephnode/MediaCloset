//
//  Views/Components/BarcodeTestView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import SwiftUI

struct BarcodeTestView: View {
    @State private var testBarcode = "602498678309"
    @State private var testResult: String = ""
    @State private var isTesting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Barcode Service Test")
                    .font(.title)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Barcode:")
                        .font(.headline)
                    TextField("Enter barcode", text: $testBarcode)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                
                Button("Test Album Lookup") {
                    Task {
                        await testAlbumLookup()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting)
                
                if isTesting {
                    ProgressView("Testing...")
                        .padding()
                }
                
                if !testResult.isEmpty {
                    ScrollView {
                        Text(testResult)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)
                    .padding()
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    func testAlbumLookup() async {
        isTesting = true
        testResult = ""

        let result = await ImprovedBarcodeService.lookupAlbumByBarcode(testBarcode)

        if let data = result {
            testResult = "Success! Found album data:\n\n"
            for (key, value) in data {
                testResult += "\(key): \(value)\n"
            }
        } else {
            testResult = "No album data found for barcode: \(testBarcode)"
        }

        isTesting = false
    }
}

#Preview {
    BarcodeTestView()
}
