//
//  BankEmailParser.swift
//  Swiftlet
//

import Foundation

nonisolated struct ParsedBankEmail: Equatable {
    var provider: String
    var type: TransactionType
    var title: String
    var amount: Int
    var walletHint: String
    var destinationHint: String?
    var reference: String
}

nonisolated enum BankEmailParser {
    static func parse(_ text: String) -> ParsedBankEmail? {
        let cleaned = plainText(from: text)
        let doc = EmailText(cleaned)
        let lower = cleaned.lowercased()

        if lower.contains("gotagihan") { return goTagihan(doc) }
        if lower.contains("wondr by bni") { return bni(doc, lower: lower) }
        if lower.contains("mybca") || lower.contains("halo bca") || lower.contains("bank central asia") {
            return bca(doc)
        }
        if lower.contains("jenis kendaraan"), lower.contains("pesanan id") { return grab(doc) }
        if lower.contains("pembayaran berhasil"), lower.contains("metode pembayaran") { return ovoMerchant(doc) }
        if lower.contains("payment success"), lower.contains("detail merchant") { return merchantNotice(doc) }
        if lower.contains("thanks for ordering go") { return gojek(doc) }
        return nil
    }

    static func plainText(from raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        guard text.range(of: #"<(?:html|body|table|tr|td|br|p|div)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        else { return text }

        text = text.replacingOccurrences(of: #"(?is)<(?:script|style)\b.*?</(?:script|style)>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)<br\s*/?>|</(?:td|th|tr|p|div|li|h\d)>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        for (entity, value) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        return text
    }

    static func rupiah(_ raw: String) -> Int? {
        var text = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        if let decimals = text.range(of: #"[.,]\d{1,2}$"#, options: .regularExpression) {
            text.removeSubrange(decimals)
        }
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    static func amount(in text: String) -> Int? {
        guard let match = firstMatch(#"(?:IDR|Rp)\s*(\d[\d.,]*)"#, in: text) else { return nil }
        return rupiah(match)
    }

    static func canonicalWallet(_ hint: String) -> String {
        let lower = hint.lowercased()
        let known = [
            ("ovo", "OVO"), ("gopay", "GoPay"), ("go-pay", "GoPay"), ("shopeepay", "ShopeePay"),
            ("linkaja", "LinkAja"), ("dana", "Dana"), ("bca", "BCA"), ("bni", "BNI"), ("grab", "Grab"),
        ]
        return known.first { lower.contains($0.0) }?.1 ?? hint.trimmingCharacters(in: .whitespaces)
    }

    private static func make(
        provider: String, type: TransactionType = .expense, title: String?, amountText: String?,
        wallet: String?, destination: String? = nil, reference: String?
    ) -> ParsedBankEmail? {
        guard let amountText, let amount = amount(in: amountText), amount > 0 else { return nil }
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ParsedBankEmail(
            provider: provider,
            type: type,
            title: cleanTitle.isEmpty ? provider : cleanTitle,
            amount: amount,
            walletHint: canonicalWallet(wallet ?? ""),
            destinationHint: destination.map(canonicalWallet),
            reference: reference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    private static func bca(_ doc: EmailText) -> ParsedBankEmail? {
        if let status = doc.field(["Status"]), !status.lowercased().contains("success") { return nil }
        return make(
            provider: "BCA",
            title: doc.field(["Payment to", "Transfer to", "Merchant Name"]) ?? doc.field(["Transaction Type"]),
            amountText: doc.field(["Total Payment", "Total Amount", "Amount"]),
            wallet: "BCA",
            reference: doc.field(["Reference No.", "RRN"])
        )
    }

    private static func bni(_ doc: EmailText, lower: String) -> ParsedBankEmail? {
        let recipient = doc.lineAfter("Penerima")
        if lower.contains("top-up") {
            let destination = canonicalWallet(recipient ?? "")
            return make(
                provider: "BNI",
                type: .transfer,
                title: "Top-up \(destination)",
                amountText: doc.field(["Total", "Nominal"]),
                wallet: "BNI",
                destination: destination.isEmpty ? nil : destination,
                reference: doc.field(["Ref ID"])
            )
        }
        return make(
            provider: "BNI",
            title: recipient,
            amountText: doc.field(["Total", "Nominal"]),
            wallet: "BNI",
            reference: doc.field(["Kode RRN", "Reference ID"])
        )
    }

    private static func merchantNotice(_ doc: EmailText) -> ParsedBankEmail? {
        make(
            provider: "QRIS",
            type: .income,
            title: doc.field(["Nama Merchant"]),
            amountText: doc.field(["Total", "Nominal"]),
            wallet: doc.field(["Nama Pengakuisisi"]),
            reference: doc.field(["No Referensi", "RRN"])
        )
    }

    private static func ovoMerchant(_ doc: EmailText) -> ParsedBankEmail? {
        make(
            provider: "OVO",
            title: doc.field(["Nama Toko"]),
            amountText: doc.field(["Total"]) ?? firstMatch(#"Pembayaran Berhasil\s*-\s*(Rp\s*[\d.,]+)"#, in: doc.text),
            wallet: doc.field(["Nama Issuer"]) ?? "OVO",
            reference: doc.field(["No. Referensi", "No. Resi (Kode Transaksi)"])
        )
    }

    private static func grab(_ doc: EmailText) -> ParsedBankEmail? {
        let vehicle = doc.lineAfter("Jenis Kendaraan") ?? "Grab"
        let restaurant = doc.lineAfter("Pesanan Dari")?.components(separatedBy: " - ").first
        let lowerVehicle = vehicle.lowercased()
        let title: String
        if lowerVehicle.contains("food") || lowerVehicle.contains("mart"), let restaurant, !restaurant.isEmpty {
            title = "\(vehicle) · \(restaurant)"
        } else {
            title = vehicle
        }
        let total = doc.field(["TOTAL (INCL. TAX)"])
            ?? firstMatch(#"\bTOTAL\s+(Rp\s*[\d.,]+)"#, in: doc.text)
        let method = firstMatch(#"Detail Pembayaran:\s*\n\s*([A-Za-z][A-Za-z ]*?)\s*:\s*Rp"#, in: doc.text)
        return make(
            provider: "Grab",
            title: title,
            amountText: total,
            wallet: method ?? "Grab",
            reference: doc.lineAfter("Pesanan ID") ?? doc.field(["Pesanan ID"])
        )
    }

    private static func goTagihan(_ doc: EmailText) -> ParsedBankEmail? {
        make(
            provider: "GoTagihan",
            title: firstMatch(#"Struk Pembayaran\s+(.+)"#, in: doc.text) ?? "GoTagihan",
            amountText: doc.field(["Total"]),
            // The value is blank in real GoTagihan emails, so the next line would be another label.
            wallet: doc.field(["Metode pembayaran"], valueMayBeOnNextLine: false) ?? "GoPay",
            reference: firstMatch(#"ID Pembayaran\s*[-:]\s*(\S+)"#, in: doc.text) ?? doc.field(["No Ref"])
        )
    }

    private static func gojek(_ doc: EmailText) -> ParsedBankEmail? {
        make(
            provider: "Gojek",
            title: firstMatch(#"Thanks for ordering\s+(\w+)"#, in: doc.text),
            amountText: doc.field(["Total paid", "Total payment"]),
            wallet: firstMatch(#"Paid with\s+(\w+)"#, in: doc.text) ?? "GoPay",
            reference: nil
        )
    }

    fileprivate static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text)
        else { return nil }
        let value = text[captured].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private nonisolated struct EmailText {
    let text: String
    let lines: [String]

    init(_ text: String) {
        self.text = text
        lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func field(_ keys: [String], valueMayBeOnNextLine: Bool = true) -> String? {
        for key in keys {
            let pattern = "^" + NSRegularExpression.escapedPattern(for: key)
                + #"(?:[ \t]*:[ \t]*|[ \t]*\t[ \t]*|[ ]{2,})(\S.*)$"#
            for line in lines {
                if let value = BankEmailParser.firstMatch(pattern, in: line) { return value }
            }
            if valueMayBeOnNextLine, let value = valueOnFollowingLine(of: key) { return value }
        }
        return nil
    }

    private func valueOnFollowingLine(of key: String) -> String? {
        let separators = CharacterSet(charactersIn: ": ")
        let target = key.trimmingCharacters(in: separators).lowercased()
        guard let index = lines.firstIndex(where: {
            $0.trimmingCharacters(in: separators).lowercased() == target
        }) else { return nil }
        return lines[(index + 1)...].first { !$0.trimmingCharacters(in: separators).isEmpty }
            .map { $0.trimmingCharacters(in: separators) }
    }

    func lineAfter(_ header: String) -> String? {
        let target = header.lowercased()
        guard let index = lines.firstIndex(where: {
            $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ": ")) == target
        }) else { return nil }
        return lines[(index + 1)...].first { !$0.isEmpty }
    }
}
