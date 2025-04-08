//
//  ScanLogStore.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import SwiftUI

// Class to store and manage scan logs
class ScanLogStore: ObservableObject {
    @Published var scanLogs: [ScanLog] = []
    
    static let shared = ScanLogStore()
    
    private init() {
        // Private initializer for singleton
    }
    
    func addScanLog(bodyFatPercentage: Double, leanMusclePercentage: Double, 
                   visceralFatLevel: String, frontImage: UIImage?, sideImage: UIImage?) {
        // Convert images to data for storage
        let frontImageData = frontImage?.jpegData(compressionQuality: 0.7)
        let sideImageData = sideImage?.jpegData(compressionQuality: 0.7)
        
        let newLog = ScanLog(
            timestamp: Date(),
            bodyFatPercentage: bodyFatPercentage,
            leanMusclePercentage: leanMusclePercentage,
            visceralFatLevel: visceralFatLevel,
            frontImageData: frontImageData,
            sideImageData: sideImageData
        )
        
        scanLogs.append(newLog)
        
        // Also add to the app data store feed
        AppDataStore.shared.addScanLog(
            bodyFatPercentage: bodyFatPercentage,
            leanMusclePercentage: leanMusclePercentage,
            visceralFatLevel: visceralFatLevel,
            frontImage: frontImage,
            sideImage: sideImage
        )
    }
    
    func getScanLogs() -> [ScanLog] {
        return scanLogs
    }
    
    func clearAllLogs() {
        scanLogs.removeAll()
    }
}

// Note: ScanLog struct is now defined only in ContentView.swift 