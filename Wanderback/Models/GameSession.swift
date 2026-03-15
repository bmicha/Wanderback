import Foundation

struct GameSession: Identifiable {
    let id: UUID
    let startDate: Date
    var rounds: [GameRound]
    var currentRoundIndex: Int

    var isFinished: Bool {
        currentRoundIndex >= rounds.count
    }

    var currentRound: GameRound? {
        guard currentRoundIndex < rounds.count else { return nil }
        return rounds[currentRoundIndex]
    }

    var score: Int {
        rounds.filter { $0.isCorrect == true }.count
    }

    var totalAnswered: Int {
        rounds.filter { $0.playerAnswer != nil }.count
    }
}
