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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                Text("Log Your Meal")
                    .font(.title2)
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
                        .font(.headline)
                    
                    TextField("What are you eating?", text: $mealCaption)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Submit button
                Button(action: submitMeal) {
                    Text("Log Meal (+50 pts)")
                        .font(.headline)
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
                    title: Text("Meal Logged!"),
                    message: Text("You earned 50 points for logging your meal."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    func submitMeal() {
        guard let image = inputImage else { return }
        
        // Add to feed with caption
        dataStore.addFeedItem(
            username: "You",
            userAvatar: "person.circle.fill",
            activityType: "meal",
            imageData: image.jpegData(compressionQuality: 0.7),
            points: 50,
            caption: mealCaption.isEmpty ? nil : mealCaption
        )
        
        // Add points
        dataStore.totalPoints += 50
        
        // Show confirmation
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