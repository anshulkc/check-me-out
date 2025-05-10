//
//  CheckMeOutApp.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 4/2/25.
//

import SwiftUI
import Supabase
import GoogleSignIn
import GoogleSignInSwift
import UIKit

// Authentication view model to handle auth state
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User? = nil

    
    init() {
        // Start listening for auth state changes
        Task {
            for await state in supabase.auth.authStateChanges {
                if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                    await MainActor.run {
                        self.isAuthenticated = state.session != nil
                        self.currentUser = state.session?.user
                        
                        // If signed in, try to load profile
                        if state.session != nil {
                            Task {
                                await loadUserProfile()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Current user profile when authenticated
    @Published var userProfile: Profile? = nil

    // Google sign-in - runs entirely on the main thread
    @MainActor
    func googleSignIn(presenting viewController: UIViewController) async throws {
        // Configure Google Sign-In
        let clientID = "331920877049-n4hluktr5orpdc1thr1oie7u55n5aof9.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Wrap the sign-in logic in MainActor to ensure it happens on the main thread
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let signInResult = signInResult else {
                    continuation.resume(throwing: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result returned"]))
                    return
                }
                
                continuation.resume(returning: signInResult)
            }
        }
        
        // Check for a valid ID token
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token found"])
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        // Send tokens to Supabase
        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        
        // Load user profile after successful sign-in
        await loadUserProfile()
    }
    
    // Load user profile from Supabase
    func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }
        guard let email = currentUser?.email else { return }
        
        do {
            // Try to fetch the existing profile
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            // If profile exists, use it
            if let profile = profiles.first {
                await MainActor.run {
                    self.userProfile = profile
                }
            } else {
                // Create a new profile if none exists
                print("Creating new profile for user: \(userId)")
                
                // Username defaults to email address initially
                let username = email.components(separatedBy: "@").first ?? ""
                
                // Create a new profile
                let newProfile = Profile(
                    id: userId,
                    username: username,
                    fullName: nil,
                    avatarUrl: nil
                )
                
                // Insert the new profile
                try await supabase
                    .from("profiles")
                    .insert(newProfile)
                    .execute()
                
                // Set the profile
                await MainActor.run {
                    self.userProfile = newProfile
                }
            }
        } catch {
            print("Error with profile: \(error)")
        }
    }
    
    // Update user profile
    func updateProfile(username: String, fullName: String) async {
        guard let userId = currentUser?.id else { return }
        
        do {
            try await supabase
                .from("profiles")
                .update(
                    UpdateProfileParams(
                        username: username,
                        fullName: fullName
                    )
                )
                .eq("id", value: userId)
                .execute()
            
            // Reload profile after update
            await loadUserProfile()
        } catch {
            print("Error updating profile: \(error)")
        }
    }
    
    // Sign in with email and password
    func signIn(email: String, password: String) async -> Bool {
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            return true
        } catch {
            print("Error signing in: \(error)")
            return false
        }
    }
    
    // Sign up with email and password
    func signUp(email: String, password: String) async -> Bool {
        do {
            _ = try await supabase.auth.signUp(email: email, password: password)
            return true
        } catch {
            print("Error signing up: \(error)")
            return false
        }
    }
    
    // Sign out current user
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

@main
struct CheckMeOutApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

struct MainTabView: View {
    // State to track navigation paths for each tab
    @State private var homeNavigationPath = NavigationPath()
    @State private var challengesNavigationPath = NavigationPath()
    @State private var leaderboardNavigationPath = NavigationPath()
    @State private var profileNavigationPath = NavigationPath()
    
    var body: some View {
        TabView {
            // Home tab with NavigationStack
            NavigationStack(path: $homeNavigationPath) {
                ContentView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            
            // Challenges tab with NavigationStack
            NavigationStack(path: $challengesNavigationPath) {
                ChallengesView()
            }
            .tabItem {
                Label("Challenges", systemImage: "trophy.fill")
            }
            
            // Leaderboard tab with NavigationStack
            NavigationStack(path: $leaderboardNavigationPath) {
                Text("Leaderboard")
                    .font(.tagesschriftTitle)
            }
            .tabItem {
                Label("Leaderboard", systemImage: "chart.bar.fill")
            }
            
            // Profile tab with NavigationStack
            NavigationStack(path: $profileNavigationPath) {
                SettingsView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .accentColor(.black)
    }
}

struct SettingsView: View {
    // Personal measurements
    @AppStorage("userHeight") private var userHeight = 170.0 // cm
    @AppStorage("userWeight") private var userWeight = 70.0 // kg
    @AppStorage("userAge") private var userAge = 30
    @AppStorage("userGender") private var userGender = "Male"
    
    // Profile information
    @State private var username = ""
    @State private var fullName = ""
    @State private var isLoading = false
    @State private var showSignInSheet = false
    @State private var showEditProfileSheet = false
    @State private var emailInput = ""
    @State private var passwordInput = ""
    @State private var editProfileName = ""
    @State private var editProfileUsername = ""
    
    // Auth view model
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                // Account section
                Section(header: Text("Account").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    if let user = authViewModel.currentUser {
                        // Profile info section
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                if let profile = authViewModel.userProfile {
                                    Text(profile.fullName ?? "No Name")
                                        .font(.headline)
                                    Text(profile.username ?? user.email ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(user.email ?? "Signed In")
                                        .font(.headline)
                                    Text("Google Account")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        
                        // Account management buttons
                        Button(action: {
                            // Initialize form with current profile data
                            if let profile = authViewModel.userProfile {
                                editProfileName = profile.fullName ?? ""
                                editProfileUsername = profile.username ?? ""
                            } else if let user = authViewModel.currentUser {
                                // Default to email address as username if no profile exists
                                editProfileUsername = user.email ?? ""
                            }
                            showEditProfileSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                    .foregroundColor(.blue)
                                Text("Edit Profile")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            Task {
                                await authViewModel.signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } else {
                        // Sign-in section when no user is logged in
                        Button(action: {
                            Task { @MainActor in
                                do {
                                    // Get the root view controller to present Google Sign-In
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootViewController = windowScene.windows.first?.rootViewController {
                                        try await authViewModel.googleSignIn(presenting: rootViewController)
                                    }
                                } catch {
                                    print("Error with Google Sign In: \(error)")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Sign in with Google")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section(header: Text("Personal Information").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    Picker(selection: $userGender, label: Text("Gender")) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        Stepper("\(userAge) years", value: $userAge, in: 18...100)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        Stepper(String(format: "%.1f cm", userHeight), value: $userHeight, in: 100...220, step: 0.5)
                    }
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        Stepper(String(format: "%.1f kg", userWeight), value: $userWeight, in: 30...200, step: 0.5)
                    }
                }
                
                Section(header: Text("Scan Settings").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    Toggle("High Resolution Scan", isOn: .constant(true))
                    Toggle("Save Scan History", isOn: .constant(true))
                    Toggle("Show Detailed Results", isOn: .constant(true))
                }
                
                Section(header: Text("Privacy").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    Toggle("Encrypt Scan Data", isOn: .constant(true))
                    Button("Delete All Scan Data") {
                        // Add confirmation dialog and deletion logic
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("About").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    HStack {
                        Text("Version").font(.tagesschrift(size: 16))
                        Spacer()
                        Text("1.0.0").font(.tagesschrift(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                        Text("No privacy, I will still all of your data (im evil)").font(.tagesschrift(size: 16))

                    }
                    
                    Button("Terms of Service") {
                        // Open terms of service
                        Text("Just workout, eat healthy, and roast your friends. Anything else is irrelevant.").font(.tagesschrift(size: 16))

                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("CheckMeOut")
                        .font(.tagesschrift(size: 16))
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showSignInSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("Sign In")) {
                            TextField("Email", text: $emailInput)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            SecureField("Password", text: $passwordInput)
                                .textContentType(.password)
                        }
                        
                        Section {
                            Button("Sign In") {
                                signInWithEmail()
                            }
                            .disabled(emailInput.isEmpty || passwordInput.isEmpty || isLoading)
                            
                            Button("Sign Up") {
                                signUpWithEmail()
                            }
                            .disabled(emailInput.isEmpty || passwordInput.isEmpty || isLoading)
                        }
                    }
                    .navigationTitle("Account")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showSignInSheet = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditProfileSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("Profile Information")) {
                            TextField("Full Name", text: $editProfileName)
                                .autocapitalization(.words)
                            
                            TextField("Username", text: $editProfileUsername)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .textContentType(.name)
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showEditProfileSheet = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                updateProfile()
                            }
                            .disabled(isLoading)
                        }
                    }
                }
            }
        }
    }
    
    // These helper methods delegate to the AuthViewModel
    
    func updateProfile() {
        isLoading = true
        
        Task {
            await authViewModel.updateProfile(username: editProfileUsername, fullName: editProfileName)
            
            await MainActor.run {
                isLoading = false
                showEditProfileSheet = false
            }
        }
    }
    
    func signInWithEmail() {
        isLoading = true
        
        Task {
            let success = await authViewModel.signIn(email: emailInput, password: passwordInput)
            
            await MainActor.run {
                if success {
                    emailInput = ""
                    passwordInput = ""
                    showSignInSheet = false
                }
                isLoading = false
            }
        }
    }
    
    func signUpWithEmail() {
        isLoading = true
        
        Task {
            let success = await authViewModel.signUp(email: emailInput, password: passwordInput)
            
            await MainActor.run {
                if success {
                    emailInput = ""
                    passwordInput = ""
                    showSignInSheet = false
                }
                isLoading = false
            }
        }
    }
}
