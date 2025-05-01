//
//  DepthCaptureManager.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import AVFoundation
import UIKit
import CoreImage
import Vision

class DepthCaptureManager: NSObject {
    // MARK: - Properties
    
    let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let dataOutputQueue = DispatchQueue(label: "com.checkmeout.dataOutput", qos: .userInitiated)
    
    private var currentDepthPixelBuffer: CVPixelBuffer?
    private var currentColorPixelBuffer: CVPixelBuffer?
    private var frameCounter = 0
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Track whether we're using the front camera
    var isUsingFrontCamera: Bool = true
    
    // Completion handlers
    var onPhotoCaptured: ((UIImage, CVPixelBuffer?) -> Void)?
    var onCaptureError: ((Error) -> Void)?
    
    // Add a preview stream for CIImage
    private var addToPreviewStream: ((CIImage) -> Void)?
    
    lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                continuation.yield(ciImage)
            }
        }
    }()
    
    // Add body detection callback
    var onFrameProcessed: ((UIImage, Bool) -> Void)?
    
    // Add body detection request
    private lazy var bodyDetectionRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()
    
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // We'll still setup the capture session, but won't start it until permissions are granted
        setupCaptureSession()
    }
    
    // MARK: - Setup
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        
        // Set quality level
        captureSession.sessionPreset = .photo
        
        // Setup camera input
        guard let device = getBestCamera() else {
            print("Failed to get camera device")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                deviceInput = input
                print("Camera input added successfully")
            } else {
                print("Could not add camera input to capture session")
                return
            }
        } catch {
            print("Error setting up camera input: \(error.localizedDescription)")
            return
        }
        
        // Setup video data output for preview stream
        videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            print("Video data output added successfully")
        }
        
        // Setup photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            print("Photo output added successfully")
            
            // Enable depth data delivery on the photo output
            if #available(iOS 11.0, *) {
                if photoOutput.isDepthDataDeliverySupported {
                    photoOutput.isDepthDataDeliveryEnabled = true
                    print("Depth data delivery enabled")
                } else {
                    print("Depth data delivery not supported")
                }
                
                if #available(iOS 12.0, *) {
                    if photoOutput.isPortraitEffectsMatteDeliverySupported {
                        photoOutput.isPortraitEffectsMatteDeliveryEnabled = true
                    }
                }
                
                if #available(iOS 13.0, *) {
                    photoOutput.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
                }
                
                if #available(iOS 14.0, *) {
                    photoOutput.maxPhotoQualityPrioritization = .quality
                }
            }
        }
        
        // Setup depth data output for real-time depth processing
        if #available(iOS 11.0, *) {
            if captureSession.canAddOutput(depthDataOutput) {
                captureSession.addOutput(depthDataOutput)
                depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
                depthDataOutput.isFilteringEnabled = true
                print("Depth data output added successfully")
            }
        }
        
        captureSession.commitConfiguration()
        
        // Create preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        print("Preview layer created")
        
    }
    
    private func getBestCamera() -> AVCaptureDevice? {
        print("Attempting to find best camera device")
        
        // Try to get TrueDepth front camera first (best for body scanning)
        if let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
            isUsingFrontCamera = true
            print("Found TrueDepth front camera: \(device.localizedName)")
            return device
        }
        
        // Fall back to dual camera if available
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            isUsingFrontCamera = false
            print("Found dual back camera: \(device.localizedName)")
            return device
        }
        
        // Try wide angle front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            isUsingFrontCamera = true
            print("Found wide angle front camera: \(device.localizedName)")
            return device
        }
        
        // Last resort: any wide angle back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            isUsingFrontCamera = false
            print("Found wide angle back camera: \(device.localizedName)")
            return device
        }
        
        print("No camera device found")
        return nil
    }
    
    // MARK: - Session Control
    
    // Add a session state property to track if session is ready
    @Published var isSessionRunning = false
    private var sessionStartTime: Date? = nil
    
    // Add a property to track camera permission status
    @Published var cameraPermissionGranted = false
    
    func startSession() {
        // First check camera permissions
        checkCameraPermissions { [weak self] granted in
            guard let self = self else { return }
            
            self.cameraPermissionGranted = granted
            
            // Only proceed if permission is granted
            if granted {
                if !self.captureSession.isRunning {
                    print("Starting camera session...")
                    self.sessionStartTime = Date()
                    print("Camera session state before starting: \(self.captureSession.isRunning)")
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        print("About to call startRunning() on background thread")
                        self.captureSession.startRunning()
                        print("startRunning() completed, checking state: \(self.captureSession.isRunning)")
                        
                        DispatchQueue.main.async {
                            self.isSessionRunning = self.captureSession.isRunning
                            print("Camera session state on main thread: \(self.captureSession.isRunning)")
                            print("isSessionRunning property updated to: \(self.isSessionRunning)")
                            
                            // Add a delayed check to see if the session state changes after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                print("Camera session state after 1 second: \(self.captureSession.isRunning)")
                            }
                        }
                    }
                } else {
                    self.isSessionRunning = true
                    print("Camera session already running")
                }
            } else {
                print("Camera permission denied - cannot start session")
                // Notify the view model that camera permission was denied
                DispatchQueue.main.async {
                    self.onCaptureError?(NSError(domain: "DepthCaptureManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"]))
                }
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            isSessionRunning = false
        }
    }
    
    // Check camera permissions and request if needed
    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("Current camera permission status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            // Permission already granted
            print("Camera permission already granted")
            completion(true)
            
        case .notDetermined:
            // Permission not requested yet, request it
            print("Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("Camera permission request result: \(granted)")
                completion(granted)
            }
            
        case .denied, .restricted:
            // Permission denied or restricted
            print("Camera permission denied or restricted")
            completion(false)
            
        @unknown default:
            print("Unknown camera permission status: \(status.rawValue)")
            completion(false)
        }
    }
    
    // MARK: - Capture Methods
    
    func capturePhoto() {
        // Check if the session is running before attempting to capture
        guard captureSession.isRunning else {
            print("Cannot capture photo - camera session is not running")
            onCaptureError?(NSError(domain: "com.checkmeout", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Camera session is not running"]))
            return
        }
        
        // Add a minimum delay to ensure the session is fully initialized
        if let startTime = sessionStartTime, Date().timeIntervalSince(startTime) < 1.0 {
            // If session was started less than 1 second ago, wait briefly
            print("Camera session just started, waiting briefly before capture...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.performPhotoCapture()
            }
            return
        }
        
        performPhotoCapture()
    }
    
    private func performPhotoCapture() {
        // Configure photo settings
        var photoSettings: AVCapturePhotoSettings
        
        if #available(iOS 11.0, *) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            
            // Enable depth data capture
            if photoOutput.isDepthDataDeliverySupported {
                photoSettings.isDepthDataDeliveryEnabled = true
                
                if #available(iOS 12.0, *) {
                    photoSettings.embedsDepthDataInPhoto = true
                }
            }
            
            // Enable portrait effects matte
            if #available(iOS 12.0, *) {
                if photoOutput.isPortraitEffectsMatteDeliverySupported {
                    photoSettings.isPortraitEffectsMatteDeliveryEnabled = true
                }
            }
            
            // Enable semantic segmentation mattes (for person segmentation)
            if #available(iOS 13.0, *) {
                if !photoOutput.availableSemanticSegmentationMatteTypes.isEmpty {
                    photoSettings.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
                }
            }
            
            // Set photo quality prioritization
            if #available(iOS 14.0, *) {
                photoSettings.photoQualityPrioritization = .balanced
            }
        } else {
            // Fallback for older iOS versions
            photoSettings = AVCapturePhotoSettings()
        }
        
        // Capture the photo
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    // MARK: - Utility Methods
    
    func normalizeDepthData(_ depthData: AVDepthData) -> CVPixelBuffer? {
        var convertedDepthData = depthData
        
        // Convert to 32-bit float depth data format if needed
        if depthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
            convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        }
        
        return convertedDepthData.depthDataMap
    }
    
    func createDepthMap(from depthData: AVDepthData, withSize size: CGSize) -> UIImage? {
        let depthPixelBuffer = normalizeDepthData(depthData)
        guard let pixelBuffer = depthPixelBuffer else { return nil }
        
        // Create CIImage from depth data
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create a false color representation
        let filter = CIFilter(name: "CIColorMap")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Create a gradient for visualization
        let gradientImage = createDepthGradientImage()
        filter?.setValue(CIImage(image: gradientImage), forKey: "inputGradientImage")
        
        guard let outputImage = filter?.outputImage else { return nil }
        
        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func createDepthGradientImage() -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 256, height: 1)
        
        // Color gradient from red (close) to blue (far)
        gradientLayer.colors = [
            UIColor.red.cgColor,
            UIColor.orange.cgColor,
            UIColor.yellow.cgColor,
            UIColor.green.cgColor,
            UIColor.blue.cgColor
        ]
        
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        
        UIGraphicsBeginImageContext(gradientLayer.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image ?? UIImage()
        }
        return UIImage()
    }
    
    // Alternative approach: Add methods to register observers
    
    func addSessionObserver(observer: Any, selector: Selector, name: NSNotification.Name) {
        NotificationCenter.default.addObserver(observer, selector: selector, name: name, object: captureSession)
    }
    
    func removeSessionObserver(observer: Any) {
        NotificationCenter.default.removeObserver(observer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension DepthCaptureManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            onCaptureError?(error)
            return
        }
        
        // Get the image data
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            onCaptureError?(NSError(domain: "DepthCaptureManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]))
            return
        }
        
        // Get depth data if available
        var depthMapImage: CVPixelBuffer?
        
        if #available(iOS 11.0, *) {
            // Check if depth data is available
            if let photoDepthData = photo.depthData {
                depthMapImage = normalizeDepthData(photoDepthData)
            }
        }
        
        // Call completion handler with captured image and depth data
        onPhotoCaptured?(image, depthMapImage)
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate

extension DepthCaptureManager: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Store the latest depth data for real-time processing
        currentDepthPixelBuffer = normalizeDepthData(depthData)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DepthCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Failed to get pixel buffer from sample buffer")
                return
            }
            
            // Log first frame received
            if frameCounter == 0 {
                print("First video frame received from camera")
            }
            
            // Create CIImage from pixel buffer
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Store the current color pixel buffer
            currentColorPixelBuffer = pixelBuffer
            
            // Send to preview stream
            addToPreviewStream?(ciImage)
            
            // Process for body detection (not on every frame to save resources)
            frameCounter += 1
            if frameCounter % 10 == 0 { // Process every 10th frame
                detectBodyInFrame(pixelBuffer)
            }
            
            // Log every 100 frames to confirm continuous operation
            if frameCounter % 100 == 0 {
                print("Received \(frameCounter) frames from camera")
            }
        }
    }
    
    private func detectBodyInFrame(_ pixelBuffer: CVPixelBuffer) {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            try requestHandler.perform([bodyDetectionRequest])
            
            if let results = bodyDetectionRequest.results, !results.isEmpty {
                // Check if we can see enough of the body
                let bodyPose = results[0]
                let bodyDetected = isFullBodyVisible(bodyPose)
                
                // Create a UIImage from the pixel buffer for the callback
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
                let image = UIImage(cgImage: cgImage)
                
                // Call the callback with the detection result
                onFrameProcessed?(image, bodyDetected)
            } else {
                // No body detected
                onFrameProcessed?(UIImage(), false)
            }
        } catch {
            print("Body detection failed: \(error.localizedDescription)")
            onFrameProcessed?(UIImage(), false)
        }
    }
    
    private func isFullBodyVisible(_ bodyPose: VNHumanBodyPoseObservation) -> Bool {
        // Check if key points are visible to determine if full body is in frame
        let jointsOfInterest: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .neck,
            .rightShoulder,
            .leftShoulder,
            .rightHip,
            .leftHip,
            .rightKnee,
            .leftKnee,
            .rightAnkle,
            .leftAnkle
        ]
        
        var visibleJointCount = 0
        
        for joint in jointsOfInterest {
            if let point = try? bodyPose.recognizedPoint(joint), point.confidence > 0.7 {
                visibleJointCount += 1
            }
        }
        
        // Consider full body visible if at least 8 out of 10 key joints are detected
        return visibleJointCount >= 8
    }
    
}
