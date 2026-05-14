import Foundation

/// Flexible Date parser used by the DB models' custom Codable init(from:).
///
/// Postgres returns `timestamptz` values in formats like:
///   • `2024-11-12T10:30:00.123456+00:00`  (6-digit fractional seconds + colon-tz)
///   • `2024-11-12T10:30:00.123+00:00`      (millisecond + colon-tz)
///   • `2024-11-12T10:30:00Z`               (no fractional, Z)
///   • `2024-11-12 10:30:00+00`             (space + partial tz, rare)
///
/// Swift's default `JSONDecoder.dateDecodingStrategy` is `.deferredToDate`
/// which only accepts reference-date intervals — it CANNOT parse any of the
/// above. And even supabase-swift's bundled strategy chokes on microseconds
/// (`.SSSSSS`) because DateFormatter caps at milliseconds (`.SSS`).
///
/// This helper tries `ISO8601DateFormatter` (which IS lenient enough), falls
/// back to stripping the fractional-seconds component if microseconds, and
/// returns nil only when nothing parses.
enum LenientDate {

    /// Decode a non-optional Date from the given keyed container.
    /// Throws if the field is missing entirely; falls back to `Date()`
    /// when the value is present but malformed.
    static func required<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>, _ key: K
    ) throws -> Date {
        if let d = try? container.decode(Date.self, forKey: key) {
            return d
        }
        let s = try container.decode(String.self, forKey: key)
        return parse(s) ?? Date()
    }

    /// Decode an optional Date from the given keyed container.
    /// Returns nil for missing keys, null values, OR malformed strings.
    static func optional<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>, _ key: K
    ) -> Date? {
        if container.contains(key) == false { return nil }
        if let d = try? container.decodeIfPresent(Date.self, forKey: key) {
            return d
        }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) {
            return s.flatMap(parse)
        }
        return nil
    }

    /// Parse a single date string using a sequence of fallback strategies.
    static func parse(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)

        // 1. ISO 8601 with fractional seconds (millisecond precision)
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: s) { return d }

        // 2. ISO 8601 without fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }

        // 3. Strip an over-precision fractional-seconds component
        //    "...:30.123456+00:00" → "...:30+00:00"
        let cleaned = s.replacingOccurrences(
            of: #"\.\d+"#, with: "", options: .regularExpression
        )
        if let d = iso.date(from: cleaned) { return d }

        // 4. Replace space separator with T (Postgres-style)
        let withT = cleaned.replacingOccurrences(of: " ", with: "T")
        if let d = iso.date(from: withT) { return d }

        return nil
    }
}
