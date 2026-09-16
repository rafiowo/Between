import Foundation

enum Direction: String, Codable, CaseIterable, Identifiable {
    case owedToMe, iOwe
    var id: String { rawValue }
    var title: String { self == .owedToMe ? "They owe me" : "I owe them" }
}

struct Repayment: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Int64
    var date: Date
}

struct Debt: Codable, Identifiable, Equatable {
    var id = UUID()
    var person: String
    var direction: Direction
    var amount: Int64
    var note: String
    var createdAt: Date
    var dueDate: Date?
    var repayments: [Repayment] = []
    var paid: Int64 { repayments.reduce(0) { $0 + $1.amount } }
    var remaining: Int64 { amount - paid }
    var isSettled: Bool { remaining == 0 }
    var isOverdue: Bool {
        guard let dueDate, !isSettled else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: Date())
    }
    var personKey: String { person.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
}

struct Ledger: Codable, Equatable {
    static let currencies = ["AUD", "CAD", "EUR", "GBP", "INR", "NZD", "USD"]
    var version = 1
    var currency = currencies.contains(Locale.current.currency?.identifier ?? "") ? Locale.current.currency!.identifier : "USD"
    var debts: [Debt] = []

    func validated() throws -> Ledger {
        guard version == 1, Self.currencies.contains(currency), debts.count <= 100_000,
              Set(debts.map(\.id)).count == debts.count else { throw LedgerError.invalidBackup }
        for debt in debts {
            guard !debt.person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  debt.person.count <= 100, debt.note.count <= 1000,
                  debt.amount > 0, debt.amount <= Money.maximum,
                  debt.repayments.count <= 100_000,
                  Set(debt.repayments.map(\.id)).count == debt.repayments.count else { throw LedgerError.invalidBackup }
            var remaining = debt.amount
            for payment in debt.repayments {
                guard payment.amount > 0, payment.amount <= remaining else { throw LedgerError.invalidBackup }
                remaining -= payment.amount
            }
        }
        return self
    }
}

enum LedgerError: LocalizedError {
    case invalidBackup, invalidPayment, invalidAdjustment, missingEntry
    var errorDescription: String? {
        switch self {
        case .invalidBackup: "This backup contains unsupported or invalid data. Your current entries have not been changed."
        case .invalidPayment: "Enter a repayment greater than zero and no larger than the remaining balance."
        case .invalidAdjustment: "Enter an amount greater than zero. Added amounts must keep the entry below the maximum."
        case .missingEntry: "This entry could not be found."
        }
    }
}

enum Money {
    // At most 9,999,999.99 per entry; all arithmetic uses exact minor units.
    static let maximum: Int64 = 999_999_999
    static func parse(_ text: String, locale: Locale = .current) -> Int64? {
        let separator = locale.decimalSeparator ?? "."
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = raw.replacingOccurrences(of: separator, with: ".")
        guard normalized.range(of: "^[0-9]+(?:\\.[0-9]{0,2})?$", options: .regularExpression) != nil,
              let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              decimal > 0, decimal <= Decimal(maximum) / 100 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).int64Value
    }
    static func format(_ amount: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: Decimal(amount) / 100)) ?? "\(currency) \(amount)"
    }
    static func input(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: Decimal(amount) / 100)) ?? ""
    }
}
