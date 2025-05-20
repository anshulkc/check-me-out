//
//  DataSyncManager.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 5/11/25.
//

import Foundation
import SwiftUI
import Supabase
import Combine

// Temporary typealias to help with migration
typealias AppDataStore = SupabaseDataStore

extension Collection {
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var result = [T]()
        for element in self {
            if let transformed = try await transform(element) {
                result.append(transformed)
            }
        }
        return result
    }
}

/// Manages data synchronization between local storage and Supabase backend
class SupabaseDataStore: ObservableObject {
    @Published var scanLogs: [ScanLog] = []
    @Published var feedItems: [FeedItem] = []
    @Published var totalPoints: Int = 0
    @Published var completedChallenges: Set<String> = []
    @Published var likedPosts: Set<String> = []

    static let shared = SupabaseDataStore()
    
    private var cancellables = Set<AnyCancellable>()
    private let authViewModel = AuthViewModel()
    
    private init() {
        // Listen for authentication changes
        authViewModel.$isAuthenticated
        // .sink to react to the changes and weak self to avoid a retain cycle (prevent memory leaks by 
        // not strongly holding onto self.)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.loadUserData()
                    }
                } else {
                    self?.clearLocalData()
                }
            }
            .store(in: &cancellables)
    }

    private func clearLocalData() {
        scanLogs = []
        feedItems = []
        totalPoints = 0
        completedChallenges = []
        likedPosts = []
    }

    private func loadUserData() async {
        await loadScanLogs()
        await loadFeedItems()
        await loadCompletedChallenges()
        await loadLikedPosts()
        await loadUserPoints()
    }
}

extension SupabaseDataStore {
    func loadUserPoints() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
                
            if let profile = profiles.first {
                await MainActor.run {
                    self.totalPoints = profile.totalPoints ?? 0
                }
            }
        } catch {
            print("Error loading user points: \(error)")
        }
    }

    func updateUserPoints(points: Int) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Update points in Supabase
            try await supabase
                .from("profiles")
                .update(["total_points": self.totalPoints + points])
                .eq("id", value: userId)
                .execute()
                
            // Update local points
            await MainActor.run {
                self.totalPoints += points
            }
        } catch {
            print("Error updating user points: \(error)")
        }
    }

    func loadScanLogs() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Fetch scan logs from Supabase
            let response: [SupabaseScanLog] = try await supabase
                .from("scan_logs")
                .select()
                .eq("user_id", value: userId)
                .order("timestamp", ascending: false)
                .execute()
                .value
                
            // Convert to local model
            let logs = response.map { log -> ScanLog in
                return ScanLog(
                    id: log.id,
                    timestamp: log.timestamp,
                    bodyFatPercentage: log.bodyFatPercentage,
                    frontImageData: nil,  // Images will be loaded separately
                    sideImageData: nil
                )
            }
            
            // Update on main thread
            await MainActor.run {
                self.scanLogs = logs
            }
            
            // Load images for each scan log
            for log in logs {
                if let supabaseLog = response.first(where: { $0.id == log.id }) {
                    await loadScanLogImages(log: log, supabaseLog: supabaseLog)
                }
            }
        } catch {
            print("Error loading scan logs: \(error)")
        }
    }

    private func loadScanLogImages(log: ScanLog, supabaseLog: SupabaseScanLog) async {
        guard supabaseLog.frontImageUrl != nil || supabaseLog.sideImageUrl != nil else {
            return // No images to load
        }
        
        // Download front image if available
        var frontImageData: Data? = nil
        if let frontImageUrl = supabaseLog.frontImageUrl {
            frontImageData = await loadImageData(from: frontImageUrl)
        }
        
        // Download side image if available
        var sideImageData: Data? = nil
        if let sideImageUrl = supabaseLog.sideImageUrl {
            sideImageData = await loadImageData(from: sideImageUrl)
        }
        
        // Update the scan log with image data
        let localFrontImageData = frontImageData
        let localSideImageData = sideImageData

        await MainActor.run {
            if let index = self.scanLogs.firstIndex(where: { $0.id == log.id }) {
                // Create an updated scan log with images
                let updatedLog = ScanLog(
                    id: log.id,
                    timestamp: log.timestamp,
                    bodyFatPercentage: log.bodyFatPercentage,
                    frontImageData: localFrontImageData,
                    sideImageData: localSideImageData
                )
                
                // Replace the log without images with the updated one
                self.scanLogs[index] = updatedLog
            }
        }
        
    }

    func addScanLog(bodyFatPercentage: Double, frontImage: UIImage?, sideImage: UIImage?,
                   fromChallenge: Bool = false) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Upload images to storage if available
            var frontImageUrl: String? = nil
            var sideImageUrl: String? = nil
            
            if let frontImage = frontImage {
                frontImageUrl = await uploadImage(image: frontImage, path: "scan_logs/\(UUID().uuidString)-front.jpg")
            }
            
            if let sideImage = sideImage {
                sideImageUrl = await uploadImage(image: sideImage, path: "scan_logs/\(UUID().uuidString)-side.jpg")
            }
            
            let newScanLogId = UUID()
            let supabaseScanLogPayload = SupabaseScanLog(
                id: newScanLogId,
                userId: userId,
                timestamp: Date(),
                bodyFatPercentage: bodyFatPercentage,
                frontImageUrl: frontImageUrl,
                sideImageUrl: sideImageUrl
            )
            
            // Insert into Supabase
            try await supabase
                .from("scan_logs")
                .insert(supabaseScanLogPayload)
                .execute()
                
            // If insert was successful, proceed to update local model and UI
            // Use details from supabaseScanLogPayload as it contains the client-generated ID and timestamp
            let newLog = ScanLog(
                id: supabaseScanLogPayload.id, // Use ID from payload
                timestamp: supabaseScanLogPayload.timestamp, // Use timestamp from payload
                bodyFatPercentage: supabaseScanLogPayload.bodyFatPercentage,
                frontImageData: frontImage?.jpegData(compressionQuality: 0.7),
                sideImageData: sideImage?.jpegData(compressionQuality: 0.7)
            )
            
            // Update local data
            await MainActor.run {
                self.scanLogs.insert(newLog, at: 0)
            }
            
            // Also add to feed
            await addFeedItem(
                activityType: "bodycheck",
                imageData: frontImage?.jpegData(compressionQuality: 0.7),
                points: fromChallenge ? 100 : 75,
                imageUrl: frontImageUrl
            )
            
            // Update points
            await updateUserPoints(points: fromChallenge ? 100 : 75)
            
            // If from challenge, mark it as completed
            if fromChallenge {
                await completeChallenge("Post a scan of yourself")
            }
        } catch {
            print("Error adding scan log: \(error)")
        }
    }

    private func uploadImage(image: UIImage, path: String) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        do {
            _ = try await supabase.storage
                .from("images")
                .upload(path, data: imageData, // Corrected deprecated method
                    options: FileOptions(
                        cacheControl: "3600",
                        upsert: true
                    )
                )
            
            // Return public URL as String, ensure 'try' is present
            return try supabase.storage.from("images").getPublicURL(path: path).absoluteString
        } catch {
            print("Error uploading image: \(error)")
            return nil
        }
    }
    
    func loadFeedItems() async {
        do {
            // Fetch feed items from Supabase
            let response: [SupabaseFeedItem] = try await supabase
                .from("feed_items")
                .select("*, roasts(*)")
                .order("timestamp", ascending: false)
                .execute()
                .value
                
            // Convert to local model
            let items = await response.asyncCompactMap { item -> FeedItem? in
                // Convert roasts if any
                let roasts = await item.roasts?.asyncCompactMap { roast -> Roast? in
                    // Load roast image if available
                    var roastImageData: Data? = nil
                    if let imageUrl = roast.imageUrl {
                        roastImageData = await loadImageData(from: imageUrl)
                    }
                    
                    return Roast(
                        username: roast.username ?? "Unknown",
                        userAvatar: "person.circle.fill", // Default avatar
                        timestamp: roast.createdAt,
                        text: roast.text,
                        imageData: roastImageData,
                        likes: roast.likes
                    )
                } ?? []
                
                // Load feed item image if available
                var imageData: Data? = nil
                if let imageUrl = item.imageUrl {
                    imageData = await loadImageData(from: imageUrl)
                }
                
                return FeedItem(
                    id: item.id,
                    userId: item.userId,
                    username: item.username,
                    userAvatar: "person.circle.fill", // Default avatar
                    activityType: item.activityType,
                    timestamp: item.timestamp,
                    imageData: imageData,
                    likes: item.likes,
                    comments: item.comments,
                    points: item.points,
                    caption: item.caption,
                    roasts: roasts
                )
            }
            
            // Update on main thread
            await MainActor.run {
                self.feedItems = items
            }
        } catch {
            print("Error loading feed items: \(error)")
        }
    }

    func addFeedItem(activityType: String, imageData: Data? = nil, points: Int, caption: String? = nil, fromChallenge: Bool = false, imageUrl: String? = nil) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        guard let profile = authViewModel.userProfile else { return }
        
        do {
            // Upload image if provided but URL not available
            var finalImageUrl = imageUrl
            if imageUrl == nil, let imageData = imageData, let image = UIImage(data: imageData) {
                finalImageUrl = await uploadImage(image: image, path: "feed/\(UUID().uuidString).jpg")
            }
            
            let newFeedItemId = UUID()
            let supabaseFeedItemPayload = SupabaseFeedItem(
                id: newFeedItemId,
                userId: userId,
                username: profile.username ?? "User",
                userAvatarUrl: profile.avatarUrl,
                activityType: activityType,
                timestamp: Date(),
                imageUrl: finalImageUrl,
                likes: 0,
                comments: 0,
                points: points,
                caption: caption,
                roasts: nil // Roasts are handled separately
            )
            
            // Insert into Supabase
            try await supabase
                .from("feed_items")
                .insert(supabaseFeedItemPayload)
                .execute()
                
            // If insert was successful, proceed to update local model and UI
            // Use details from supabaseFeedItemPayload
            let newItem = FeedItem(
                id: newFeedItemId,
                userId: userId,
                username: supabaseFeedItemPayload.username,
                userAvatar: "person.circle.fill", // Default or fetch from profile if needed
                activityType: supabaseFeedItemPayload.activityType,
                timestamp: supabaseFeedItemPayload.timestamp, // Use timestamp from payload
                imageData: imageData, // imageData is already prepared
                likes: 0, // Initial likes
                comments: 0, // Initial comments
                points: supabaseFeedItemPayload.points,
                caption: supabaseFeedItemPayload.caption
            )
            
            await MainActor.run {
                self.feedItems.insert(newItem, at: 0)
            }
            
            // Update points
            await updateUserPoints(points: points)
            
            // If from challenge, mark it as completed
            if fromChallenge {
                await completeChallenge("Post a \(activityType)")
            }
        } catch {
            print("Error adding feed item: \(error)")
        }
    }

    private func loadImageData(from url: String) async -> Data? {
        guard let imageUrl = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            return data
        } catch {
            print("Error loading image data: \(error)")
            return nil
        }
    }

    func addRoastToPost(originalPost: FeedItem, responseText: String, responseImage: UIImage?) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        guard let profile = authViewModel.userProfile else { return }
        
        do {
            // Find the post in Supabase
            let feedItemsResponse: [SupabaseFeedItem] = try await supabase // Renamed to avoid conflict
                .from("feed_items")
                .select()
                .eq("id", value: originalPost.id.uuidString)
                .execute()
                .value
                
            guard let feedItemId = feedItemsResponse.first?.id else { // Use renamed variable
                print("Feed item not found in Supabase")
                return
            }
            
            // Upload image if available
            var imageUrl: String? = nil
            if let responseImage = responseImage {
                imageUrl = await uploadImage(image: responseImage, path: "roasts/\(UUID().uuidString).jpg")
            }
            
            let newRoastId = UUID()
            let supabaseRoastPayload = SupabaseRoast(
                id: newRoastId,
                userId: userId,
                feedItemId: feedItemId,
                username: profile.username ?? "User",
                createdAt: Date(),
                text: responseText.isEmpty ? nil : responseText,
                imageUrl: imageUrl,
                likes: 0
            )
            
            // Insert into Supabase
            try await supabase
                .from("roasts")
                .insert(supabaseRoastPayload)
                .execute()
            
            // If insert was successful, proceed to update local model and UI
            // Increment comments count on the feed item (server-side)
            try await supabase.rpc("increment_comments", params: ["item_id": feedItemId]).execute()
            
            // Convert image to data for local storage
            let responseImageData = responseImage?.jpegData(compressionQuality: 0.7)
            
            // Create local roast model using info from supabaseRoastPayload
            let newRoast = Roast(
                username: supabaseRoastPayload.username ?? "User",
                userAvatar: "person.circle.fill", // Default avatar
                timestamp: supabaseRoastPayload.createdAt, // Use timestamp from payload
                text: supabaseRoastPayload.text,
                imageData: responseImageData,
                likes: 0 // Initial likes
            )
            
            // Update local data
            await MainActor.run {
                if let index = self.feedItems.firstIndex(where: { $0.id == originalPost.id }) {
                    // Add the roast to the post
                    self.feedItems[index].roasts.append(newRoast)
                    
                    // Update the comments count
                    self.feedItems[index].comments += 1
                    
                    // Move the item to the top of the feed
                    let updatedItem = self.feedItems.remove(at: index)
                    self.feedItems.insert(updatedItem, at: 0)
                }
            }
        } catch {
            print("Error adding roast: \(error)")
        }
    }

    func loadLikedPosts() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Fetch likes from Supabase
            let response: [Like] = try await supabase
                .from("likes")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
                
            // Convert to set of liked post IDs
            let likedPostIds = Set(response.map { $0.feedItemId.uuidString })
            
            await MainActor.run {
                self.likedPosts = likedPostIds
            }
        } catch {
            print("Error loading liked posts: \(error)")
        }
    }
    
    // Toggle like on a post
    func toggleLike(for postID: UUID) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Find the post in Supabase to confirm existence and get its current server state if needed
            let supabaseFeedItems: [SupabaseFeedItem] = try await supabase
                .from("feed_items")
                .select()
                .eq("id", value: postID.uuidString)
                .execute()
                .value
                
            guard let supabaseFeedItem = supabaseFeedItems.first else {
                print("Feed item not found in Supabase for toggling like")
                return
            }
            let feedItemId = supabaseFeedItem.id // Use the ID from the fetched Supabase item
            
            let postIdString = postID.uuidString
            let isLikedLocally = likedPosts.contains(postIdString)
            
            if isLikedLocally {
                // Unlike the post
                try await supabase
                    .from("likes")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("feed_item_id", value: feedItemId)
                    .execute()
                    
                // Decrement likes count on server
                _ = try await supabase.rpc("decrement_likes", params: ["item_id": feedItemId]).execute()
                
                _ = await MainActor.run {
                    likedPosts.remove(postIdString)
                    if let index = self.feedItems.firstIndex(where: { $0.id == postID }) {
                        self.feedItems[index].likes -= 1
                    }
                }
            } else {
                // Like the post
                let likePayload = LikeInsertPayload(userId: userId, feedItemId: feedItemId)
                try await supabase
                    .from("likes")
                    .insert(likePayload)
                    .execute()
                    
                // Increment likes count on server
                _ = try await supabase.rpc("increment_likes", params: ["item_id": feedItemId]).execute()
                
                _ = await MainActor.run {
                    likedPosts.insert(postIdString)
                    if let index = self.feedItems.firstIndex(where: { $0.id == postID }) {
                        self.feedItems[index].likes += 1
                    }
                }
            }
        } catch {
            print("Error toggling like: \(error)")
        }
    }
    
    // Check if a post is liked
    func isPostLiked(_ postID: UUID) -> Bool {
        return likedPosts.contains(postID.uuidString)
    }

     func loadCompletedChallenges() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Fetch completed challenges from Supabase
            let response: [CompletedChallenge] = try await supabase
                .from("completed_challenges")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
                
            // Convert to set of challenge titles
            let challenges = Set(response.map { $0.challengeTitle })
            
            await MainActor.run {
                self.completedChallenges = challenges
            }
        } catch {
            print("Error loading completed challenges: \(error)")
        }
    }
    
    // Complete a challenge
    func completeChallenge(_ challengeTitle: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Check if already completed
            if completedChallenges.contains(challengeTitle) {
                return
            }
            
            // Mark as completed in Supabase
            let payload = CompletedChallengeInsertPayload(userId: userId, challengeTitle: challengeTitle)
            try await supabase
                .from("completed_challenges")
                .insert(payload)
                .execute() // No try needed if PostgrestResponse<Void> and not checking result for error
                
            await MainActor.run {
                completedChallenges.insert(challengeTitle)
            }
        } catch {
            print("Error completing challenge: \(error)")
        }
    }
    
    // Check if a challenge is completed
    func isChallengeCompleted(_ challengeTitle: String) -> Bool {
        return completedChallenges.contains(challengeTitle)
    }
}

extension SupabaseDataStore {
    // Sync method wrapper for addRoastToPost to match AppDataStore API
    func addRoastToPost(originalPost: FeedItem, responseText: String, responseImage: UIImage?) {
        Task {
            await addRoastToPost(originalPost: originalPost, responseText: responseText, responseImage: responseImage)
        }
    }
    
    // Sync method wrapper for addThreadedPost to match AppDataStore API
    func addThreadedPost(originalPost: FeedItem, responseText: String, responseImage: UIImage?) {
        addRoastToPost(originalPost: originalPost, responseText: responseText, responseImage: responseImage)
    }
    
    // Simplified toggle like method for local operations
    func toggleLike(for postID: UUID, isThreadResponse: Bool = false) {
        // If it's a thread response (legacy), handle locally
        if isThreadResponse {
            handleLegacyThreadResponseLike(for: postID)
        } else {
            // For regular posts, call the async method
            Task {
                await toggleLike(for: postID)
            }
        }
    }
    
    // Handle legacy thread response likes (only used for backward compatibility)
    private func handleLegacyThreadResponseLike(for postID: UUID) {
        let likeID = "\(postID)-response"
        
        // Find the post
        if let index = feedItems.firstIndex(where: { $0.id == postID }) {
            // Check if already liked
            if likedPosts.contains(likeID) {
                // Unlike
                feedItems[index].threadResponseLikes -= 1
                likedPosts.remove(likeID)
            } else {
                // Like
                feedItems[index].threadResponseLikes += 1
                likedPosts.insert(likeID)
            }
            objectWillChange.send()
        }
    }
    
    // Extended isPostLiked to handle thread responses
    func isPostLiked(_ postID: UUID, isThreadResponse: Bool = false) -> Bool {
        if isThreadResponse {
            let likeID = "\(postID)-response"
            return likedPosts.contains(likeID)
        } else {
            return likedPosts.contains(postID.uuidString)
        }
    }
    
    // Helper method to add sample data for development
    func addSampleFeedItems() {
        Task {
            // Only add sample items if feed is empty
            if feedItems.isEmpty {
                await addFeedItem(
                    activityType: "meal",
                    imageData: nil,
                    points: 50,
                    caption: "Healthy breakfast",
                    fromChallenge: false
                )
                
                await addFeedItem(
                    activityType: "workout",
                    imageData: nil,
                    points: 100,
                    caption: "Morning run",
                    fromChallenge: false
                )
            }
        }
    }
    
    // Sync wrapper for addFeedItem to match AppDataStore API
    func addFeedItem(username: String, userAvatar: String, activityType: String, imageData: Data?, 
                     points: Int, caption: String? = nil, fromChallenge: Bool = false) {
        Task {
            await addFeedItem(
                activityType: activityType,
                imageData: imageData,
                points: points,
                caption: caption,
                fromChallenge: fromChallenge
            )
        }
    }
    
    // Sync wrapper for addScanLog to match AppDataStore API
    func addScanLog(bodyFatPercentage: Double, frontImage: UIImage?, sideImage: UIImage?, 
                   fromChallenge: Bool = false) {
        Task {
            await addScanLog(
                bodyFatPercentage: bodyFatPercentage,
                frontImage: frontImage,
                sideImage: sideImage,
                fromChallenge: fromChallenge
            )
        }
    }

    func deleteFeedItem(feedItemToDelete: FeedItem) async {
        guard let currentUserId = authViewModel.currentUser?.id else {
            print("Error: User not authenticated. Cannot delete feed item.")
            return
        }

        let feedItemId = feedItemToDelete.id

        do {
            // 1. Fetch the SupabaseFeedItem to get its details and verify ownership
            let fetchedSupabaseFeedItems: [SupabaseFeedItem] = try await supabase
                .from("feed_items")
                .select()
                .eq("id", value: feedItemId)
                .limit(1) // Expecting only one item
                .execute()
                .value

            guard let supabaseFeedItem = fetchedSupabaseFeedItems.first else {
                print("Error: Feed item with ID \(feedItemId) not found in Supabase. Cannot delete.")
                return
            }

            // 2. Authorization Check: Ensure the current user owns the post
            guard supabaseFeedItem.userId == currentUserId else {
                print("Error: User \(currentUserId) is not authorized to delete feed item \(feedItemId) owned by \(supabaseFeedItem.userId).")
                // Potentially show an alert to the user or handle this more gracefully
                return
            }

            // 3. Delete Associated Roasts and their Images
            let roastsToDelete: [SupabaseRoast] = try await supabase
                .from("roasts")
                .select()
                .eq("feed_item_id", value: feedItemId)
                .execute()
                .value

            for roast in roastsToDelete {
                if let roastImageUrl = roast.imageUrl {
                    await deleteImageFromStorage(publicUrl: roastImageUrl, bucketName: "images")
                }
            }
            if !roastsToDelete.isEmpty {
                try await supabase
                    .from("roasts")
                    .delete()
                    .eq("feed_item_id", value: feedItemId)
                    .execute()
            }

            // 4. Delete Main Feed Item Image from Storage
            if let feedItemImageUrl = supabaseFeedItem.imageUrl {
                await deleteImageFromStorage(publicUrl: feedItemImageUrl, bucketName: "images")
            }

            // 5. Delete Associated Likes
            try await supabase
                .from("likes")
                .delete()
                .eq("feed_item_id", value: feedItemId)
                .execute()

            // 6. Delete the Feed Item Record itself
            try await supabase
                .from("feed_items")
                .delete()
                .eq("id", value: feedItemId)
                .execute()

            // 7. Update Local Data
            await MainActor.run {
                self.feedItems.removeAll { $0.id == feedItemToDelete.id }
                print("Feed item \(feedItemId) and its associated data deleted successfully.")
            }

        } catch {
            print("Error deleting feed item \(feedItemId): \(error)")
            // Potentially show an error message to the user
        }
    }

    private func deleteImageFromStorage(publicUrl: String?, bucketName: String) async {
        guard let publicUrlString = publicUrl, let url = URL(string: publicUrlString) else {
            // print("Invalid or missing public URL for image deletion.")
            return
        }

        // Assuming the path is the part of the URL after the bucket name
        // e.g., https://<ref>.supabase.co/storage/v1/object/public/images/feed/image.jpg -> path is "feed/image.jpg"
        let pathComponents = url.pathComponents
        if let bucketIndex = pathComponents.firstIndex(of: bucketName), bucketIndex + 1 < pathComponents.count {
            let imagePath = pathComponents.suffix(from: bucketIndex + 1).joined(separator: "/")
            
            if imagePath.isEmpty {
                // print("Could not extract a valid image path from URL: \(publicUrlString)")
                return
            }

            // print("Attempting to delete image from storage at path: \(imagePath) in bucket: \(bucketName)")
            do {
                _ = try await supabase.storage
                    .from(bucketName)
                    .remove(paths: [imagePath])
                // print("Successfully deleted image from storage: \(imagePath)")
            } catch {
                print("Error deleting image from storage path \(imagePath) in bucket \(bucketName): \(error)")
            }
        } else {
            // print("Could not determine image path from URL: \(publicUrlString) for bucket: \(bucketName)")
        }
    }
}
