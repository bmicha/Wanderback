import Foundation

enum GameMode: String, CaseIterable, Identifiable {
    case souvenir
    case challenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .souvenir: return "Souvenir"
        case .challenge: return "Challenge"
        }
    }

    var subtitle: String {
        switch self {
        case .souvenir: return "Ambiance détendue, sans chrono"
        case .challenge: return "Chronomètre 30s, score dynamique"
        }
    }

    var icon: String {
        switch self {
        case .souvenir: return "heart.fill"
        case .challenge: return "timer"
        }
    }
}
