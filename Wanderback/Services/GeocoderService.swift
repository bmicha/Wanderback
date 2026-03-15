import Foundation
import CoreLocation
import SwiftData
import os

@MainActor
class GeocoderService {
    private let geocoder = CLGeocoder()
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "GeocoderService")

    /// Seuil de proximité pour réutiliser un cache existant (500m)
    static let proximityCacheThreshold: CLLocationDistance = 500

    /// Délai entre requêtes API (50 req/60s max imposé par Apple)
    private static let throttleDelay: Duration = .milliseconds(1250)

    /// Délai de backoff après une erreur rate-limit
    private static let retryDelay: Duration = .seconds(10)

    /// Nombre max de retries par coordonnée
    private static let maxRetries = 2

    /// Marge en degrés pour le bounding box (~1 km)
    private static let boundingBoxDelta: Double = 0.009

    private var lastRequestTime: ContinuousClock.Instant?

    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        modelContext: ModelContext
    ) async -> LocationCache? {
        // 1. Chercher dans le cache
        if let cached = findCachedLocation(near: coordinate, in: modelContext) {
            return cached
        }

        // 2. Géocoder avec retry sur rate-limit
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        for attempt in 0...Self.maxRetries {
            await throttle()

            do {
                guard let placemark = try await geocoder.reverseGeocodeLocation(location).first else {
                    logger.warning("No placemark for \(coordinate.latitude), \(coordinate.longitude)")
                    return nil
                }

                let cache = LocationCache(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    city: placemark.locality,
                    country: placemark.country ?? "Unknown",
                    countryCode: placemark.isoCountryCode ?? "??",
                    region: placemark.administrativeArea
                )

                modelContext.insert(cache)
                try? modelContext.save()

                return cache
            } catch {
                if attempt < Self.maxRetries {
                    logger.info("Geocoding retry \(attempt + 1) for \(coordinate.latitude), \(coordinate.longitude)")
                    try? await Task.sleep(for: Self.retryDelay)
                } else {
                    logger.warning("Geocoding failed after \(Self.maxRetries) retries: \(error.localizedDescription)")
                }
            }
        }

        return nil
    }

    private func findCachedLocation(
        near coordinate: CLLocationCoordinate2D,
        in modelContext: ModelContext
    ) -> LocationCache? {
        let minLat = coordinate.latitude - Self.boundingBoxDelta
        let maxLat = coordinate.latitude + Self.boundingBoxDelta
        let minLon = coordinate.longitude - Self.boundingBoxDelta
        let maxLon = coordinate.longitude + Self.boundingBoxDelta

        let descriptor = FetchDescriptor<LocationCache>(
            predicate: #Predicate<LocationCache> {
                $0.latitude >= minLat && $0.latitude <= maxLat &&
                $0.longitude >= minLon && $0.longitude <= maxLon
            }
        )

        guard let nearby = try? modelContext.fetch(descriptor) else { return nil }

        return nearby.first { cache in
            cache.distance(to: coordinate) < Self.proximityCacheThreshold
        }
    }

    private func throttle() async {
        if let last = lastRequestTime {
            let elapsed = ContinuousClock.now - last
            if elapsed < Self.throttleDelay {
                try? await Task.sleep(for: Self.throttleDelay - elapsed)
            }
        }
        lastRequestTime = .now
    }
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
