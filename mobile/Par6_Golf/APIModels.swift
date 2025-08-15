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