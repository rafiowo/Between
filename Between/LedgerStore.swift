import Foundation
import Combine

@MainActor
final class LedgerStore: ObservableObject {
    @Published private(set) var ledger = Ledger()
    @Published var errorMessage: String?
    @Published private(set) var recoveryRequired = false
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory.appending(path: "Between/ledger.json")
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        do { ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: self.fileURL)).validated() }
        catch {
            recoveryRequired = true
            errorMessage = "Your saved data could not be opened. It has been preserved. Restore a backup in Settings to continue. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func commit(_ next: Ledger) -> Bool {
        do {
            let validated = try next.validated()
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(validated)
            // Preserve the unreadable file before any recovery replacement.
            if recoveryRequired, FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.copyItem(at: fileURL, to: fileURL.deletingLastPathComponent().appending(path: "unreadable-\(UUID()).json"))
            }
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            ledger = validated
            recoveryRequired = false
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func add(_ debt: Debt) -> Bool {
        guard !recoveryRequired else { return false }
        var next = ledger
        next.debts.insert(debt, at: 0)
        return commit(next)
    }

    func repay(_ id: UUID, amount: Int64, date: Date) -> Bool {
        var next = ledger
        guard let index = next.debts.firstIndex(where: { $0.id == id }) else { errorMessage = LedgerError.missingEntry.localizedDescription; return false }
        guard amount > 0, amount <= next.debts[index].remaining else { errorMessage = LedgerError.invalidPayment.localizedDescription; return false }
        next.debts[index].repayments.append(Repayment(amount: amount, date: date))
        return commit(next)
    }

    func increaseAmount(_ id: UUID, by amount: Int64) -> Bool {
        var next = ledger
        guard let index = next.debts.firstIndex(where: { $0.id == id }) else { errorMessage = LedgerError.missingEntry.localizedDescription; return false }
        guard amount > 0, next.debts[index].amount <= Money.maximum - amount else { errorMessage = LedgerError.invalidAdjustment.localizedDescription; return false }
        next.debts[index].amount += amount
        return commit(next)
    }

    func settle(_ id: UUID, date: Date = Date()) -> Bool {
        guard let debt = ledger.debts.first(where: { $0.id == id }) else { errorMessage = LedgerError.missingEntry.localizedDescription; return false }
        guard debt.remaining > 0 else { return true }
        return repay(id, amount: debt.remaining, date: date)
    }

    func removePayment(_ debtID: UUID, paymentID: UUID) {
        var next = ledger
        guard let index = next.debts.firstIndex(where: { $0.id == debtID }) else { return }
        next.debts[index].repayments.removeAll { $0.id == paymentID }
        commit(next)
    }

    func delete(_ id: UUID) -> Bool {
        var next = ledger
        next.debts.removeAll { $0.id == id }
        return commit(next)
    }

    func setCurrency(_ currency: String) {
        guard ledger.debts.isEmpty, !recoveryRequired else { return }
        var next = ledger
        next.currency = currency
        commit(next)
    }

    func money(_ amount: Int64) -> String { Money.format(amount, currency: ledger.currency) }
    func total(_ direction: Direction) -> Int64 { ledger.debts.filter { $0.direction == direction }.reduce(0) { $0 + $1.remaining } }
}
