//
//  BodyScanView.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import SwiftUI
import AVFoundation
import Foundation
import Vision

struct BodyScanView: View {
    @StateObject private var viewModel: BodyScanViewModel
    @State private var showingInstructions = true
    @State private var currentScanPerspective = "front"
    @State private var navigateToResults = false
    @State private var isCountingDown = false
    @State private var countdownValue = 5
    @EnvironmentObject var dataStore: AppDataStore
    var fromChallenge: Bool = false
    
    init(fromChallenge: Bool = false) {
        self.fromChallenge = fromChallenge
        let viewModel = BodyScanViewModel()
        viewModel.fromChallenge = fromChallenge
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
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
                    .font(.tagesschriftHeadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 50) // Add padding to move below status bar
                
                Spacer() // Push content to top and bottom
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Capture button
                        Button(action: {
                            if !isCountingDown && viewModel.isCameraReady {
                                startCountdown()
                            } else if !viewModel.isCameraReady {
                                // Show a message that camera is initializing
                                viewModel.alertTitle = "Camera Initializing"
                                viewModel.alertMessage = "Please wait a moment while the camera is preparing..."
                                viewModel.showAlert = true
                            }
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 2)
                                        .frame(width: 60, height: 60)
                                )
                        }
                        .disabled(viewModel.isProcessing)
                        
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
                
                // Navigation destination is now moved to the ZStack level
            }
            
            // Countdown overlay
            if isCountingDown {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("\(countdownValue)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                    
                    Text("Get ready!")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
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
        .navigationDestination(isPresented: $navigateToResults) {
            ScanResultsView(
                frontImage: viewModel.frontImageWithPosePoints ?? viewModel.frontImage,
                sideImage: viewModel.sideImageWithPosePoints ?? viewModel.sideImage,
                fromChallenge: fromChallenge,
                dataStore: AppDataStore.shared  // Pass the data store directly as a parameter
            )
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK")) {
                    if viewModel.scanComplete {
                        if currentScanPerspective == "front" {
                            // Switch to side perspective for the second scan
                            currentScanPerspective = "side"
                            viewModel.showInstructionsForSideScan()
                        } else {
                            // Both scans are complete, navigate to results page
                            navigateToResults = true
                        }
                    }
                }
            )
        }
        .onChange(of: viewModel.scanComplete) { oldValue, newValue in
            print("Scan complete changed: \(oldValue) -> \(newValue), perspective: \(currentScanPerspective)")
            if newValue && currentScanPerspective == "front" {
                // Front scan complete, switch to side scan
                print("Front scan complete, switching to side scan")
                currentScanPerspective = "side"
                viewModel.scanComplete = false
                viewModel.showInstructionsForSideScan()
            } else if newValue && currentScanPerspective == "side" {
                // Both scans complete, navigate to results
                print("Side scan complete, navigating to results")
                navigateToResults = true
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
    
    // Function to handle the countdown and capture
    private func startCountdown() {
        // Start countdown
        isCountingDown = true
        countdownValue = 5
        
        // Create a timer that fires every second
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.countdownValue > 1 {
                self.countdownValue -= 1
            } else {
                // When countdown reaches 0, stop the timer and take the photo
                timer.invalidate()
                self.isCountingDown = false
                
                // Add a small delay before capturing to allow UI to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.viewModel.captureImage()
                }
            }
        }
        
        // Make sure the timer continues to fire even when scrolling
        RunLoop.current.add(timer, forMode: .common)
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
        print("StreamingCameraView: Starting to handle camera previews")
        var frameCount = 0
        
        let imageStream = viewModel.depthCaptureManager.previewStream
            .compactMap { ciImage -> Image? in
                // Count frames received from the stream
                frameCount += 1
                
                if frameCount == 1 {
                    print("StreamingCameraView: Received first image from preview stream")
                }
                
                if frameCount % 30 == 0 {
                    print("StreamingCameraView: Processed \(frameCount) frames")
                }
                
                // Convert CIImage to SwiftUI Image with correct orientation
                let ciContext = CIContext()
                
                // Apply rotation transform to fix orientation
                // First rotate, then flip horizontally to fix mirroring
                var rotatedImage = ciImage.oriented(.right)
                
                // Flip horizontally to fix mirroring (for front camera)
                if viewModel.depthCaptureManager.isUsingFrontCamera {
                    rotatedImage = rotatedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                }
                
                guard let cgImage = ciContext.createCGImage(rotatedImage, from: rotatedImage.extent) else {
                    if frameCount < 10 { // Only log early failures to avoid spam
                        print("StreamingCameraView: Failed to create CGImage from CIImage")
                    }
                    return nil
                }
                
                return Image(decorative: cgImage, scale: 1, orientation: .up)
            }
        
        print("StreamingCameraView: Awaiting images from stream")
        
        for await image in imageStream {
            // Update the viewfinder image on the main thread
            await MainActor.run {
                let oldImage = viewfinderImage
                viewfinderImage = image
                
                if oldImage == nil && viewfinderImage != nil {
                    print("StreamingCameraView: First viewfinder image set successfully")
                }
            }
        }
        
        print("StreamingCameraView: Stream ended")
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
                    .font(.tagesschrift(size: 22))
                    .fontWeight(.bold)
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
                        .font(.tagesschrift(size: 16))
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
                    .font(.tagesschrift(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.tagesschrift(size: 14))
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
    var fromChallenge: Bool = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var isCameraReady = false
    
    // Changed from private to internal access level to allow ScanResultsView to access them
    var frontImage: UIImage?
    var frontDepthData: CVPixelBuffer?
    var sideImage: UIImage?
    var sideDepthData: CVPixelBuffer?
    
    // Store the body pose points for visualization
    @Published var frontImageWithPosePoints: UIImage?
    @Published var sideImageWithPosePoints: UIImage?
    
    // Body pose detection request
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    
    init() {
        print("Initializing BodyScanViewModel")
        depthCaptureManager = DepthCaptureManager()
        setupCaptureCallbacks()
        setupSessionObservers()
    }
    
    private func setupSessionObservers() {
        print("Setting up session observers")
        
        // Monitor camera session state using notifications
        let startNotificationName = AVCaptureSession.didStartRunningNotification
        let stopNotificationName = AVCaptureSession.didStopRunningNotification
        let runtimeErrorNotificationName = AVCaptureSession.runtimeErrorNotification
        let wasInterruptedNotificationName = AVCaptureSession.wasInterruptedNotification
        let interruptionEndedNotificationName = AVCaptureSession.interruptionEndedNotification
        
        // Session started notification
        NotificationCenter.default.addObserver(forName: startNotificationName, object: depthCaptureManager.captureSession, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.isCameraReady = true
            print("📷 NOTIFICATION: Camera session did start running")
            print("Camera ready state updated to: \(self.isCameraReady)")
        }
        
        // Session stopped notification
        NotificationCenter.default.addObserver(forName: stopNotificationName, object: depthCaptureManager.captureSession, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.isCameraReady = false
            print("📷 NOTIFICATION: Camera session did stop running")
        }
        
        // Runtime error notification
        NotificationCenter.default.addObserver(forName: runtimeErrorNotificationName, object: depthCaptureManager.captureSession, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            print("📷 NOTIFICATION: Camera session runtime error")
            
            if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error {
                print("Camera error: \(error.localizedDescription)")
                
                // Show error to user
                self.alertTitle = "Camera Error"
                self.alertMessage = "The camera encountered an error: \(error.localizedDescription)"
                self.showAlert = true
            }
        }
        
        // Session was interrupted notification
        NotificationCenter.default.addObserver(forName: wasInterruptedNotificationName, object: depthCaptureManager.captureSession, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            print("📷 NOTIFICATION: Camera session was interrupted")
            
            if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason {
                print("Interruption reason: \(reason.rawValue)")
            }
        }
        
        // Interruption ended notification
        NotificationCenter.default.addObserver(forName: interruptionEndedNotificationName, object: depthCaptureManager.captureSession, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            print("📷 NOTIFICATION: Camera session interruption ended")
        }
        
        print("All session observers have been set up")
    }
    
    private func setupCaptureCallbacks() {
        depthCaptureManager.onPhotoCaptured = { [weak self] image, depthData in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.frontImage == nil {
                    // This is the front image
                    self.frontImage = image
                    self.frontDepthData = depthData
                    // Process the image to detect body pose points
                    self.detectBodyPosePoints(in: image, isFrontView: true)
                } else {
                    // This is the side image
                    self.sideImage = image
                    self.sideDepthData = depthData
                    // Process the image to detect body pose points
                    self.detectBodyPosePoints(in: image, isFrontView: false)
                }
                
                self.isProcessing = false
                self.scanComplete = true
                print("Photo captured and processed, scanComplete set to true, isFrontView: \(self.frontImage == nil ? false : true)")
            }
        }
        
        depthCaptureManager.onCaptureError = { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                
                // Check if this is a camera permission error
                let nsError = error as NSError
                if nsError.domain == "DepthCaptureManager" && nsError.code == 2 {
                    self.alertTitle = "Camera Permission Required"
                    self.alertMessage = "Please allow camera access in Settings to use the body scan feature."
                } else {
                    self.alertTitle = "Capture Error"
                    self.alertMessage = error.localizedDescription
                }
                
                self.showAlert = true
            }
        }
    }
    
    func startSession() {
        print("ViewModel starting camera session")
        
        // Check if camera session is already running
        if depthCaptureManager.captureSession.isRunning {
            print("Camera session is already running before startSession() call")
            self.isCameraReady = true
        } else {
            print("Camera session is not running, starting now...")
        }
        
        // Start the camera session
        depthCaptureManager.startSession()
        
        // Check camera status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Check permission status
            let permissionGranted = self.depthCaptureManager.cameraPermissionGranted
            print("Camera permission status after 0.5s: \(permissionGranted)")
            
            // Check if session is running
            let isRunning = self.depthCaptureManager.captureSession.isRunning
            print("Camera session running status after 0.5s: \(isRunning)")
            
            // Update ready state
            self.isCameraReady = permissionGranted && isRunning
            print("Camera ready status updated to: \(self.isCameraReady)")
            
            if !self.isCameraReady {
                if !permissionGranted {
                    print("Camera not ready - permission denied")
                } else if !isRunning {
                    print("Camera not ready - session not running")
                }
            }
        }
        
        // Check again after a longer delay to catch delayed startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            let isRunning = self.depthCaptureManager.captureSession.isRunning
            print("Camera session running status after 2.0s: \(isRunning)")
            
            if isRunning && !self.isCameraReady {
                print("Updating camera ready status - session is now running")
                self.isCameraReady = true
            }
        }
    }
    
    func stopSession() {
        depthCaptureManager.stopSession()
    }
    
    func captureImage() {
        isProcessing = true
        depthCaptureManager.capturePhoto()
    }
    
    func showInstructionsForSideScan() {
        print("Showing instructions for side scan")
        alertTitle = "Side Scan"
        alertMessage = "Great! Now please turn to your side and position yourself within the outline for a side view scan."
        showAlert = true
    }
    
    // This function is now just for resetting scan data after processing
    func processScans() {
        print("Processing scans and resetting state")
        // Reset the scan data after processing
        resetScanState()
    }
    
    func resetScanState() {
        print("Resetting scan state")
        isProcessing = false
        scanComplete = false
        
        // Reset the captured images
        frontImage = nil
        frontDepthData = nil
        sideImage = nil
        sideDepthData = nil
        frontImageWithPosePoints = nil
        sideImageWithPosePoints = nil
    }
    
    // MARK: - Body Pose Detection
    
    private func detectBodyPosePoints(in image: UIImage, isFrontView: Bool) {
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else { return }
        
        // Create a request handler with proper orientation
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, orientation: .right)
        
        do {
            // Perform the body pose detection request
            try requestHandler.perform([bodyPoseRequest])
            
            // Process the results
            if let observations = bodyPoseRequest.results, !observations.isEmpty {
                let bodyPose = observations[0] // Get the first detected body
                
                // Create an image with the pose points overlaid
                let annotatedImage = drawPosePoints(on: image, bodyPose: bodyPose)
                
                // Store the annotated image
                if isFrontView {
                    self.frontImageWithPosePoints = annotatedImage
                } else {
                    self.sideImageWithPosePoints = annotatedImage
                }
            }
        } catch {
            print("Body pose detection failed: \(error.localizedDescription)")
        }
    }
    
    private func drawPosePoints(on image: UIImage, bodyPose: VNHumanBodyPoseObservation) -> UIImage {
        // Start a graphics context with the original image
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
        image.draw(at: .zero)
        
        // Get the graphics context
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        // Define the joints we want to visualize
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .neck,
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            .leftHip, .rightHip, .root,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        // Set drawing parameters
        context.setLineWidth(3.0)
        context.setStrokeColor(UIColor.green.cgColor)
        context.setFillColor(UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.9).cgColor)
        
        // Draw each joint point
        for jointName in jointNames {
            if let point = try? bodyPose.recognizedPoint(jointName), point.confidence > 0.3 {
                // Convert normalized point to image coordinates
                let x = CGFloat(point.location.x) * image.size.width
                let y = (1 - CGFloat(point.location.y)) * image.size.height  // Flip y-coordinate
                
                // Draw a larger circle at the joint position
                context.fillEllipse(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
                
                // Add joint name as text with improved readability
                // Get the simplified joint name
                let jointText = formatJointName(jointName)
                
                // Use larger font for better readability
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 50),
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = (jointText as NSString).size(withAttributes: attributes)
                
                // Position text with more space from the joint point
                let textRect = CGRect(x: x + 10, y: y - textSize.height/2, width: textSize.width, height: textSize.height)
                
                // Draw a more visible background with rounded corners for the text
                let backgroundPath = UIBezierPath(roundedRect: textRect.insetBy(dx: -6, dy: -4), cornerRadius: 6)
                context.addPath(backgroundPath.cgPath)
                context.setFillColor(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.85).cgColor)
                context.fillPath()
                
                // Add a subtle border around the text background
                context.addPath(backgroundPath.cgPath)
                context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
                context.setLineWidth(1.0)
                context.strokePath()
                
                // Draw the text
                context.setFillColor(UIColor.white.cgColor)
                (jointText as NSString).draw(in: textRect, withAttributes: attributes)
            }
        }
        
        // Draw connections between joints to form a skeleton
        drawSkeletonConnections(context: context, bodyPose: bodyPose, imageSize: image.size)
        
        // Get the resulting image
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resultImage
    }
    
    // Helper function to format joint names for better readability
    private func formatJointName(_ jointName: VNHumanBodyPoseObservation.JointName) -> String {
        // Get just the simple name of the joint without any prefix
        switch jointName {
        case .nose: return "Nose"
        case .leftEye: return "L Eye"
        case .rightEye: return "R Eye"
        case .leftEar: return "L Ear"
        case .rightEar: return "R Ear"
        case .neck: return "Neck"
        case .leftShoulder: return "L Shoulder"
        case .rightShoulder: return "R Shoulder"
        case .leftElbow: return "L Elbow"
        case .rightElbow: return "R Elbow"
        case .leftWrist: return "L Wrist"
        case .rightWrist: return "R Wrist"
        case .leftHip: return "L Hip"
        case .rightHip: return "R Hip"
        case .root: return "Root"
        case .leftKnee: return "L Knee"
        case .rightKnee: return "R Knee"
        case .leftAnkle: return "L Ankle"
        case .rightAnkle: return "R Ankle"
        default: return "Joint"
        }
    }
    
    private func drawSkeletonConnections(context: CGContext, bodyPose: VNHumanBodyPoseObservation, imageSize: CGSize) {
        // Define connections between joints
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.nose, .leftEye), (.leftEye, .leftEar), (.nose, .rightEye), (.rightEye, .rightEar),
            (.leftShoulder, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
        ]
        
        // Set line properties with improved visibility
        context.setStrokeColor(UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8).cgColor)
        context.setLineWidth(3.0)
        
        // Draw each connection
        for connection in connections {
            guard let pointA = try? bodyPose.recognizedPoint(connection.0),
                  let pointB = try? bodyPose.recognizedPoint(connection.1),
                  pointA.confidence > 0.3,
                  pointB.confidence > 0.3 else {
                continue
            }
            
            // Convert normalized points to image coordinates
            let xA = CGFloat(pointA.location.x) * imageSize.width
            let yA = (1 - CGFloat(pointA.location.y)) * imageSize.height
            let xB = CGFloat(pointB.location.x) * imageSize.width
            let yB = (1 - CGFloat(pointB.location.y)) * imageSize.height
            
            // Draw the line
            context.move(to: CGPoint(x: xA, y: yA))
            context.addLine(to: CGPoint(x: xB, y: yB))
            context.strokePath()
        }
    }
}

// MARK: - Scan Results View

struct ScanResultsView: View {
    var frontImage: UIImage?
    var sideImage: UIImage?
    var fromChallenge: Bool = false
    var dataStore: AppDataStore  // Accept data store as a parameter instead of environment object
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            
            VStack(spacing: 20) {
                Text("Body Scan Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Body pose points detected")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                
                VStack(spacing: 20) {
                        // Front image with pose points
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Front View")
                                .font(.headline)
                            
                            if let frontImage = frontImage {
                                Image(uiImage: frontImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(12)
                            } else {
                                Text("Front image not available")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Side image with pose points
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Side View")
                                .font(.headline)
                            
                            if let sideImage = sideImage {
                                Image(uiImage: sideImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(12)
                            } else {
                                Text("Side image not available")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                
                // Continue button
                Button(action: {
                    // Process the scan and add to feed
                    processScanAndNavigateToFeed()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Body Scan Results")
        .navigationBarItems(leading: Button("Retake") {
            presentationMode.wrappedValue.dismiss()
        })
        .navigationBarBackButtonHidden(true)
    }
}

// Add the processing function to ScanResultsView
extension ScanResultsView {
    func processScanAndNavigateToFeed() {
        // Simulate analysis results
        let bodyFatPercentage = Double.random(in: 15...25)
        let leanMusclePercentage = Double.random(in: 60...75)
        let visceralFatLevel = Int.random(in: 1...10)
        
        // Add the scan to the data store
        dataStore.addScanLog(
            bodyFatPercentage: bodyFatPercentage,
            leanMusclePercentage: leanMusclePercentage,
            visceralFatLevel: String(visceralFatLevel), // Convert Int to String
            frontImage: frontImage,
            sideImage: sideImage,
            fromChallenge: fromChallenge
        )
        
        // Dismiss all the way back to the root view (Today's Feed)
        dismiss()
    }
}

struct BodyScanView_Previews: PreviewProvider {
    static var previews: some View {
        BodyScanView()
            .environmentObject(AppDataStore.shared)
    }
} 
