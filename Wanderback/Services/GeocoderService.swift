import Foundation
import CoreLocation
import SwiftData
import os

actor GeocoderService {
    private let geocoder = CLGeocoder()
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "GeocoderService")

    /// Seuil de proximité pour réutiliser un cache existant (500m)
    static let proximityCacheThreshold: CLLocationDistance = 500

    /// Délai entre chaque requête pour respecter la limite Apple (45 req/min)
    private static let throttleDelay: Duration = .milliseconds(1334) // ~45 req/min

    private var lastRequestTime: ContinuousClock.Instant?

    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        modelContext: ModelContext
    ) async -> LocationCache? {
        // 1. Chercher dans le cache
        if let cached = findCachedLocation(near: coordinate, in: modelContext) {
            return cached
        }

        // 2. Throttle
        await throttle()

        // 3. Géocoder
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
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

            logger.info("Geocoded: \(cache.displayName)")
            return cache
        } catch {
            logger.warning("Geocoding failed for \(coordinate.latitude), \(coordinate.longitude): \(error.localizedDescription)")
            return nil
        }
    }

    func batchGeocode(
        coordinates: [CLLocationCoordinate2D],
        modelContext: ModelContext
    ) async -> [CLLocationCoordinate2D: LocationCache] {
        var results: [CLLocationCoordinate2D: LocationCache] = [:]

        for coordinate in coordinates {
            if let cache = await reverseGeocode(coordinate: coordinate, modelContext: modelContext) {
                results[coordinate] = cache
            }
        }

        logger.info("Batch geocoded: \(results.count)/\(coordinates.count) succeeded")
        return results
    }

    private func findCachedLocation(
        near coordinate: CLLocationCoordinate2D,
        in modelContext: ModelContext
    ) -> LocationCache? {
        let descriptor = FetchDescriptor<LocationCache>()
        guard let allCached = try? modelContext.fetch(descriptor) else { return nil }

        return allCached.first { cache in
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
