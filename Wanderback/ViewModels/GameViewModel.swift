import Foundation
import CoreLocation
import os

@MainActor
@Observable
class GameViewModel {
    enum Phase {
        case playing
        case revealing
        case finished
    }

    /// Durée d'un round en mode Challenge (secondes)
    static let roundDuration: TimeInterval = 30
    /// Points max par round en mode Challenge, dégressifs selon le temps
    static let maxPointsPerRound = 1000

    private(set) var session: GameSession?
    private(set) var mode: GameMode = .souvenir
    private(set) var phase: Phase = .playing
    private(set) var score = 0
    private(set) var timerRemaining: TimeInterval = GameViewModel.roundDuration
    /// Points gagnés sur le round qui vient d'être joué (affichés sur RevealView)
    private(set) var lastPointsEarned = 0

    private var clusters: [LocationCluster] = []
    private let questionGenerator = QuestionGenerator()
    private var timerTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "GameViewModel")

    /// Cluster « chez vous » : celui qui contient le plus de photos.
    private var homeCluster: LocationCluster? {
        clusters.max { $0.photoCount < $1.photoCount }
    }

    var currentRound: GameRound? { session?.currentRound }

    var roundLabel: String {
        guard let session else { return "" }
        return "Round \(min(session.currentRoundIndex + 1, session.rounds.count))/\(session.rounds.count)"
    }

    var isLastRound: Bool {
        guard let session else { return true }
        return session.currentRoundIndex >= session.rounds.count - 1
    }

    var correctAnswersCount: Int {
        session?.rounds.filter { $0.isCorrect == true }.count ?? 0
    }

    var answeredRoundsCount: Int {
        session?.rounds.filter { $0.playerAnswer != nil || $0.timeElapsed != nil }.count ?? 0
    }

    /// Distance cumulée entre les lieux joués, en km (« 6 240 km parcourus »)
    var totalDistanceKm: Int {
        guard let rounds = session?.rounds, rounds.count > 1 else { return 0 }
        var total: CLLocationDistance = 0
        for (previous, next) in zip(rounds, rounds.dropFirst()) {
            total += previous.correctAnswer.distance(to: next.correctAnswer)
        }
        return Int(total / 1000)
    }

    var countriesVisitedCount: Int {
        guard let rounds = session?.rounds else { return 0 }
        return Set(rounds.map { $0.correctAnswer.country }).subtracting([""]).count
    }

    /// Distance entre le lieu du round courant et « chez vous », en km. Nil si trop proche.
    var distanceFromHomeKm: Int? {
        guard let round = currentRound, let home = homeCluster else { return nil }
        let km = Int(home.distance(to: round.correctAnswer) / 1000)
        return km >= 50 ? km : nil
    }

    // MARK: - Cycle de vie de la partie

    func startGame(mode: GameMode, roundCount: Int, clusters: [LocationCluster]) {
        self.mode = mode
        self.clusters = clusters
        questionGenerator.reset()

        var rounds: [GameRound] = []
        for _ in 0..<roundCount {
            guard let round = questionGenerator.generateRound(from: clusters) else { break }
            rounds.append(round)
        }
        guard !rounds.isEmpty else {
            logger.error("Could not generate any round")
            return
        }
        if rounds.count < roundCount {
            logger.info("Only \(rounds.count)/\(roundCount) rounds generated")
        }

        session = GameSession(id: UUID(), startDate: .now, rounds: rounds, currentRoundIndex: 0)
        score = 0
        lastPointsEarned = 0
        phase = .playing
        startTimerIfNeeded()
    }

    func answer(_ cluster: LocationCluster) {
        guard phase == .playing, let session, let round = session.currentRound else { return }
        stopTimer()

        let elapsed = Self.roundDuration - timerRemaining
        let isCorrect = cluster.id == round.correctAnswer.id

        var updatedRound = round
        updatedRound.playerAnswer = cluster
        updatedRound.timeElapsed = elapsed
        self.session?.rounds[session.currentRoundIndex] = updatedRound

        if mode == .challenge {
            lastPointsEarned = isCorrect ? pointsForRemainingTime(timerRemaining) : 0
            score += lastPointsEarned
        }
        phase = .revealing
    }

    /// Temps écoulé en mode Challenge : compte comme une mauvaise réponse.
    private func timeOut() {
        guard phase == .playing, let session, let round = session.currentRound else { return }
        stopTimer()

        var updatedRound = round
        updatedRound.timeElapsed = Self.roundDuration
        self.session?.rounds[session.currentRoundIndex] = updatedRound

        lastPointsEarned = 0
        phase = .revealing
    }

    func nextRound() {
        guard let session else { return }
        let nextIndex = session.currentRoundIndex + 1
        self.session?.currentRoundIndex = nextIndex

        if nextIndex >= session.rounds.count {
            phase = .finished
        } else {
            phase = .playing
            startTimerIfNeeded()
        }
    }

    func replay() {
        guard let session else { return }
        startGame(mode: mode, roundCount: session.rounds.count, clusters: clusters)
    }

    func quit() {
        stopTimer()
        session = nil
        phase = .playing
    }

    // MARK: - Chrono (mode Challenge)

    private func startTimerIfNeeded() {
        timerRemaining = Self.roundDuration
        guard mode == .challenge else { return }

        timerTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.timerRemaining > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self.timerRemaining = max(0, self.timerRemaining - 0.1)
            }
            self?.timeOut()
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// 1000 pts dégressifs selon le temps restant, arrondis à la dizaine.
    private func pointsForRemainingTime(_ remaining: TimeInterval) -> Int {
        let ratio = max(0, min(1, remaining / Self.roundDuration))
        let raw = Double(Self.maxPointsPerRound) * ratio
        return max(10, Int((raw / 10).rounded()) * 10)
    }
}
