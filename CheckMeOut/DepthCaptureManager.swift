//
//  DepthCaptureManager.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import AVFoundation
import UIKit
import CoreImage

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
    
    // MARK: - Initialization
    
    override init() {
        super.init()
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
        
        // Start the session immediately
        startSession()
    }
    
    private func getBestCamera() -> AVCaptureDevice? {
        // Try to get TrueDepth front camera first (best for body scanning)
        if let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
            isUsingFrontCamera = true
            return device
        }
        
        // Fall back to dual camera if available
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            isUsingFrontCamera = false
            return device
        }
        
        // Last resort: any wide angle camera
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        isUsingFrontCamera = device?.position == .front
        return device
    }
    
    // MARK: - Session Control
    
    func startSession() {
        if !captureSession.isRunning {
            print("Starting camera session...")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    print("Camera session started: \(self?.captureSession.isRunning ?? false)")
                }
            }
        } else {
            print("Camera session already running")
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Capture Methods
    
    func capturePhoto() {
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
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Create CIImage from pixel buffer
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Store the current color pixel buffer
            currentColorPixelBuffer = pixelBuffer
            
            // Send to preview stream
            addToPreviewStream?(ciImage)
        }
    }
} 
