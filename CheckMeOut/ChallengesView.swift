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
    let isCompleted: Bool
    let negativeEffect: String?
}

struct ChallengesView: View {
    @ObservedObject private var dataStore = AppDataStore.shared
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
            negativeEffect: "-50 points to friend"
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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with total points
                    HStack {
                        Text("Daily Challenges")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Points pill
                        HStack(spacing: 4) {
                            Text("\(dataStore.totalPoints) pts")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.darkGray))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Challenge cards
                    ForEach(challenges) { challenge in
                        ChallengeCard(challenge: challenge) {
                            completeChallenge(challenge)
                        }
                    }
                }
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func completeChallenge(_ challenge: Challenge) {
        // Find and update the challenge
        if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
            var updatedChallenge = challenge
            updatedChallenge = Challenge(
                title: challenge.title,
                description: challenge.description,
                points: challenge.points,
                iconName: challenge.iconName,
                isCompleted: true,
                negativeEffect: challenge.negativeEffect
            )
            
            challenges[index] = updatedChallenge
            
            // Add points to user
            dataStore.totalPoints += challenge.points
            
            // Add to feed
            dataStore.addFeedItem(
                username: "You", 
                userAvatar: "person.circle.fill", 
                activityType: getChallengeActivityType(challenge), 
                imageData: nil, 
                points: challenge.points
            )
            
            // Handle specific challenge actions
            handleSpecificChallengeActions(challenge)
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
            // Navigate to body scan view
            // This would typically be handled with a navigation link
            break
            
        case "Take a picture at the gym":
            // This would be handled by a navigation link to WorkoutLogView
            // For now, we'll just simulate completing the challenge
            break
            
        case "Shame a friend":
            // Show friend selection UI
            // For now, we'll just simulate it
            let friendName = ["John D.", "Sarah M.", "Mike T.", "Emma R."].randomElement()!
            
            // Add a feed item for the shamed friend
            dataStore.addFeedItem(
                username: friendName,
                userAvatar: "person.circle.fill",
                activityType: "shamed",
                imageData: nil,
                points: -50
            )
            
            break
            
        case "Log a meal":
            // This would be handled by a navigation link to MealLogView
            break
            
        default:
            break
        }
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
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            HStack {
                // Points display
                HStack {
                    Text("+\(challenge.points) pts")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black)
                .cornerRadius(20)
                
                if let negativeEffect = challenge.negativeEffect {
                    Text(negativeEffect)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Complete button
                Button(action: action) {
                    Text(challenge.isCompleted ? "Completed" : "Complete")
                        .font(.subheadline)
                        .fontWeight(.semibold)
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