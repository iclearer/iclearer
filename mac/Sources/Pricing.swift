import Foundation

/// Website / buy-sheet prices from `iclearer-landing.html`.
enum Pricing {
    /// Yearly billed totals, Monthly per-month, One-time — indexes 0/1/2 = 1/2/5 Macs.
    static let yearly: [Double] = [29.99, 44.99, 74.99]
    static let monthly: [Double] = [4.99, 7.99, 12.99]
    static let once: [Double] = [79.99, 119.99, 189.99]
    static let macSeats: [Int] = [1, 2, 5]

    enum Plan: Int, CaseIterable {
        case yearly = 0
        case monthly = 1
        case once = 2

        var apiValue: String {
            switch self {
            case .yearly: return "yearly"
            case .monthly: return "monthly"
            case .once: return "once"
            }
        }

        var label: String {
            switch self {
            case .yearly: return "Yearly"
            case .monthly: return "Monthly"
            case .once: return "One-time"
            }
        }
    }

    static func macIndex(for seats: Int) -> Int {
        if seats >= 5 { return 2 }
        if seats >= 2 { return 1 }
        return 0
    }

    static func price(plan: Plan, macs: Int) -> Double {
        let i = macIndex(for: macs)
        switch plan {
        case .yearly: return yearly[i]
        case .monthly: return monthly[i]
        case .once: return once[i]
        }
    }

    static func priceLabel(plan: Plan, macs: Int) -> String {
        let amount = price(plan: plan, macs: macs)
        switch plan {
        case .yearly:
            let perMonth = amount / 12
            return String(format: "$%.2f", perMonth)
        case .monthly, .once:
            return String(format: "$%.2f", amount)
        }
    }

    static func termLabel(plan: Plan, macs: Int) -> String {
        let amount = price(plan: plan, macs: macs)
        let seat = macs == 1 ? "1 Mac" : "\(macs) Macs"
        switch plan {
        case .yearly:
            return String(format: "Yearly · $%.2f/yr · %@", amount, seat)
        case .monthly:
            return "Monthly · \(seat)"
        case .once:
            return "One-time · \(seat)"
        }
    }
}
