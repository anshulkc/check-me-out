//
//  Models.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import Foundation
import SwiftUI

// MARK: - Supabase Models

// Profile model for Supabase integration
struct Profile: Codable {
    let id: UUID
    var username: String?
    var fullName: String?
    var avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

struct UpdateProfileParams: Codable {
    let username: String
    let fullName: String
    
    enum CodingKeys: String, CodingKey {
        case username
        case fullName = "full_name"
    }
}

// MARK: - App Models

// Define a model for roast/response attached to a post
struct Roast: Identifiable {
    let id = UUID()
    let username: String
    let userAvatar: String // system image name
    let timestamp: Date
    let text: String?
    let imageData: Data?
    var likes: Int
    
    init(username: String, userAvatar: String, timestamp: Date = Date(), text: String? = nil, imageData: Data? = nil, likes: Int = 0) {
        self.username = username
        self.userAvatar = userAvatar
        self.timestamp = timestamp
        self.text = text
        self.imageData = imageData
        self.likes = likes
    }
}

// Define a model for our activity feed items
struct FeedItem: Identifiable {
    let id = UUID()
    let username: String
    let userAvatar: String // system image name
    let activityType: String // "meal", "workout", "bodycheck"
    let timestamp: Date
    let imageData: Data?
    var likes: Int
    var comments: Int
    let points: Int
    let caption: String? // Optional caption for posts
    
    // For storing roasts directly on the original post
    var roasts: [Roast]
    
    // Keeping these for backward compatibility
    let isThreaded: Bool
    let originalPostID: UUID?
    let threadResponseText: String?
    let threadResponseImageData: Data?
    var threadResponseLikes: Int
    
    // Default initializer for regular posts
    init(username: String, userAvatar: String, activityType: String, timestamp: Date, imageData: Data?, likes: Int, comments: Int, points: Int, caption: String? = nil, roasts: [Roast] = []) {
        self.username = username
        self.userAvatar = userAvatar
        self.activityType = activityType
        self.timestamp = timestamp
        self.imageData = imageData
        self.likes = likes
        self.comments = comments
        self.points = points
        self.caption = caption
        self.roasts = roasts
        self.isThreaded = false
        self.originalPostID = nil
        self.threadResponseText = nil
        self.threadResponseImageData = nil
        self.threadResponseLikes = 0
    }
    
    // Initializer for threaded posts (for backward compatibility)
    init(username: String, userAvatar: String, activityType: String, timestamp: Date, imageData: Data?, likes: Int, comments: Int, points: Int, caption: String? = nil, originalPostID: UUID, threadResponseText: String?, threadResponseImageData: Data?, threadResponseLikes: Int = 0) {
        self.username = username
        self.userAvatar = userAvatar
        self.activityType = activityType
        self.timestamp = timestamp
        self.imageData = imageData
        self.likes = likes
        self.comments = comments
        self.points = points
        self.caption = caption
        self.roasts = []
        self.isThreaded = true
        self.originalPostID = originalPostID
        self.threadResponseText = threadResponseText
        self.threadResponseImageData = threadResponseImageData
        self.threadResponseLikes = threadResponseLikes
    }
}

// Define a model for our scan logs
struct ScanLog: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let bodyFatPercentage: Double
    let leanMusclePercentage: Double
    let visceralFatLevel: String
    let frontImageData: Data?
    let sideImageData: Data?
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: ScanLog, rhs: ScanLog) -> Bool {
        return lhs.id == rhs.id
    }
} 