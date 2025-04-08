//
//  BodyScanView.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import SwiftUI
import AVFoundation
import Foundation

struct BodyScanView: View {
    @StateObject private var viewModel = BodyScanViewModel()
    @State private var showingInstructions = true
    @State private var currentScanPerspective = "front"
    
    var body: some View {
        ZStack {
            // Camera preview using the stream
            StreamingCameraView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay for body positioning guide
            BodyPositioningGuideView(perspective: currentScanPerspective)
                .opacity(0.7)
            
            // Main content layout
            VStack {
                // Scan perspective indicator at the top
                Text("Current scan: \(currentScanPerspective.capitalized)")
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 50) // Add padding to move below status bar
                
                Spacer() // Push content to top and bottom
                
                // Capture button at the bottom
                Button(action: {
                    viewModel.captureImage()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 80, height: 80)
                    }
                }
                .padding(.bottom, 30)
                .disabled(viewModel.isProcessing)
            }
            
            // Processing overlay
            if viewModel.isProcessing {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    
                    Text("Processing scan...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            // Instructions overlay
            if showingInstructions {
                InstructionsView(isShowing: $showingInstructions)
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK")) {
                    // Check if this is the completion alert and reset if needed
                    if viewModel.alertTitle == "Scan Complete" {
                        resetForNewScan()
                    }
                }
            )
        }
        .onChange(of: viewModel.scanComplete) { oldValue, newValue in
            if newValue && currentScanPerspective == "front" {
                // Front scan complete, switch to side scan
                currentScanPerspective = "side"
                viewModel.scanComplete = false
                viewModel.showInstructionsForSideScan()
            } else if newValue && currentScanPerspective == "side" {
                // Both scans complete, process the results
                viewModel.processScans()
            }
        }
        .onAppear {
            print("BodyScanView appeared")
            // Reset the view state when it appears
            resetForNewScan()
            
            // Force start the camera session when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.startSession()
            }
        }
        .onDisappear {
            print("BodyScanView disappeared")
            viewModel.stopSession()
        }
    }
    
    private func resetForNewScan() {
        // Reset the view state
        currentScanPerspective = "front"
        showingInstructions = true
        
        // Reset the view model state
        viewModel.resetScanState()
    }
}

// New streaming camera view that uses the CIImage stream
struct StreamingCameraView: View {
    @ObservedObject var viewModel: BodyScanViewModel
    @State private var viewfinderImage: Image?
    
    var body: some View {
        ZStack {
            // Display the current viewfinder image or a black background
            if let image = viewfinderImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            // Start handling the preview stream
            Task {
                await handleCameraPreviews()
            }
        }
    }
    
    private func handleCameraPreviews() async {
        let imageStream = viewModel.depthCaptureManager.previewStream
            .compactMap { ciImage -> Image? in
                // Convert CIImage to SwiftUI Image with correct orientation
                let ciContext = CIContext()
                
                // Apply rotation transform to fix orientation
                // First rotate, then flip horizontally to fix mirroring
                var rotatedImage = ciImage.oriented(.right)
                
                // Flip horizontally to fix mirroring (for front camera)
                if viewModel.depthCaptureManager.isUsingFrontCamera {
                    rotatedImage = rotatedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                }
                
                guard let cgImage = ciContext.createCGImage(rotatedImage, from: rotatedImage.extent) else { return nil }
                return Image(decorative: cgImage, scale: 1, orientation: .up)
            }
        
        for await image in imageStream {
            // Update the viewfinder image on the main thread
            await MainActor.run {
                viewfinderImage = image
            }
        }
    }
}

// Keep the existing CameraPreviewView for devices that don't support the new approach
struct CameraPreviewView: UIViewRepresentable {
    let depthCaptureManager: DepthCaptureManager
    
    class Coordinator: NSObject {
        var parent: CameraPreviewView
        
        init(parent: CameraPreviewView) {
            self.parent = parent
        }
        
        @objc func sessionDidStartRunning() {
            print("Received notification: Camera session started running")
        }
        
        @objc func sessionRuntimeError(_ notification: Notification) {
            print("Camera session runtime error: \(notification)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIView {
        print("Creating camera preview view")
        let view = UIView(frame: UIScreen.main.bounds)
        
        // Set a black background as fallback
        view.backgroundColor = .black
        
        if let previewLayer = depthCaptureManager.previewLayer {
            print("Preview layer exists, adding to view")
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            // Add observers using the coordinator with updated notification names
            if #available(iOS 18.0, *) {
                depthCaptureManager.addSessionObserver(
                    observer: context.coordinator,
                    selector: #selector(Coordinator.sessionDidStartRunning),
                    name: AVCaptureSession.didStartRunningNotification
                )
                
                depthCaptureManager.addSessionObserver(
                    observer: context.coordinator,
                    selector: #selector(Coordinator.sessionRuntimeError(_:)),
                    name: AVCaptureSession.runtimeErrorNotification
                )
            } else {
                // For iOS 17 and earlier
                depthCaptureManager.addSessionObserver(
                    observer: context.coordinator,
                    selector: #selector(Coordinator.sessionDidStartRunning),
                    name: .AVCaptureSessionDidStartRunning
                )
                
                depthCaptureManager.addSessionObserver(
                    observer: context.coordinator,
                    selector: #selector(Coordinator.sessionRuntimeError(_:)),
                    name: .AVCaptureSessionRuntimeError
                )
            }
        } else {
            print("Preview layer is nil")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = depthCaptureManager.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        // Remove observers when the view is dismantled
        coordinator.parent.depthCaptureManager.removeSessionObserver(observer: coordinator)
    }
}

struct BodyPositioningGuideView: View {
    let perspective: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Outline for body positioning
                Path { path in
                    if perspective == "front" {
                        // Front-facing body outline - simplified and smoother
                        let width = geometry.size.width * 0.5  // Slightly narrower
                        let height = geometry.size.height * 0.7
                        let x = (geometry.size.width - width) / 2
                        let y = (geometry.size.height - height) / 2
                        
                        // Head - simplified oval
                        let headSize = width * 0.28
                        path.addEllipse(in: CGRect(
                            x: x + (width - headSize) / 2,
                            y: y,
                            width: headSize,
                            height: headSize * 1.1
                        ))
                        
                        // Shoulders - smoother curve
                        path.move(to: CGPoint(x: x + width * 0.2, y: y + headSize * 1.3))
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.8, y: y + headSize * 1.3),
                            control1: CGPoint(x: x + width * 0.3, y: y + headSize * 1.2),
                            control2: CGPoint(x: x + width * 0.7, y: y + headSize * 1.2)
                        )
                        
                        // Body outline - smoother curves
                        // Left side
                        path.move(to: CGPoint(x: x + width * 0.2, y: y + headSize * 1.3))
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.15, y: y + height * 0.5),
                            control1: CGPoint(x: x + width * 0.18, y: y + height * 0.3),
                            control2: CGPoint(x: x + width * 0.15, y: y + height * 0.4)
                        )
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.2, y: y + height * 0.9),
                            control1: CGPoint(x: x + width * 0.15, y: y + height * 0.6),
                            control2: CGPoint(x: x + width * 0.18, y: y + height * 0.75)
                        )
                        
                        // Right side
                        path.move(to: CGPoint(x: x + width * 0.8, y: y + headSize * 1.3))
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.85, y: y + height * 0.5),
                            control1: CGPoint(x: x + width * 0.82, y: y + height * 0.3),
                            control2: CGPoint(x: x + width * 0.85, y: y + height * 0.4)
                        )
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.8, y: y + height * 0.9),
                            control1: CGPoint(x: x + width * 0.85, y: y + height * 0.6),
                            control2: CGPoint(x: x + width * 0.82, y: y + height * 0.75)
                        )
                        
                        // Legs - simplified
                        path.move(to: CGPoint(x: x + width * 0.35, y: y + height * 0.9))
                        path.addLine(to: CGPoint(x: x + width * 0.35, y: y + height))
                        
                        path.move(to: CGPoint(x: x + width * 0.65, y: y + height * 0.9))
                        path.addLine(to: CGPoint(x: x + width * 0.65, y: y + height))
                        
                    } else if perspective == "side" {
                        // Side-facing body outline - simplified and smoother
                        let width = geometry.size.width * 0.3  // Narrower for side view
                        let height = geometry.size.height * 0.7
                        let x = (geometry.size.width - width) / 2
                        let y = (geometry.size.height - height) / 2
                        
                        // Head - simplified oval
                        let headSize = width * 0.8
                        path.addEllipse(in: CGRect(
                            x: x + width * 0.1,
                            y: y,
                            width: headSize,
                            height: headSize * 1.1
                        ))
                        
                        // Body outline - smoother curves
                        // Back
                        path.move(to: CGPoint(x: x + width * 0.3, y: y + headSize * 1.1))
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.2, y: y + height * 0.9),
                            control1: CGPoint(x: x + width * 0.25, y: y + height * 0.4),
                            control2: CGPoint(x: x + width * 0.2, y: y + height * 0.6)
                        )
                        
                        // Front
                        path.move(to: CGPoint(x: x + width * 0.9, y: y + headSize * 1.1))
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.7, y: y + height * 0.4),
                            control1: CGPoint(x: x + width * 0.9, y: y + height * 0.25),
                            control2: CGPoint(x: x + width * 0.8, y: y + height * 0.3)
                        )
                        path.addCurve(
                            to: CGPoint(x: x + width * 0.6, y: y + height * 0.9),
                            control1: CGPoint(x: x + width * 0.65, y: y + height * 0.5),
                            control2: CGPoint(x: x + width * 0.6, y: y + height * 0.7)
                        )
                        
                        // Legs
                        path.move(to: CGPoint(x: x + width * 0.4, y: y + height * 0.9))
                        path.addLine(to: CGPoint(x: x + width * 0.4, y: y + height))
                    }
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.teal.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                
                // Add a subtle highlight area to indicate optimal positioning
                if perspective == "front" {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                        .frame(
                            width: geometry.size.width * 0.6,
                            height: geometry.size.height * 0.75
                        )
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                        .frame(
                            width: geometry.size.width * 0.4,
                            height: geometry.size.height * 0.75
                        )
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                }
            }
        }
    }
}

struct InstructionsView: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                Text("Body Scan Instructions")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(number: 1, text: "Stand 5-7 feet from camera")
                    InstructionRow(number: 2, text: "Position body within outline")
                    InstructionRow(number: 3, text: "Wear form-fitting clothing")
                    InstructionRow(number: 4, text: "Take front and side photos")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: {
                    withAnimation {
                        isShowing = false
                    }
                }) {
                    Text("Got it")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 30)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.teal]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemGray6))
                    .opacity(0.95)
            )
            .frame(width: min(UIScreen.main.bounds.width - 40, 320))
            .padding(20)
        }
        .transition(.opacity)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.teal]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                
                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - ViewModel

class BodyScanViewModel: ObservableObject {
    let depthCaptureManager: DepthCaptureManager
    
    @Published var isProcessing = false
    @Published var scanComplete = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    private var frontImage: UIImage?
    private var frontDepthData: CVPixelBuffer?
    private var sideImage: UIImage?
    private var sideDepthData: CVPixelBuffer?
    
    init() {
        print("Initializing BodyScanViewModel")
        depthCaptureManager = DepthCaptureManager()
        setupCaptureCallbacks()
    }
    
    private func setupCaptureCallbacks() {
        depthCaptureManager.onPhotoCaptured = { [weak self] image, depthData in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.frontImage == nil {
                    // This is the front image
                    self.frontImage = image
                    self.frontDepthData = depthData
                } else {
                    // This is the side image
                    self.sideImage = image
                    self.sideDepthData = depthData
                }
                
                self.isProcessing = false
                self.scanComplete = true
            }
        }
        
        depthCaptureManager.onCaptureError = { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.alertTitle = "Capture Error"
                self.alertMessage = error.localizedDescription
                self.showAlert = true
            }
        }
    }
    
    func startSession() {
        print("ViewModel starting camera session")
        depthCaptureManager.startSession()
    }
    
    func stopSession() {
        depthCaptureManager.stopSession()
    }
    
    func captureImage() {
        isProcessing = true
        depthCaptureManager.capturePhoto()
    }
    
    func showInstructionsForSideScan() {
        alertTitle = "Side Scan"
        alertMessage = "Great! Now please turn to your side and position yourself within the outline for a side view scan."
        showAlert = true
    }
    
    func processScans() {
        guard let frontImage = frontImage, let sideImage = sideImage else {
            alertTitle = "Processing Error"
            alertMessage = "Missing scan data. Please try again."
            showAlert = true
            return
        }
        
        isProcessing = true
        
        // Here you would integrate with your AI model for body composition analysis
        // For now, we'll simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Simulate analysis results
            let bodyFatPercentage = Double.random(in: 15...25)
            let leanMusclePercentage = Double.random(in: 60...75)
            let visceralFatLevel = ["Low", "Medium", "High"].randomElement()!
            
            // Save the scan log
            ScanLogStore.shared.addScanLog(
                bodyFatPercentage: bodyFatPercentage,
                leanMusclePercentage: leanMusclePercentage,
                visceralFatLevel: visceralFatLevel,
                frontImage: frontImage,
                sideImage: sideImage
            )
            
            self.isProcessing = false
            self.alertTitle = "Scan Complete"
            self.alertMessage = "Body composition analysis complete!\n\nEstimated body fat: \(String(format: "%.1f%%", bodyFatPercentage))\nLean muscle mass: \(String(format: "%.1f%%", leanMusclePercentage))\nVisceral fat level: \(visceralFatLevel)"
            self.showAlert = true
        }
    }
    
    func resetScanState() {
        isProcessing = false
        scanComplete = false
        
        // Reset the captured images
        frontImage = nil
        frontDepthData = nil
        sideImage = nil
        sideDepthData = nil
    }
}

struct BodyScanView_Previews: PreviewProvider {
    static var previews: some View {
        BodyScanView()
    }
} 