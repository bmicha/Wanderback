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
        case .souvenir: return "Tranquille, on se remémore ensemble"
        case .challenge: return "30 s, 1000 pts, qui gagne ?"
        }
    }

    var icon: String {
        switch self {
        case .souvenir: return "heart.fill"
        case .challenge: return "timer"
        }
    }
}
