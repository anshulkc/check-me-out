//
//  MealLogView.swift
//  CheckMeOut
//
//  Created for meal logging
//

import SwiftUI
import UIKit

struct MealLogView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var dataStore = AppDataStore.shared
    @State private var inputImage: UIImage?
    @State private var mealCaption = ""
    @State private var showingCamera = false
    @State private var showingAlert = false
    var fromChallenge: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                Text("Log Your Meal")
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
                                        .font(.tagesschriftCaption)
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
                    
                    TextField("What are you eating?", text: $mealCaption)
                        .font(.tagesschrift(size: 16))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Submit button
                Button(action: submitMeal) {
                    Text("Log Meal (+50 pts)")
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
                    title: Text("Meal Logged!").font(.tagesschrift(size: 18)),
                    message: Text("You earned \(fromChallenge ? 100 : 50) points for logging your meal.\(fromChallenge ? " Challenge completed!" : "")").font(.tagesschrift(size: 14)),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    func submitMeal() {
        guard let image = inputImage else { return }
        
        // Points to award (more if from challenge)
        let points = fromChallenge ? 100 : 50
        
        // Add to feed with caption
        dataStore.addFeedItem(
            username: "You",
            userAvatar: "person.circle.fill",
            activityType: "meal",
            imageData: image.jpegData(compressionQuality: 0.7),
            points: points,
            caption: mealCaption.isEmpty ? nil : mealCaption,
            fromChallenge: fromChallenge
        )
        
        // Add points
        dataStore.totalPoints += points
        
        // Show confirmation with appropriate message
        showingAlert = true
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        
        // Explicitly set camera device to avoid warnings and reduce hang time
        if sourceType == .camera {
            // Check which camera devices are available and use the most reliable option
            if UIImagePickerController.isCameraDeviceAvailable(.rear) {
                picker.cameraDevice = .rear
            } else if UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            }
            
            // Set camera mode explicitly to photo to avoid any video configuration issues
            picker.cameraCaptureMode = .photo
            
            // Set flash mode to auto
            picker.cameraFlashMode = .auto
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            picker.dismiss(animated: true)
        }
    }
}

struct MealLogView_Previews: PreviewProvider {
    static var previews: some View {
        MealLogView()
    }
} 