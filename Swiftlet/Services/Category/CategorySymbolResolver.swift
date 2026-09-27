//
//  CategorySymbolResolver.swift
//  Swiftlet
//

import Foundation

/// Picks an icon for a category from its name, used as the fallback when the user has not
/// chosen one by hand and Apple Intelligence is unavailable.
enum CategorySymbolResolver {
    static func icon(forName name: String, scope: CategoryScope = .both) -> CategoryIconIntelligence.Icon {
        let haystack = name.lowercased()

        for rule in rules where rule.keywords.contains(where: haystack.contains) {
            return rule.icon
        }

        switch scope {
        case .income: return .salary
        case .expense: return .shopping
        case .both: return .other
        }
    }

    static func symbol(forName name: String, scope: CategoryScope = .both) -> String {
        icon(forName: name, scope: scope).symbolName
    }

    private struct Rule {
        let keywords: [String]
        let icon: CategoryIconIntelligence.Icon
    }

    private static let rules: [Rule] = [
        Rule(keywords: ["food", "meal", "eat", "restaurant", "makan", "snack", "lunch", "dinner", "breakfast"], icon: .food),
        Rule(keywords: ["grocer", "supermarket", "market", "sayur"], icon: .groceries),
        Rule(keywords: ["coffee", "cafe", "drink", "kopi", "tea"], icon: .drink),
        Rule(keywords: ["transport", "car", "ride", "fuel", "gas", "taxi", "bus", "train", "commute", "ojek"], icon: .transport),
        Rule(keywords: ["flight", "travel", "trip", "holiday", "vacation", "hotel"], icon: .travel),
        Rule(keywords: ["shop", "clothes", "fashion", "purchase", "belanja", "store"], icon: .shopping),
        Rule(keywords: ["bill", "utility", "rent", "electric", "water", "internet", "subscription"], icon: .bills),
        Rule(keywords: ["phone", "mobile", "pulsa", "data plan"], icon: .phone),
        Rule(keywords: ["entertain", "movie", "game", "fun", "music", "concert"], icon: .entertainment),
        Rule(keywords: ["health", "medic", "doctor", "hospital", "pharmacy", "obat", "dental"], icon: .health),
        Rule(keywords: ["fitness", "gym", "sport", "workout"], icon: .fitness),
        Rule(keywords: ["education", "school", "course", "book", "tuition", "study", "kuliah"], icon: .education),
        Rule(keywords: ["pet", "cat", "dog"], icon: .pet),
        Rule(keywords: ["home", "house", "furniture", "repair"], icon: .home),
        Rule(keywords: ["salary", "wage", "payroll", "gaji"], icon: .salary),
        Rule(keywords: ["reimburse", "refund", "claim", "payback"], icon: .refund),
        Rule(keywords: ["bonus", "gift", "prize", "reward", "hadiah"], icon: .gift),
        Rule(keywords: ["saving", "emergency", "tabungan", "fund"], icon: .savings),
        Rule(keywords: ["invest", "stock", "dividend", "interest", "crypto"], icon: .investment),
        Rule(keywords: ["parent", "family", "kid", "child", "orang tua"], icon: .family),
        Rule(keywords: ["freelance", "side", "project", "business", "client"], icon: .work),
        Rule(keywords: ["donation", "charity", "zakat", "sedekah"], icon: .donation),
        Rule(keywords: ["tax", "fee", "admin", "charge"], icon: .tax),
        Rule(keywords: ["transfer", "topup", "top up", "withdraw"], icon: .transfer),
        Rule(keywords: ["other", "misc"], icon: .other),
    ]
}
