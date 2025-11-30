//
//  Views/Components/BarcodeScannerView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let onBarcodeScanned: (String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                BarcodeScannerRepresentable(
                    isScanning: $isScanning,
                    onBarcodeScanned: { barcode in
                        onBarcodeScanned(barcode)
                        dismiss()
                    }
                )
                .ignoresSafeArea()
                
                // Overlay with scanning frame
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Text("Position barcode within the frame")
                            .foregroundColor(.white)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        // Scanning frame
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 250, height: 150)
                            .overlay(
                                // Corner indicators
                                VStack {
                                    HStack {
                                        CornerIndicator()
                                        Spacer()
                                        CornerIndicator()
                                    }
                                    Spacer()
                                    HStack {
                                        CornerIndicator()
                                        Spacer()
                                        CornerIndicator()
                                    }
                                }
                                .padding(10)
                            )
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Scanning Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                isScanning = true
            }
            .onDisappear {
                isScanning = false
            }
        }
    }
}

struct CornerIndicator: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 20, height: 3)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: 20)
            }
        }
    }
}

struct BarcodeScannerRepresentable: UIViewRepresentable {
    @Binding var isScanning: Bool
    let onBarcodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let coordinator = context.coordinator
        
        // Store the view reference
        coordinator.containerView = view
        
        // Configure the camera session
        coordinator.setupCamera()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let coordinator = context.coordinator as? Coordinator else { return }
        
        // Update preview layer frame when view bounds change
        coordinator.updatePreviewLayerFrame()
        
        if isScanning {
            coordinator.startScanning()
        } else {
            coordinator.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: BarcodeScannerRepresentable
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var containerView: UIView?
        private var isSessionConfigured = false
        
        init(_ parent: BarcodeScannerRepresentable) {
            self.parent = parent
            super.init()
        }
        
        func setupCamera() {
            // Check camera permission first
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureCameraSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.configureCameraSession()
                        }
                    }
                }
            case .denied, .restricted:
                print("Camera access denied")
            @unknown default:
                print("Unknown camera authorization status")
            }
        }
        
        private func configureCameraSession() {
            let captureSession = AVCaptureSession()
            self.captureSession = captureSession
            
            // Configure session on background queue
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                captureSession.beginConfiguration()
                
                // Set session preset
                if captureSession.canSetSessionPreset(.high) {
                    captureSession.sessionPreset = .high
                }
                
                // Add video input
                guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                    print("No video capture device available")
                    captureSession.commitConfiguration()
                    return
                }
                
                do {
                    let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
                    if captureSession.canAddInput(videoInput) {
                        captureSession.addInput(videoInput)
                    }
                } catch {
                    print("Error creating video input: \(error)")
                    captureSession.commitConfiguration()
                    return
                }
                
                // Add metadata output
                let metadataOutput = AVCaptureMetadataOutput()
                if captureSession.canAddOutput(metadataOutput) {
                    captureSession.addOutput(metadataOutput)
                    
                    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    metadataOutput.metadataObjectTypes = [
                        .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93, .upce
                    ]
                }
                
                captureSession.commitConfiguration()
                
                // Mark session as configured
                self.isSessionConfigured = true
                
                // Create preview layer on main queue
                DispatchQueue.main.async { [weak self] in
                    self?.setupPreviewLayer()
                }
            }
        }
        
        private func setupPreviewLayer() {
            guard let captureSession = captureSession,
                  let containerView = containerView else { return }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = containerView.layer.bounds
            
            containerView.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
            
            // Start the session only after everything is set up
            startSessionIfReady()
        }
        
        private func startSessionIfReady() {
            guard isSessionConfigured,
                  let captureSession = captureSession,
                  !captureSession.isRunning else { return }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
        
        func updatePreviewLayerFrame() {
            guard let previewLayer = previewLayer,
                  let containerView = containerView else { return }
            
            previewLayer.frame = containerView.layer.bounds
        }
        
        func startScanning() {
            startSessionIfReady()
        }
        
        func stopScanning() {
            guard let captureSession = captureSession else { return }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if captureSession.isRunning {
                    self?.captureSession?.stopRunning()
                }
            }
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                // Stop scanning and return the barcode
                stopScanning()
                parent.onBarcodeScanned(stringValue)
            }
        }
    }
}

