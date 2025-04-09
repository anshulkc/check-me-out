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
    @ObservedObject private var dataStore = AppDataStore.shared
    @State private var selectedPost: FeedItem? = nil
    @State private var roastText = ""
    @State private var showingMemeOptions = false
    @State private var showingImagePicker = false
    @State private var customMemeImage: UIImage? = nil
    @State private var showingAlert = false
    
    // Filter posts from friends (not your own posts)
    var friendPosts: [FeedItem] {
        return dataStore.feedItems.filter { 
            $0.username != "You" && $0.imageData != nil 
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    Text("Roast a Friend")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // Instructions
                    Text("Select a post to roast")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Friend posts grid
                    if friendPosts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No friend posts to roast yet")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(friendPosts) { post in
                                PostThumbnail(post: post, isSelected: selectedPost?.id == post.id) {
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
                                    
                                    Text(activityTypeText(selectedPost.activityType))
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
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Roast options
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Response")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Text roast option
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Write a roast")
                                    .font(.subheadline)
                                
                                TextField("Your savage comment...", text: $roastText)
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
                            Button(action: submitRoast) {
                                Text("Post Response (+100 pts)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        (roastText.isEmpty && customMemeImage == nil) 
                                            ? Color.gray 
                                            : Color.black
                                    )
                                    .cornerRadius(12)
                            }
                            .disabled(roastText.isEmpty && customMemeImage == nil)
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
                    message: Text("You earned 100 points for your savage response. It's now at the top of the feed."),
                    dismissButton: .default(Text("Savage!")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .navigationBarTitle("", displayMode: .inline)
        }
    }
    
    func submitRoast() {
        guard let post = selectedPost else { return }
        
        // Create thread post that references the original post
        dataStore.addThreadedPost(
            originalPost: post,
            responseText: roastText,
            responseImage: customMemeImage
        )
        
        // Add points to user
        dataStore.totalPoints += 100
        
        // Show confirmation
        showingAlert = true
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
        case "shamed":
            return "Shamed"
        default:
            return type.capitalized
        }
    }
}

struct PostThumbnail: View {
    let post: FeedItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if let imageData = post.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.black : Color.clear, lineWidth: 3)
                        )
                }
                
                HStack {
                    Text(post.username)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .black : .gray)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct FriendRoastView_Previews: PreviewProvider {
    static var previews: some View {
        FriendRoastView()
    }
} 