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
    var totalPoints: Int?
    var gender: String?
    var age: Int?
    var height: Int?
    var weight: Int?
    var bodyFatPercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case username = "username"
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case totalPoints = "total_points"
    }
}

struct UpdateProfileParams: Codable {
    let username: String
    let fullName: String
    
    enum CodingKeys: String, CodingKey {
        case username = "username"
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

// Supabase roast model
struct SupabaseRoast: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let feedItemId: UUID
    let username: String?
    let createdAt: Date
    let text: String?
    let imageUrl: String?
    var likes: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case userId = "user_id"
        case feedItemId = "feed_item_id"
        case username = "username"
        case createdAt = "created_at"
        case text = "text"
        case imageUrl = "image_url"
        case likes = "likes"
    }
}

// Define a model for our activity feed items
struct FeedItem: Identifiable {
    let id: UUID
    let userId: UUID
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
    init(id: UUID = UUID(), userId: UUID = UUID(), username: String, userAvatar: String, activityType: String, timestamp: Date, imageData: Data?, likes: Int, comments: Int, points: Int, caption: String? = nil, roasts: [Roast] = []) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userAvatar = userAvatar
        self.activityType = activityType
        self.timestamp = timestamp
        self.imageData = imageData
        self.likes = likes
        self.comments = comments // number of comments on the post, not the comments themselves
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
    init(id: UUID = UUID(), userId: UUID = UUID(), username: String, userAvatar: String, activityType: String, timestamp: Date, imageData: Data?, likes: Int, comments: Int, points: Int, caption: String? = nil, originalPostID: UUID, threadResponseText: String?, threadResponseImageData: Data?, threadResponseLikes: Int = 0) {
        self.id = id
        self.userId = userId
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

// Supabase feed item model
struct SupabaseFeedItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let username: String
    let userAvatarUrl: String?
    let activityType: String
    let timestamp: Date
    let imageUrl: String?
    var likes: Int
    var comments: Int
    let points: Int
    let caption: String?
    var roasts: [SupabaseRoast]?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case userId = "user_id"
        case username = "username"
        case userAvatarUrl = "user_avatar_url"
        case activityType = "activity_type"
        case timestamp = "timestamp"
        case imageUrl = "image_url"
        case likes = "likes"
        case comments = "comments"
        case points = "points"
        case caption = "caption"
        case roasts = "roasts"
    }
}

// Define a model for our scan logs


struct Like: Codable {
    let id: UUID
    let userId: UUID
    let feedItemId: UUID
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case userId = "user_id"
        case feedItemId = "feed_item_id"
    }
}

struct LikeInsertPayload: Encodable {
    let userId: UUID
    let feedItemId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case feedItemId = "feed_item_id"
    }
}

// For tracking completed challenges
struct CompletedChallenge: Codable {
    let id: UUID
    let userId: UUID
    let challengeTitle: String
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case userId = "user_id"
        case challengeTitle = "challenge_title"
    }
}

struct CompletedChallengeInsertPayload: Encodable {
    let userId: UUID
    let challengeTitle: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case challengeTitle = "challenge_title"
    }
}

struct ScanLog: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let bodyFatPercentage: Double
    let frontImageData: Data?
    let sideImageData: Data?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), bodyFatPercentage: Double, frontImageData: Data? = nil, sideImageData: Data? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.bodyFatPercentage = bodyFatPercentage
        self.frontImageData = frontImageData
        self.sideImageData = sideImageData
    }
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: ScanLog, rhs: ScanLog) -> Bool {
        return lhs.id == rhs.id
    }
} 

// Supabase scan log model
struct SupabaseScanLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let timestamp: Date
    let bodyFatPercentage: Double
    let frontImageUrl: String?
    let sideImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case timestamp = "timestamp"
        case bodyFatPercentage = "body_fat_percentage"
        case frontImageUrl = "front_image_url"
        case sideImageUrl = "side_image_url"
    }
}
