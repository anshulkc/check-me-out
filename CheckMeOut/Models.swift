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
    let activityType: String // "meal", "workout", "bodycheck", "roast", "thread"
    let timestamp: Date
    let imageData: Data?
    let likes: Int
    let comments: Int
    let points: Int
    let caption: String? // Optional caption for posts
    
    // For threaded posts
    let isThreaded: Bool
    let originalPostID: UUID?
    let threadResponseText: String?
    let threadResponseImageData: Data?
    
    // Default initializer for regular posts
    init(username: String, userAvatar: String, activityType: String, timestamp: Date, imageData: Data?, likes: Int, comments: Int, points: Int, caption: String? = nil) {
        self.username = username
        self.userAvatar = userAvatar
        self.activityType = activityType
        self.timestamp = timestamp
        self.imageData = imageData
        self.likes = likes
        self.comments = comments
        self.points = points
        self.caption = caption
        self.isThreaded = false
        self.originalPostID = nil
        self.threadResponseText = nil
        self.threadResponseImageData = nil
    }
    
    // Initializer for threaded posts
    init(username: String, userAvatar: String, activityType: String, timestamp: Date, imageData: Data?, likes: Int, comments: Int, points: Int, caption: String? = nil, originalPostID: UUID, threadResponseText: String?, threadResponseImageData: Data?) {
        self.username = username
        self.userAvatar = userAvatar
        self.activityType = activityType
        self.timestamp = timestamp
        self.imageData = imageData
        self.likes = likes
        self.comments = comments
        self.points = points
        self.caption = caption
        self.isThreaded = true
        self.originalPostID = originalPostID
        self.threadResponseText = threadResponseText
        self.threadResponseImageData = threadResponseImageData
    }
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