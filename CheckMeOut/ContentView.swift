//
//  ContentView.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 4/2/25.
//

import SwiftUI
import CoreData

// Create a shared data model to store scan logs and feed
class AppDataStore: ObservableObject {
    @Published var scanLogs: [ScanLog] = []
    @Published var feedItems: [FeedItem] = []
    @Published var totalPoints: Int = 1250
    
    static let shared = AppDataStore()
    
    init() {
        // Add some sample feed items
        if feedItems.isEmpty {
            addSampleFeedItems()
        }
    }
    
    func addScanLog(bodyFatPercentage: Double, leanMusclePercentage: Double, 
                   visceralFatLevel: String, frontImage: UIImage?, sideImage: UIImage?) {
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
        
        // Also add to feed
        addFeedItem(username: "You", userAvatar: "person.circle.fill", activityType: "bodycheck", imageData: frontImageData, points: 75)
        
        // Add points
        totalPoints += 75
    }
    
    func addFeedItem(username: String, userAvatar: String, activityType: String, imageData: Data?, points: Int, caption: String? = nil) {
        let newItem = FeedItem(
            username: username,
            userAvatar: userAvatar,
            activityType: activityType,
            timestamp: Date(),
            imageData: imageData,
            likes: Int.random(in: 0...30),
            comments: Int.random(in: 0...5),
            points: points,
            caption: caption
        )
        
        feedItems.insert(newItem, at: 0)
    }
    
    private func addSampleFeedItems() {
        // Add sample feed items similar to the image
        addFeedItem(username: "John D.", userAvatar: "person.circle.fill", activityType: "meal", imageData: nil, points: 50)
        addFeedItem(username: "Sarah M.", userAvatar: "person.circle.fill", activityType: "workout", imageData: nil, points: 100)
    }
    
    func addThreadedPost(originalPost: FeedItem, responseText: String, responseImage: UIImage?) {
        let responseImageData = responseImage?.jpegData(compressionQuality: 0.7)
        
        // Create a new threaded post
        let newItem = FeedItem(
            username: "You",
            userAvatar: "person.circle.fill",
            activityType: "thread",
            timestamp: Date(),
            imageData: originalPost.imageData,
            likes: Int.random(in: 0...30),
            comments: Int.random(in: 0...5),
            points: 100,
            caption: originalPost.caption,
            originalPostID: originalPost.id,
            threadResponseText: responseText.isEmpty ? nil : responseText,
            threadResponseImageData: responseImageData
        )
        
        // Add to the beginning of the feed
        feedItems.insert(newItem, at: 0)
    }
}

struct ContentView: View {
    @ObservedObject private var dataStore = AppDataStore.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Points and profile section
                    HStack {
                        Text("Track Progress")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Points pill
                        HStack(spacing: 4) {
                            Text("\(dataStore.totalPoints) pts")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.darkGray))
                        .cornerRadius(20)
                        
                        // Profile icon
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Quick action buttons
                    HStack(spacing: 15) {
                        NavigationLink(destination: MealLogView()) {
                            QuickActionButtonContent(icon: "fork.knife", title: "Log Meal")
                        }
                        
                        NavigationLink(destination: WorkoutLogView()) {
                            QuickActionButtonContent(icon: "dumbbell", title: "Log\nWorkout")
                        }
                        
                        NavigationLink(destination: BodyScanView()) {
                            QuickActionButtonContent(icon: "camera", title: "Body\nCheck")
                        }
                        
                        NavigationLink(destination: FriendRoastView()) {
                            QuickActionButtonContent(icon: "flame.fill", title: "Roast\nFriend")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Today's feed section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today's Feed")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        // Feed items
                        ForEach(dataStore.feedItems) { item in
                            FeedItemView(item: item)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(icon: icon, title: title)
        }
    }
}

struct QuickActionButtonContent: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(.black)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct FeedItemView: View {
    let item: FeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info and timestamp
            HStack {
                Image(systemName: item.userAvatar)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(timeAgo(from: item.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Activity type badge
                Text(activityTypeText(item.activityType))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Caption if available
            if let caption = item.caption {
                Text(caption)
                    .font(.subheadline)
            }
            
            // Image if available
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            }
            
            // Thread response if this is a threaded post
            if item.isThreaded {
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 2)
                        .padding(.leading, 18)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let responseText = item.threadResponseText {
                            Text(responseText)
                                .font(.subheadline)
                                .padding(.leading, 8)
                        }
                        
                        if let responseImageData = item.threadResponseImageData, 
                           let responseImage = UIImage(data: responseImageData) {
                            Image(uiImage: responseImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            
            // Points, likes, comments
            HStack {
                // Points display
                HStack {
                    Text("\(item.points > 0 ? "+" : "")\(item.points) pts")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.points >= 0 ? Color.black : Color.red)
                .cornerRadius(12)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(item.likes)", systemImage: "heart")
                        .font(.caption)
                    
                    Label("\(item.comments)", systemImage: "bubble.right")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // Helper functions
    func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour == 1 ? "" : "s") ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) minute\(minute == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
    
    func activityTypeText(_ type: String) -> String {
        switch type {
        case "meal":
            return "Meal"
        case "workout":
            return "Workout"
        case "bodycheck":
            return "Body Check"
        case "roast":
            return "Roast"
        case "thread":
            return "Thread"
        case "shamed":
            return "Shamed"
        default:
            return type.capitalized
        }
    }
}

// Keep the existing ScanLog-related views
struct ScanDetailView: View {
    let log: ScanLog
    
    var body: some View {
        // Existing implementation
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Scan Results")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)
                
                Group {
                    ResultRow(title: "Body Fat", value: String(format: "%.1f%%", log.bodyFatPercentage))
                    ResultRow(title: "Lean Muscle", value: String(format: "%.1f%%", log.leanMusclePercentage))
                    ResultRow(title: "Visceral Fat", value: log.visceralFatLevel)
                    ResultRow(title: "Scan Date", value: log.timestamp.formatted(date: .long, time: .shortened))
                }
                
                Text("Scan Images")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                HStack {
                    VStack {
                        if let frontImageData = log.frontImageData, 
                           let uiImage = UIImage(data: frontImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .overlay(
                                    Text("No front image")
                                        .foregroundColor(.gray)
                                )
                        }
                        Text("Front View")
                            .font(.caption)
                    }
                    
                    VStack {
                        if let sideImageData = log.sideImageData, 
                           let uiImage = UIImage(data: sideImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .overlay(
                                    Text("No side image")
                                        .foregroundColor(.gray)
                                )
                        }
                        Text("Side View")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
