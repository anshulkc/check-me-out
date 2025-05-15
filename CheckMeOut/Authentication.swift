//
//  Supabase.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 5/9/25.
//

import Foundation
import Supabase
import GoogleSignIn
import GoogleSignInSwift
import UIKit
import SwiftUI

// Initialize the Supabase client
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://hibmwhxkbrzuygnojtyb.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhpYm13aHhrYnJ6dXlnbm9qdHliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY3NTUyNjUsImV4cCI6MjA2MjMzMTI2NX0.IV4JujAlWuKQqssJ-awzoymsNLshR6fPwYcKHpkR-O8"
)

// Authentication view model to handle auth state
public class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User? = nil
    
    // Current user profile when authenticated
    @Published var userProfile: Profile? = nil
    
    public init() {
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

    // Google sign-in - runs entirely on the main thread
    @MainActor
    public func googleSignIn(presenting viewController: UIViewController) async throws {
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
    public func loadUserProfile() async {
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
    public func updateProfile(username: String, fullName: String) async {
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
    public func signIn(email: String, password: String) async -> Bool {
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            return true
        } catch {
            print("Error signing in: \(error)")
            return false
        }
    }
    
    // Sign up with email and password
    public func signUp(email: String, password: String) async -> Bool {
        do {
            _ = try await supabase.auth.signUp(email: email, password: password)
            return true
        } catch {
            print("Error signing up: \(error)")
            return false
        }
    }
    
    // Sign out current user
    public func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
