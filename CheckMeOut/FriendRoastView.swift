//
//  FriendRoastView.swift
//  CheckMeOut
//
//  Created for friend roasting functionality
//

import SwiftUI
import UIKit

struct FriendRoastView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataStore = AppDataStore.shared
    @State private var selectedPost: FeedItem? = nil
    @State private var responseText = ""
    @State private var showingMemeOptions = false
    @State private var showingImagePicker = false
    @State private var customMemeImage: UIImage? = nil
    @State private var showingAlert = false
    @State private var viewAppeared = false
    var fromChallenge: Bool = false
    
    // Filter posts from friends (not your own posts)
    var friendPosts: [FeedItem] {
        // The viewAppeared property is accessed to ensure this computed property
        // is reevaluated whenever the view appears
        _ = viewAppeared
        
        return dataStore.feedItems
        // .filter { 
         //   $0.username != "You" 
       // }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    Text("Respond to Posts")
                        .font(.tagesschriftTitle2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // Instructions
                    Text("Scroll through posts and select one to respond to")
                        .font(.tagesschriftSubheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Friend posts feed
                    if friendPosts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No posts to respond to yet")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(friendPosts) { post in
                                SelectableFeedItemView(post: post, isSelected: selectedPost?.id == post.id) {
                                    if selectedPost?.id == post.id {
                                        selectedPost = nil
                                    } else {
                                        selectedPost = post
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if let selectedPost = selectedPost {
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Show selected post preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Selected Post")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                Image(systemName: selectedPost.userAvatar)
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selectedPost.username)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(FriendRoastView.activityTypeText(selectedPost.activityType))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            if let caption = selectedPost.caption {
                                Text(caption)
                                    .font(.subheadline)
                                    .padding(.horizontal)
                            }
                            
                            if let imageData = selectedPost.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            } else {
                                // Placeholder for posts without images
                                VStack(spacing: 12) {
                                    Image(systemName: FriendRoastView.activityTypeIcon(selectedPost.activityType))
                                        .font(.system(size: 46))
                                        .foregroundColor(.gray)
                                    Text("No image for this post")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Response options
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Response")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Text response option
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Write your response")
                                    .font(.subheadline)
                                
                                TextField("Your comment...", text: $responseText)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            // Meme options
                            Button(action: {
                                showingMemeOptions = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Create or Choose Meme")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            .actionSheet(isPresented: $showingMemeOptions) {
                                ActionSheet(
                                    title: Text("Meme Options"),
                                    buttons: [
                                        .default(Text("Take Photo")) {
                                            showingImagePicker = true
                                        },
                                        .default(Text("Choose from Library")) {
                                            // Would implement meme template selection
                                            customMemeImage = UIImage(named: "sample_meme")
                                        },
                                        .cancel()
                                    ]
                                )
                            }
                            
                            // Preview of selected meme
                            if let memeImage = customMemeImage {
                                Image(uiImage: memeImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                            
                            // Submit button
                            Button(action: submitResponse) {
                                Text("Send Response (+\(fromChallenge ? 100 : 50) pts)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        (responseText.isEmpty && customMemeImage == nil) 
                                            ? Color.gray 
                                            : Color.black
                                    )
                                    .cornerRadius(12)
                            }
                            .disabled(responseText.isEmpty && customMemeImage == nil)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $customMemeImage, sourceType: .camera)
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Response Posted!"),
                    message: Text("You earned \(fromChallenge ? 100 : 50) points for your response.\(fromChallenge ? " Challenge completed!" : "")"),
                    dismissButton: .default(Text("OK")) {
                        // Use the newer dismiss environment value
                        dismiss()
                        
                        // Reset state for next time
                        selectedPost = nil
                        responseText = ""
                        customMemeImage = nil
                    }
                )
            }
            .navigationBarTitle("", displayMode: .inline)
            .onAppear {
                // Force view refresh when appearing
                viewAppeared = true
                
                // Reset selection when view appears
                if selectedPost != nil && !friendPosts.contains(where: { $0.id == selectedPost?.id }) {
                    selectedPost = nil
                }
            }
        }
    }
    
    func submitResponse() {
        guard let post = selectedPost else { return }
        
        // Add roast directly to the original post instead of creating a new thread post
        dataStore.addRoastToPost(
            originalPost: post,
            responseText: responseText,
            responseImage: customMemeImage
        )
        
        // Points to award (more if from challenge)
        let points = fromChallenge ? 100 : 50
        
        // Add points to user
        dataStore.totalPoints += points
        
        // If this is from a challenge, mark it as completed
        if fromChallenge {
            // Complete the challenge
            dataStore.completeChallenge("Respond to a friend's post")
            
            // Add a feed item showing the friend received your response
            let friendName = post.username
            
            dataStore.addFeedItem(
                username: friendName,
                userAvatar: "person.circle.fill",
                activityType: "received_response",
                imageData: nil,
                points: 10,  // Small points for receiving a response
                caption: "Received your response",
                fromChallenge: true
            )
        }      
        // Show confirmation
        showingAlert = true
    }
    
    static func activityTypeText(_ type: String) -> String {
        switch type {
        case "meal":
            return "Logged a meal"
        case "workout":
            return "Completed a workout"
        case "bodycheck":
            return "Posted a body scan"
        case "thread":
            return "Responded to a post"
        case "received_response":
            return "Received response"
        case "shamed":
            return "Got feedback"
        default:
            return "Posted an update"
        }
    }
    
    static func activityTypeIcon(_ type: String) -> String {
        switch type {
        case "meal":
            return "fork.knife"
        case "workout":
            return "dumbbell"
        case "bodycheck":
            return "camera.fill"
        case "thread":
            return "bubble.right"
        case "received_response":
            return "bell.fill"
        case "shamed":
            return "bubble.left.fill"
        default:
            return "doc.text"
        }
    }
}

struct SelectableFeedItemView: View {
    let post: FeedItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Feed item content
                VStack(alignment: .leading, spacing: 10) {
                    // User info and timestamp
                    HStack {
                        Image(systemName: post.userAvatar)
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.username)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(SelectableFeedItemView.timeAgo(from: post.timestamp))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Activity type badge
                        Text(FriendRoastView.activityTypeText(post.activityType))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Caption
                    if let caption = post.caption {
                        Text(caption)
                            .font(.subheadline)
                    }
                    
                    // Image
                    if let imageData = post.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                    
                    // Points and stats
                    HStack(spacing: 16) {
                        Button(action: {
                            AppDataStore.shared.toggleLike(for: post.id)
                        }) {
                            Label("\(post.likes)", systemImage: AppDataStore.shared.isPostLiked(post.id) ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(AppDataStore.shared.isPostLiked(post.id) ? .red : .secondary)
                        }
                        
                        Spacer()
                        
                        Text("+\(post.points) pts")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: isSelected ? Color.black.opacity(0.2) : Color.black.opacity(0.05), 
                       radius: isSelected ? 8 : 5, 
                       x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper function to format time
    static func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct FriendRoastView_Previews: PreviewProvider {
    static var previews: some View {
        FriendRoastView()
    }
} 