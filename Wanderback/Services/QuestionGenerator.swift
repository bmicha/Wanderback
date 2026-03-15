import Foundation
import CoreLocation
import os

@MainActor
class QuestionGenerator {
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "QuestionGenerator")

    /// Distance minimale entre les options de réponse (200 km)
    static let minimumOptionDistance: CLLocationDistance = 200_000

    /// Nombre d'options par round
    static let optionsCount = 4

    private var usedPhotoIds: Set<String> = []
    private var lastCorrectClusterId: UUID?

    func reset() {
        usedPhotoIds.removeAll()
        lastCorrectClusterId = nil
    }

    func generateRound(from clusters: [LocationCluster]) -> GameRound? {
        guard clusters.count >= Self.optionsCount else {
            logger.warning("Not enough clusters: \(clusters.count) < \(Self.optionsCount)")
            return nil
        }

        // 1. Choisir un cluster correct (pas le même que le dernier)
        let eligibleClusters = clusters.filter { $0.id != lastCorrectClusterId }
        guard let correctCluster = eligibleClusters.randomElement() else { return nil }

        // 2. Choisir une photo non utilisée dans ce cluster
        let availablePhotos = correctCluster.photos.filter { !usedPhotoIds.contains($0.id) }
        guard let photo = availablePhotos.randomElement() else {
            logger.info("No more unused photos in cluster \(correctCluster.displayName)")
            return nil
        }

        // 3. Sélectionner 3 distracteurs avec contrainte de distance
        let distractors = selectDistractors(
            correctCluster: correctCluster,
            allClusters: clusters,
            count: Self.optionsCount - 1
        )

        guard distractors.count == Self.optionsCount - 1 else {
            logger.warning("Could not find enough distractors")
            return nil
        }

        // 4. Mélanger les options
        var options = [correctCluster] + distractors
        options.shuffle()

        // 5. Mettre à jour l'état
        usedPhotoIds.insert(photo.id)
        lastCorrectClusterId = correctCluster.id

        let round = GameRound(
            id: UUID(),
            photo: photo,
            correctAnswer: correctCluster,
            options: options
        )

        logger.info("Generated round: \(correctCluster.displayName) with \(options.count) options")
        return round
    }

    private func selectDistractors(
        correctCluster: LocationCluster,
        allClusters: [LocationCluster],
        count: Int
    ) -> [LocationCluster] {
        var selected: [LocationCluster] = []
        var candidates = allClusters.filter { $0.id != correctCluster.id }.shuffled()

        // D'abord essayer avec la contrainte de distance stricte
        selected = selectWithDistance(
            from: &candidates,
            alreadySelected: selected,
            correctCluster: correctCluster,
            count: count,
            minimumDistance: Self.minimumOptionDistance
        )

        // Si pas assez, relâcher la contrainte avec les candidats restants
        if selected.count < count {
            let additional = selectWithDistance(
                from: &candidates,
                alreadySelected: selected,
                correctCluster: correctCluster,
                count: count - selected.count,
                minimumDistance: 0
            )
            selected.append(contentsOf: additional)
        }

        return selected
    }

    private func selectWithDistance(
        from candidates: inout [LocationCluster],
        alreadySelected: [LocationCluster],
        correctCluster: LocationCluster,
        count: Int,
        minimumDistance: CLLocationDistance
    ) -> [LocationCluster] {
        var selected: [LocationCluster] = []
        let allExisting = alreadySelected

        for candidate in candidates {
            guard selected.count < count else { break }

            let farEnoughFromCorrect = correctCluster.distance(to: candidate) >= minimumDistance
            let farEnoughFromExisting = allExisting.allSatisfy { existing in
                existing.distance(to: candidate) >= minimumDistance
            }
            let farEnoughFromNewlySelected = selected.allSatisfy { existing in
                existing.distance(to: candidate) >= minimumDistance
            }

            if farEnoughFromCorrect && farEnoughFromExisting && farEnoughFromNewlySelected {
                selected.append(candidate)
            }
        }

        candidates.removeAll { candidate in
            selected.contains(where: { $0.id == candidate.id })
        }

        return selected
    }
}
