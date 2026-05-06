import Foundation
import OpenAPIRuntime

/// Decodes ISO-8601 date-time strings that may or may not carry fractional
/// seconds. swift-openapi-runtime's default ``ISO8601DateTranscoder`` is
/// created with ``ISO8601DateFormatter()`` — which rejects fractional
/// seconds. Our server emits timestamps like ``"2026-04-12T20:44:32.815Z"``
/// via JavaScript ``Date.prototype.toISOString()``, so the default decoder
/// throws ``DecodingError.dataCorrupted`` on every response that carries
/// a ``Date`` field (dashboard, tasks).
///
/// This transcoder tries the fractional-seconds formatter first, falls
/// back to the plain form, and encodes with fractional seconds so round
/// trips are stable.
struct TolerantISO8601Transcoder: DateTranscoder {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func encode(_ date: Date) throws -> String {
        Self.withFractional.string(from: date)
    }

    func decode(_ string: String) throws -> Date {
        if let d = Self.withFractional.date(from: string) { return d }
        if let d = Self.withoutFractional.date(from: string) { return d }
        throw DecodingError.dataCorruptedError(
            in: SingleValueDecodingContainerStub(),
            debugDescription: "Date string '\(string)' is not a valid ISO-8601 timestamp"
        )
    }
}

/// Minimal stub so `DecodingError.dataCorruptedError(in:debugDescription:)`
/// has a container to reference. Never actually read from; only exists so
/// the initializer accepts a container value.
private struct SingleValueDecodingContainerStub: SingleValueDecodingContainer {
    var codingPath: [CodingKey] { [] }
    func decodeNil() -> Bool { true }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try unsupported(type)
    }

    private func unsupported<T>(_ type: T.Type) throws -> T {
        throw DecodingError.valueNotFound(
            type,
            .init(codingPath: [], debugDescription: "stub container")
        )
    }
    func decode(_ type: Bool.Type) throws -> Bool { try unsupported(type) }
    func decode(_ type: String.Type) throws -> String { try unsupported(type) }
    func decode(_ type: Double.Type) throws -> Double { try unsupported(type) }
    func decode(_ type: Float.Type) throws -> Float { try unsupported(type) }
    func decode(_ type: Int.Type) throws -> Int { try unsupported(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try unsupported(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try unsupported(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try unsupported(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try unsupported(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try unsupported(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try unsupported(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try unsupported(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try unsupported(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try unsupported(type) }
}
