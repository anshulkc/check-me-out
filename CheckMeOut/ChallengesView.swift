//
//  ChallengesView.swift
//  CheckMeOut
//
//  Created for daily challenges
//

import SwiftUI

struct Challenge: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let points: Int
    let iconName: String
    var isCompleted: Bool
    let negativeEffect: String?
}

struct ChallengesView: View {
    @ObservedObject private var dataStore = SupabaseDataStore.shared
    @State private var showingBodyScanView = false
    @State private var showingMealLogView = false
    @State private var showingWorkoutLogView = false
    @State private var showingFriendRoastView = false
    @State private var challenges = [
        Challenge(
            title: "Post a scan of yourself",
            description: "Take a body scan and share it with your friends",
            points: 100,
            iconName: "camera.viewfinder",
            isCompleted: false,
            negativeEffect: nil
        ),
        Challenge(
            title: "Take a picture at the gym",
            description: "Show off your workout routine",
            points: 50,
            iconName: "dumbbell.fill",
            isCompleted: false,
            negativeEffect: nil
        ),
        Challenge(
            title: "Shame a friend",
            description: "Tag a friend who missed their workout",
            points: 100,
            iconName: "person.fill.questionmark",
            isCompleted: false,
            negativeEffect: "-50 pts -> friend"
        ),
        Challenge(
            title: "Log a meal",
            description: "Take a photo of your healthy meal",
            points: 50,
            iconName: "fork.knife",
            isCompleted: false,
            negativeEffect: nil
        )
    ]
    
    var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with total points
                    HStack {
                        Text("Daily Challenges")
                            .font(.quicksand(size: 22))
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Points pill
                        HStack(spacing: 4) {
                            Text("\(dataStore.totalPoints) pts")
                                .font(.tagesschriftSubheadline)
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
                    
                    // Challenge cards
                    ForEach(challenges) { challenge in
                        ChallengeCard(challenge: challenge) {
                            startChallenge(challenge)
                        }
                    }
                }
                .padding(.bottom)

            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CheckMeOut")
                        .font(.quicksand(size: 16))
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingBodyScanView, onDismiss: updateChallengeStatus) {
                BodyScanView(fromChallenge: true)
            }
            .sheet(isPresented: $showingMealLogView, onDismiss: updateChallengeStatus) {
                MealLogView(fromChallenge: true)
            }
            .sheet(isPresented: $showingWorkoutLogView, onDismiss: updateChallengeStatus) {
                WorkoutLogView(fromChallenge: true)
            }
            .sheet(isPresented: $showingFriendRoastView, onDismiss: updateChallengeStatus) {
                FriendRoastView(fromChallenge: true)
            }
    }
    
    private func startChallenge(_ challenge: Challenge) {
        // Handle specific challenge actions without marking as completed yet
        handleSpecificChallengeActions(challenge)
    }
    
    // This will be called when returning to this view
    private func updateChallengeStatus() {
        // Update challenges based on completed status in dataStore
        for (index, challenge) in challenges.enumerated() {
            if dataStore.isChallengeCompleted(challenge.title) && !challenge.isCompleted {
                var updatedChallenge = challenge
                updatedChallenge.isCompleted = true
                challenges[index] = updatedChallenge
            }
        }
    }
    
    private func getChallengeActivityType(_ challenge: Challenge) -> String {
        switch challenge.title {
        case "Post a scan of yourself":
            return "bodycheck"
        case "Take a picture at the gym":
            return "workout"
        case "Log a meal":
            return "meal"
        default:
            return "challenge"
        }
    }
    
    private func handleSpecificChallengeActions(_ challenge: Challenge) {
        switch challenge.title {
        case "Post a scan of yourself":
            // Navigate to body scan view with fromChallenge flag
            showingBodyScanView = true
            
        case "Take a picture at the gym":
            // Navigate to workout log view
            showingWorkoutLogView = true
            
        case "Shame a friend":
            // Navigate to friend roast view
            showingFriendRoastView = true
            
        case "Log a meal":
            // Navigate to meal log view
            showingMealLogView = true
            
        default:
            break
        }
    }
    
    struct ChallengeCard: View {
        let challenge: Challenge
        let action: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Challenge icon
                    Image(systemName: challenge.iconName)
                        .font(.tagesschriftBody)
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.quicksand(size: 20))
                        
                        Text(challenge.description)
                            .font(.quicksand(size: 16))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    // Points display
                    HStack {
                        Text("+\(challenge.points) pts")
                            .font(.tagesschriftSubheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    .cornerRadius(20)
                    
                    if let negativeEffect = challenge.negativeEffect {
                        Text(negativeEffect)
                            .font(.tagesschriftCaption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    // Complete button
                    Button(action: action) {
                        Text(challenge.isCompleted ? "Completed" : "Start Challenge")
                            .font(.quicksand(size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(challenge.isCompleted ? .gray : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(challenge.isCompleted ? Color.gray.opacity(0.3) : Color.black)
                            .cornerRadius(20)
                    }
                    .disabled(challenge.isCompleted)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
    
    struct ChallengesView_Previews: PreviewProvider {
        static var previews: some View {
            ChallengesView()
        }
    }
}
