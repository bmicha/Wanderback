import Foundation

struct GameSession: Identifiable {
    let id: UUID
    let startDate: Date
    var rounds: [GameRound]
    var currentRoundIndex: Int
    var score: Int

    var isFinished: Bool {
        currentRoundIndex >= rounds.count
    }
}
