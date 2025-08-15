//
//  APIModels.swift
//  Par6_Golf
//
//  Created by Claude on 8/11/25.
//

import Foundation

enum Status: String, Codable, CaseIterable {
    case solved = "solved"
    case dnf = "dnf"
}

struct UserCreate: Codable {
    let handle: String
}

struct User: Codable {
    let userId: String
    let handle: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case handle
        case createdAt = "created_at"
    }
}

struct UserResponse: Codable {
    let userId: String
    let handle: String
    let sessionToken: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case handle
        case sessionToken = "session_token"
    }
}

struct ScoreCreate: Codable {
    let userId: String
    let puzzleDate: String
    let status: Status
    let guessesUsed: Int?
    let sourceText: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case puzzleDate = "puzzle_date"
        case status
        case guessesUsed = "guesses_used"
        case sourceText = "source_text"
    }
}

struct Score: Codable, Identifiable {
    let id: String
    let userId: String
    let puzzleDate: String
    let status: Status
    let guessesUsed: Int?
    let golfScore: Int
    let sourceText: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "score_id"
        case userId = "user_id"
        case puzzleDate = "puzzle_date"
        case status
        case guessesUsed = "guesses_used"
        case golfScore = "golf_score"
        case sourceText = "source_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let userId: String
    let handle: String
    let totalGolfScore: Int
    let roundsPlayed: Int
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case handle
        case totalGolfScore = "total_golf_score"
        case roundsPlayed = "rounds_played"
    }
}

// MARK: - Tournament Models

struct Tournament: Codable, Identifiable {
    let id: String
    let name: String
    let startDate: String // yyyy-MM-dd format
    let endDate: String   // 18 days after start
    let createdBy: String
    let participants: [String] // Array of user IDs
    let createdAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "tournament_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case createdBy = "created_by"
        case participants
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}

struct TournamentScore: Codable, Identifiable {
    let id: String
    let tournamentId: String
    let userId: String
    let day: Int // 1-18 (hole number)
    let score: Int // Golf score for that day
    let puzzleDate: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "tournament_score_id"
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case day
        case score
        case puzzleDate = "puzzle_date"
        case createdAt = "created_at"
    }
}

struct TournamentStanding: Codable, Identifiable {
    let userId: String
    let handle: String
    let totalScore: Int
    let completedDays: Int
    let position: Int
    let isCurrentUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case handle
        case totalScore = "total_score"
        case completedDays = "completed_days"
        case position
        case isCurrentUser = "is_current_user"
    }
    
    var id: String { userId }
}

struct TournamentSummary: Codable, Identifiable {
    let id: String
    let tournament: Tournament
    let standings: [TournamentStanding]
    let userParticipating: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "tournament_id"
        case tournament
        case standings
        case userParticipating = "user_participating"
    }
}