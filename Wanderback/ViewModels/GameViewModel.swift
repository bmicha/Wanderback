import Foundation

@Observable
class GameViewModel {
    var session: GameSession?
    var isLoadingRound = false
}
