import Foundation

@main
struct LedgerChecks {
    @MainActor static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
        }
        let us = Locale(identifier: "en_US")
        check(Money.parse("12.34", locale: us) == 1234, "Exact cents")
        check(Money.parse("0.01", locale: us) == 1, "One cent")
        check(Money.parse("12,34", locale: Locale(identifier: "de_DE")) == 1234, "Localized decimal")
        for input in ["0", "-1", "1.001", "1e2", "NaN", "1,000", "10000000", "", "1.2.3"] {
            check(Money.parse(input, locale: us) == nil, "Reject invalid amount: \(input)")
        }
        let dir = URL.temporaryDirectory.appending(path: "BetweenTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "ledger.json")
        let store = LedgerStore(fileURL: file)
        let debt = Debt(person: "Sam", direction: .owedToMe, amount: 10000, note: "Dinner", createdAt: Date(), dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        check(store.add(debt), "Add and persist")
        check(store.total(.owedToMe) == 10000, "Incoming total")
        check(debt.isOverdue, "Overdue date")
        check(store.repay(debt.id, amount: 2500, date: Date()), "Partial repayment")
        check(store.total(.owedToMe) == 7500, "Remaining after partial repayment")
        check(!store.repay(debt.id, amount: 7501, date: Date()), "Overpayment blocked")
        check(!store.repay(debt.id, amount: 0, date: Date()), "Zero repayment blocked")
        check(store.repay(debt.id, amount: 7500, date: Date()), "Full repayment")
        check(store.ledger.debts[0].isSettled, "Settled automatically")
        check(!store.ledger.debts[0].isOverdue, "Settled debts not overdue")
        let payment = store.ledger.debts[0].repayments.last!
        store.removePayment(debt.id, paymentID: payment.id)
        check(store.total(.owedToMe) == 7500, "Undo repayment restores outstanding balance")
        let outgoing = Debt(person: "sam", direction: .iOwe, amount: 2000, note: "Taxi", createdAt: Date(), dueDate: nil)
        check(store.add(outgoing), "Add outgoing")
        check(store.total(.iOwe) == 2000 && store.total(.owedToMe) == 7500, "Directions remain separate")
        check(outgoing.personKey == debt.personKey, "Person normalization")
        let reloaded = LedgerStore(fileURL: file)
        check(reloaded.ledger == store.ledger, "Disk persistence round-trip")
        let originalCurrency = store.ledger.currency
        store.setCurrency(originalCurrency == "USD" ? "EUR" : "USD")
        check(store.ledger.currency == originalCurrency, "Currency cannot relabel existing money")
        var invalid = store.ledger
        invalid.debts[0].repayments = [Repayment(amount: Int64.max, date: Date())]
        check(!store.commit(invalid), "Invalid backup rejected without overflow")
        check(store.ledger == reloaded.ledger, "Invalid import leaves data unchanged")
        invalid = store.ledger
        invalid.debts.append(invalid.debts[0])
        check(!store.commit(invalid), "Duplicate entries rejected")
        check(store.delete(debt.id), "Delete debt")
        check(store.total(.owedToMe) == 0, "Delete updates total")
        try Data("broken file".utf8).write(to: file)
        let corrupted = LedgerStore(fileURL: file)
        check(corrupted.recoveryRequired, "Corruption detected")
        check(!corrupted.add(debt), "Corrupt saved data cannot be overwritten by a new entry")
        check(corrupted.commit(reloaded.ledger), "Backup recovery")
        let preserved = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("unreadable-") }
        check(preserved.count == 1, "Original corrupt file preserved")
        print("Passed \(count) checks: currency precision, repayments, totals, validation, persistence, recovery.")
    }
}
