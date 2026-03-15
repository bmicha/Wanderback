import Foundation

struct GameRound: Identifiable {
    let id: UUID
    let photo: PhotoLocation
    let correctAnswer: LocationCluster
    let options: [LocationCluster]
    var playerAnswer: LocationCluster?
    var timeElapsed: TimeInterval?

    var isCorrect: Bool? {
        guard let answer = playerAnswer else { return nil }
        return answer.id == correctAnswer.id
    }
}
