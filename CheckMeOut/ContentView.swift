//
//  ContentView.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 4/2/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @ObservedObject private var dataStore = SupabaseDataStore.shared
    @State private var navigationPath = NavigationPath()

    var body: some View {
            NavigationStack(path: $navigationPath) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Points and profile section
                        HStack {
                            Text("Track Progress")
                                .font(.quicksand(size: 22))
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            // Points pill
                            HStack(spacing: 4) {
                                Text("\(dataStore.totalPoints) pts")
                                    .font(.poetsen(size: 16))
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
                            /* Button {
                                navigationPath.append("mealLog")
                            } label: {
                                QuickActionButtonContent(icon: "fork.knife", title: "Log\nMeal")
                            } */
                            
                            Button {
                                navigationPath.append("workoutLog")
                            } label: {
                                QuickActionButtonContent(icon: "dumbbell", title: "Log\nWorkout")
                            }

                            // making the grass green
                            
                            Button {
                                navigationPath.append("bodyScan")
                            } label: {
                                QuickActionButtonContent(icon: "camera", title: "Body\nCheck")
                            }
                            
                            Button {
                                navigationPath.append("friendRoast")
                            } label: {
                                QuickActionButtonContent(icon: "flame.fill", title: "Roast\nFriend")
                            }
                        }
                        .padding(.horizontal)
                        
                        // Today's feed section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today's Feed")
                                .font(.quicksand(size: 22))
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            // Feed items
                            ForEach(dataStore.feedItems.prefix(5)) { item in
                                FeedItemView(item: item)
                            }
                            
                            Button {
                                navigationPath.append("allFeed")
                            } label: {
                                Text("View All")
                                    .font(.quicksand(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Recent scans section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Recent Scans")
                                .font(.quicksand(size: 22))
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            if dataStore.scanLogs.isEmpty {
                                Text("No scans yet. Take your first body scan to track your progress!")
                                    .font(.quicksand(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(dataStore.scanLogs.prefix(3)) { log in
                                        Button {
                                            navigationPath.append(log)
                                        } label: {
                                            ScanLogRow(log: log)
                                        }
                                    }
                                }
                                .padding(.horizontal, 0)
                                
                                if dataStore.scanLogs.count > 3 {
                                    Button {
                                        navigationPath.append("allScans")
                                    } label: {
                                        Text("View All Scans")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("CheckMeOut")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("CheckMeOut")
                            .font(.quicksand(size: 16))
                            .foregroundColor(.primary)
                    }
                }
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "mealLog":
                        MealLogView()
                    case "workoutLog":
                        WorkoutLogView()
                    case "bodyScan":
                        BodyScanView()
                    case "friendRoast":
                        FriendRoastView()
                    case "allFeed":
                        AllFeedView()
                    case "allScans":
                        Text("All Scans")
                    default:
                        Text("Page not found")
                    }
                }
                .navigationDestination(for: ScanLog.self) { log in
                    ScanDetailView(log: log)
                }
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
                .font(.quicksand(size: 14))
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
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingDeleteConfirmation = false

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
                        .font(.quicksand(size: 14))
                        .fontWeight(.semibold)
                    
                    Text(timeAgo(from: item.timestamp))
                        .font(.quicksand(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Activity type badge
                Text(activityTypeText(item.activityType))
                    .font(.quicksand(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Caption if available
            if let caption = item.caption {
                Text(caption)
                    .font(.quicksand(size: 14))
            }
            
            // Image if available
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            }
            
            // Show roasts attached to this post
            if !item.roasts.isEmpty || item.isThreaded {
                Divider()
                    .padding(.vertical, 4)
                
                // For backward compatibility, show threaded post if present
                if item.isThreaded && item.threadResponseText != nil {
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 2)
                            .padding(.leading, 18)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if let responseText = item.threadResponseText {
                                Text(responseText)
                                    .font(.quicksand(size: 14))
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
                            
                            // Thread response like button
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    SupabaseDataStore.shared.toggleLike(for: item.id, isThreadResponse: true)
                                }) {
                                    Label("\(item.threadResponseLikes)", systemImage: SupabaseDataStore.shared.isPostLiked(item.id, isThreadResponse: true) ? "heart.fill" : "heart")
                                        .font(.caption)
                                        .foregroundColor(SupabaseDataStore.shared.isPostLiked(item.id, isThreadResponse: true) ? .red : .black)
                                }
                                .padding(.trailing, 8)
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    if !item.roasts.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
                
                // Show all roasts
                ForEach(item.roasts) { roast in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 2)
                            .padding(.leading, 18)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Header with username and timestamp
                            HStack {
                                Image(systemName: roast.userAvatar)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.gray)
                                
                                Text(roast.username)
                                    .font(.quicksand(size: 13))
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(timeAgo(from: roast.timestamp))
                                    .font(.quicksand(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 8)
                            
                            // Roast text if available
                            if let text = roast.text {
                                Text(text)
                                    .font(.tagesschrift(size: 14))
                                    .padding(.leading, 8)
                            }
                            
                            // Roast image if available
                            if let imageData = roast.imageData, 
                               let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                                    .padding(.leading, 8)
                            }
                            
                            // Roast like button
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    // For now, we'll just use the index in the array to identify the roast
                                    if let index = item.roasts.firstIndex(where: { $0.id == roast.id }) {
                                        let likeID = "\(item.id)-roast-\(index)"
                                        if SupabaseDataStore.shared.likedPosts.contains(likeID) {
                                            // Unlike
                                            SupabaseDataStore.shared.likedPosts.remove(likeID)
                                            if let postIndex = SupabaseDataStore.shared.feedItems.firstIndex(where: { $0.id == item.id }) {
                                                SupabaseDataStore.shared.feedItems[postIndex].roasts[index].likes -= 1
                                            }
                                        } else {
                                            // Like
                                            SupabaseDataStore.shared.likedPosts.insert(likeID)
                                            if let postIndex = SupabaseDataStore.shared.feedItems.firstIndex(where: { $0.id == item.id }) {
                                                SupabaseDataStore.shared.feedItems[postIndex].roasts[index].likes += 1
                                            }
                                        }
                                        SupabaseDataStore.shared.objectWillChange.send()
                                    }
                                }) {
                                    let likeID = "\(item.id)-roast-\(item.roasts.firstIndex(where: { $0.id == roast.id }) ?? 0)"
                                    Label("\(roast.likes)", systemImage: SupabaseDataStore.shared.likedPosts.contains(likeID) ? "heart.fill" : "heart")
                                        .font(.caption)
                                        .foregroundColor(SupabaseDataStore.shared.likedPosts.contains(likeID) ? .red : .black)
                                }
                                .padding(.trailing, 8)
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    if roast.id != item.roasts.last?.id {
                        Divider()
                            .padding(.vertical, 2)
                            .padding(.leading, 28)
                    }
                }
            }
            
            // Points, likes, comments
            HStack {
                // Points display
                HStack {
                    Text("\(item.points > 0 ? "+" : "")\(item.points) pts")
                        .font(.poetsen(size: 12))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.points >= 0 ? Color.black : Color.red)
                .cornerRadius(12)
                
                Spacer()
                
                Button(action: {
                    SupabaseDataStore.shared.toggleLike(for: item.id)
                }) {
                    Label("\(item.likes)", systemImage: SupabaseDataStore.shared.isPostLiked(item.id) ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(SupabaseDataStore.shared.isPostLiked(item.id) ? .red : .black)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .gesture(
            LongPressGesture(minimumDuration: 1.0)
                .onEnded { _ in
                    if let currentUserID = authViewModel.currentUser?.id, item.userId == currentUserID {
                        self.showingDeleteConfirmation = true
                    }
                }
        )
        .alert("Delete Post", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await SupabaseDataStore.shared.deleteFeedItem(feedItemToDelete: item)
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete this post and all its associated roasts?")
        }
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
// ScanLogRow component for displaying scan logs in a list
struct ScanLogRow: View {
    let log: ScanLog
    
    var body: some View {
        HStack {
            // Thumbnail of front image
            if let imageData = log.frontImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate(log.timestamp))
                    .font(.tagesschriftHeadline)
                
                Text("Body Fat: \(String(format: "%.1f%%", log.bodyFatPercentage))")
                    .font(.tagesschriftSubheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct ScanDetailView: View {
    let log: ScanLog
    
    var body: some View {
        // Existing implementation
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Scan Results")
                    .font(.tagesschriftTitle)
                    .bold()
                    .padding(.top)
                
                Group {
                    ResultRow(title: "Body Fat", value: String(format: "%.1f%%", log.bodyFatPercentage))
                    ResultRow(title: "Scan Date", value: log.timestamp.formatted(date: .long, time: .shortened))
                }
                
                Text("Scan Images")
                    .font(.tagesschriftTitle2)
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
