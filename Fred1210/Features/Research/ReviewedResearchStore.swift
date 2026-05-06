import Foundation

struct ReviewedResearchRecord: Codable, Equatable {
    enum Decision: String, Codable {
        case adopt
        case adapt
        case ignore
        case reviewed
    }

    let id: String
    let title: String
    let decision: Decision
    let decidedAt: Date
}

actor ReviewedResearchStore {
    static let shared = ReviewedResearchStore()

    private let key = "fred.reviewedResearch"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func records() async -> [String: ReviewedResearchRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        do {
            return try decoder.decode([String: ReviewedResearchRecord].self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return [:]
        }
    }

    func mark(id: String, title: String, decision: ReviewedResearchRecord.Decision) async {
        var current = await records()
        current[id] = ReviewedResearchRecord(
            id: id,
            title: title,
            decision: decision,
            decidedAt: Date()
        )
        if let data = try? encoder.encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
