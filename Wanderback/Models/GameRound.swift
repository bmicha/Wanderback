import Foundation

struct GameRound: Identifiable {
    let id: UUID
    let photoLocation: PhotoLocation
    let options: [String]
    let correctAnswer: String
    var selectedAnswer: String?
    var isCorrect: Bool?
}
