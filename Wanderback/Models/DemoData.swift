import Foundation
import CoreLocation

/// Destinations fictives pour le mode démo (écran « Pas assez de destinations »).
/// Les photos n'ont pas d'asset PhotoKit : le jeu affiche alors un dégradé de simulation.
enum DemoData {
    static let clusters: [LocationCluster] = [
        makeCluster("Paris", "France", 48.8566, 2.3522, photoCount: 4, year: 2023, month: 5),
        makeCluster("Lisbonne", "Portugal", 38.7223, -9.1393, photoCount: 5, year: 2022, month: 7),
        makeCluster("Séville", "Espagne", 37.3891, -5.9845, photoCount: 3, year: 2023, month: 9),
        makeCluster("Rome", "Italie", 41.9028, 12.4964, photoCount: 4, year: 2021, month: 6),
        makeCluster("Tokyo", "Japon", 35.6762, 139.6503, photoCount: 6, year: 2024, month: 4),
        makeCluster("New York", "États-Unis", 40.7128, -74.0060, photoCount: 3, year: 2022, month: 11),
        makeCluster("Marrakech", "Maroc", 31.6295, -7.9811, photoCount: 4, year: 2023, month: 3),
        makeCluster("Reykjavik", "Islande", 64.1466, -21.9426, photoCount: 3, year: 2024, month: 8)
    ]

    private static func makeCluster(
        _ name: String,
        _ country: String,
        _ latitude: Double,
        _ longitude: Double,
        photoCount: Int,
        year: Int,
        month: Int
    ) -> LocationCluster {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let baseDate = Calendar.current.date(
            from: DateComponents(year: year, month: month, day: 14, hour: 15)
        ) ?? .now

        let photos = (0..<photoCount).map { index in
            PhotoLocation(
                id: "demo-\(name)-\(index)",
                coordinate: CLLocationCoordinate2D(
                    latitude: latitude + Double(index) * 0.002,
                    longitude: longitude + Double(index) * 0.002
                ),
                dateTaken: baseDate.addingTimeInterval(TimeInterval(index) * 3600),
                assetIdentifier: ""
            )
        }

        return LocationCluster(
            id: UUID(),
            centerCoordinate: center,
            photos: photos,
            displayName: name,
            country: country
        )
    }
}
