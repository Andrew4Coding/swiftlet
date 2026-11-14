import CoreML
import Foundation
import NaturalLanguage

enum TransactionCategoryModel {
    private static let minimumConfidence = 0.4

    private static let model: NLModel? = {
        guard let ml = try? TransactionCategoryClassifier(configuration: MLModelConfiguration()).model else {
            return nil
        }
        return try? NLModel(mlModel: ml)
    }()

    static func classify(title: String, among candidates: [String]) -> String? {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty, let model else { return nil }

        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: candidates.count + 5)
        let allowed = Dictionary(candidates.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        let best = hypotheses
            .filter { allowed[$0.key.lowercased()] != nil }
            .max { $0.value < $1.value }

        guard let best, best.value >= minimumConfidence else { return nil }
        return allowed[best.key.lowercased()]
    }
}
