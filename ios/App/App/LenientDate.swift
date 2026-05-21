import Foundation

/// Flexible Date parser used by the DB models' custom Codable init(from:).
///
/// Postgres returns `timestamptz` values in formats like:
///   • `2024-11-12T10:30:00.123456+00:00`  (6-digit fractional seconds + colon-tz)
///   • `2024-11-12T10:30:00.123+00:00`      (millisecond + colon-tz)
///   • `2024-11-12T10:30:00Z`               (no fractional, Z)
///
/// Neither Swift's default `JSONDecoder.dateDecodingStrategy` nor
/// supabase-swift's bundled one accepts microsecond precision — DateFormatter
/// caps at milliseconds (`.SSS`). This helper falls back through several
/// strategies and returns nil only when nothing matches.
enum LenientDate {

    /// Non-optional Date decode for a single key. Throws if the value is
    /// missing entirely; otherwise returns `Date()` as a last-ditch fallback
    /// rather than throwing on a malformed string.
    static func required<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>, _ key: K
    ) throws -> Date {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let string = try? container.decode(String.self, forKey: key),
           let parsed = parse(string) {
            return parsed
        }
        // Last resort — don't let one malformed timestamp kill the row.
        return Date()
    }

    /// Optional Date decode for a single key. Returns nil for missing keys,
    /// null values, and malformed strings alike.
    static func optional<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>, _ key: K
    ) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let string = try? container.decode(String.self, forKey: key) {
            return parse(string)
        }
        return nil
    }

    /// Parse a single date string using a sequence of fallback strategies.
    static func parse(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)

        // 1. ISO 8601 with fractional seconds
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

        // 5. Bare date string ("2026-05-19") — Postgres DATE type
        //    returns this format. Critical for sessions.date: without
        //    this branch, the parser returned nil and the caller
        //    fell back to `Date()` = today, which caused every loaded
        //    session to appear on today's calendar cell instead of
        //    its real day. We parse at midnight in the LOCAL timezone
        //    (not UTC) so that Calendar.current extracts the same
        //    year/month/day the string carries, regardless of where
        //    the device is — a session "on May 19" should mean
        //    May 19 on any user's calendar.
        let dateOnly = DateFormatter()
        dateOnly.calendar  = Calendar(identifier: .gregorian)
        dateOnly.locale    = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone  = TimeZone.current
        dateOnly.dateFormat = "yyyy-MM-dd"
        if let d = dateOnly.date(from: s) { return d }

        return nil
    }
}
