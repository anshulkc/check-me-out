//
//  WorkoutLogView.swift
//  CheckMeOut
//
//  Created for workout logging
//

import SwiftUI
import UIKit

struct WorkoutLogView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var dataStore = SupabaseDataStore.shared
    @State private var inputImage: UIImage?
    @State private var workoutCaption = ""
    @State private var showingCamera = false
    @State private var showingAlert = false
    var fromChallenge: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                Text("Log Your Workout")
                    .font(.tagesschriftTitle2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                // Image preview
                ZStack {
                    if let inputImage = inputImage {
                        Image(uiImage: inputImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(12)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 300)
                            .cornerRadius(12)
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Tap to add a photo")
                                        .font(.tagesschriftBody)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                }
                .contentShape(Rectangle()) // Improve tap target
                .onTapGesture {
                    self.showingCamera = true
                }
                .padding(.horizontal)
                
                // Caption field
                VStack(alignment: .leading, spacing: 12) {
                    Text("Caption")
                        .font(.tagesschriftHeadline)
                    
                    TextField("What are you working on today?", text: $workoutCaption)
                        .font(.tagesschrift(size: 16))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Submit button
                Button(action: submitWorkout) {
                    Text("Log Workout (+50 pts)")
                        .font(.tagesschriftHeadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inputImage == nil ? Color.gray : Color.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .disabled(inputImage == nil)
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showingCamera, onDismiss: {
                // This ensures we process the image selection immediately
                if inputImage != nil {
                    // Image was selected
                }
            }) {
                ImagePicker(image: $inputImage, sourceType: .camera)
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Workout Logged!").font(.tagesschrift(size: 18)),
                    message: Text("You earned \(fromChallenge ? 100 : 50) points for logging your workout.\(fromChallenge ? " Challenge completed!" : "")").font(.tagesschrift(size: 14)),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    func submitWorkout() {
        guard let image = inputImage else { return }
        
        // Points to award (more if from challenge)
        let points = fromChallenge ? 100 : 50
        
        // Add to feed with caption
        dataStore.addFeedItem(
            username: "You",
            userAvatar: "person.circle.fill",
            activityType: "workout",
            imageData: image.jpegData(compressionQuality: 0.7),
            points: points,
            caption: workoutCaption.isEmpty ? nil : workoutCaption,
            fromChallenge: fromChallenge
        )
        
        // Add points
        dataStore.totalPoints += points
        
        // Show confirmation with appropriate message
        showingAlert = true
    }
}

struct WorkoutLogView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutLogView()
    }
} 