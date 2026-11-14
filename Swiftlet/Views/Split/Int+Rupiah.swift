//
//  Int+Rupiah.swift
//  Swiftlet
//

import Foundation

extension Int {
    var rupiah: String {
        CurrencyFormatter.rupiah(Decimal(self))
    }
}
