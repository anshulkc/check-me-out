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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.username)
                        .font(.headline)
                    
                    Text(timeAgo(from: item.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Points badge
                if item.points != 0 {
                    Text(item.points > 0 ? "+\(item.points)" : "\(item.points)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.points > 0 ? Color.black : Color.red)
                        .cornerRadius(12)
                }
            }
            
            // Caption if available
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .padding(.vertical, 4)
            }
            
            // Image if available
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            }
            
            // Activity type, likes and comments
            HStack {
                Text(activityTypeText(item.activityType))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
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
    
    private func timeAgo(from date: Date) -> String {
        let hours = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? 0
        if hours < 1 {
            return "Just now"
        } else if hours < 2 {
            return "1h ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(hours / 24)d ago"
        }
    }
    
    private func activityTypeText(_ type: String) -> String {
        switch type {
        case "meal":
            return "Meal Photo"
        case "workout":
            return "Workout Photo"
        case "bodycheck":
            return "Body Check Photo"
        default:
            return "Activity Photo"
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
