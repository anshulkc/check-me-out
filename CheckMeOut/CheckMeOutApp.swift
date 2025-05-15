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

@main
struct CheckMeOutApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var dataStore = SupabaseDataStore.shared
    
    init() {
        // Initialize any app-wide settings here
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authViewModel)
                .environmentObject(dataStore)
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
    @AppStorage("userHeight") private var userHeight: Double = 60 // in
    @AppStorage("userWeight") private var userWeight: Double = 150 // lbs
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
                                Text("Sign in with Google").font(.tagesschrift(size: 16))
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section(header: Text("Personal Information").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    Picker(selection: $userGender, label: Text("Gender").font(.tagesschrift(size: 16))) {
                        Text("Male").font(.tagesschrift(size: 16)).tag("Male")
                        Text("Female").font(.tagesschrift(size: 16)).tag("Female")
                        Text("Other").font(.tagesschrift(size: 16)).tag("Other")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Age: \(userAge) yrs")
                            .font(.tagesschrift(size: 16))
                        Picker("", selection: $userAge) {
                            ForEach(Array(stride(from: 13, through: 100, by: 1)), id: \.self) { h in
                                Text("\(h) yrs").font(.tagesschrift(size: 14))
                                    .tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)    // tighten up the wheel
                        .clipped()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Height: \(userHeight, specifier: "%.1f") in")
                            .font(.tagesschrift(size: 16))
                        Picker("", selection: $userHeight) {
                            ForEach(Array(stride(from: 24.0, through: 100.0, by: 0.5)), id: \.self) { h in
                                Text("\(h, specifier: "%.1f") in").font(.tagesschrift(size: 14))
                                    .tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)    // tighten up the wheel
                        .clipped()
                    }

    VStack(alignment: .leading) {
                       Text("Weight: \(userWeight, specifier: "%.1f") lbs")
                        .font(.tagesschrift(size: 16))
                       Picker("", selection: $userWeight) {
                           ForEach(Array(stride(from: 30.0, through: 500.0, by: 0.5)), id: \.self) { w in
                               Text("\(w, specifier: "%.1f") lbs")
                                   .font(.tagesschrift(size: 14))
                                   .tag(w)
                           }
                       }
                       .pickerStyle(.wheel)
                       .frame(height: 120)
                       .clipped()
                   }
                }
                
                Section(header: Text("About").font(.tagesschrift(size: 16)).foregroundColor(.primary)) {
                    HStack {
                        Text("Version").font(.tagesschrift(size: 16))
                        Spacer()
                        Text("1.0.0").font(.tagesschrift(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()   // swap in a PrivacyPolicyView if you make one
                    }
                    .font(.tagesschrift(size: 16))

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                    .font(.tagesschrift(size: 16))
                    
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
    
    struct TermsOfServiceView: View {
        var body: some View {
            ScrollView {
                Text("""
                Just workout, eat healthy, and roast your friends. Anything else is irrelevant.
                """)
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    struct PrivacyPolicyView: View {
        var body: some View {
            ScrollView {
                Text("""
                No privacy, I will still all of your data (im evil)
                """)
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
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
