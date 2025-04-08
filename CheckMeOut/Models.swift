//
//  Models.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import Foundation
import SwiftUI

// Define a model for our activity feed items
struct FeedItem: Identifiable {
    let id = UUID()
    let username: String
    let userAvatar: String // system image name
    let activityType: String // "meal", "workout", "bodycheck"
    let timestamp: Date
    let imageData: Data?
    let likes: Int
    let comments: Int
    let points: Int
    let caption: String? // Optional caption for posts
}

// Define a model for our scan logs
struct ScanLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bodyFatPercentage: Double
    let leanMusclePercentage: Double
    let visceralFatLevel: String
    let frontImageData: Data?
    let sideImageData: Data?
} 