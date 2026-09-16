import SwiftUI
import UniformTypeIdentifiers

enum Palette {
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.18)
    static let mint = Color(red: 0.78, green: 0.94, blue: 0.68)
    static let paper = Color(uiColor: .systemGroupedBackground)
    static let green = Color(red: 0.13, green: 0.45, blue: 0.32)
    static let orange = Color(red: 0.65, green: 0.30, blue: 0.15)
}

@main
struct BetweenApp: App {
    @StateObject private var store = LedgerStore()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store).tint(Palette.green)
        }
    }
}

enum EntryFilter: String, CaseIterable {
    case active = "Open", owed = "Owed to me", owing = "I owe", settled = "Settled"
}

struct HomeView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var filter: EntryFilter = .active
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingSettings = false
    private var entries: [Debt] {
        store.ledger.debts.filter { debt in
            let matches: Bool
            switch filter {
            case .active: matches = !debt.isSettled
            case .owed: matches = !debt.isSettled && debt.direction == .owedToMe
            case .owing: matches = !debt.isSettled && debt.direction == .iOwe
            case .settled: matches = debt.isSettled
            }
            return matches && (search.isEmpty || debt.person.localizedCaseInsensitiveContains(search) || debt.note.localizedCaseInsensitiveContains(search))
        }.sorted { $0.createdAt > $1.createdAt }
    }
    private var people: [String] { Array(Set(entries.map(\.personKey))).sorted() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A LITTLE CLARITY").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                        Text("Money between\nyou & your people.").font(.system(size: 33, weight: .bold, design: .rounded)).tracking(-1)
                    }.padding(.top, 8)
                    balanceCard
                    if store.recoveryRequired {
                        Label("Saved data needs attention. Open Settings to restore a backup.", systemImage: "exclamationmark.triangle")
                            .font(.callout).foregroundStyle(Palette.orange)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Your people").font(.title2.bold())
                            Spacer()
                            Text("\(people.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(EntryFilter.allCases, id: \.self) { item in
                                    Button { filter = item } label: {
                                        Text(item.rawValue).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(filter == item ? Palette.ink : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                                            .foregroundStyle(filter == item ? .white : .primary)
                                    }.buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : [])
                                }
                            }
                        }
                        if entries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: filter == .settled ? "checkmark.circle" : "person.2.crop.square.stack")
                                    .font(.system(size: 34, weight: .light)).foregroundStyle(Palette.green)
                                Text(search.isEmpty ? (filter == .settled ? "All settled entries live here" : "Keep the little things clear")
                                     : "No matching entries").font(.headline)
                                Text(search.isEmpty ? "Dinner, a loan, a shared trip. Add an entry and let Between keep count." : "Try another name or note.")
                                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                if store.ledger.debts.isEmpty {
                                    Button("Add your first entry") { showingAdd = true }.font(.subheadline.bold()).disabled(store.recoveryRequired)
                                }
                            }.frame(maxWidth: .infinity).padding(28).background(.background, in: RoundedRectangle(cornerRadius: 24))
                        } else {
                            VStack(spacing: 12) {
                                ForEach(people, id: \.self) { key in
                                    let debts = entries.filter { $0.personKey == key }
                                    NavigationLink { PersonView(personKey: key) } label: { PersonCard(debts: debts) }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Label("Just your records. No accounts, no awkwardness.", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 8)
                }.padding(20)
            }
            .background(Palette.paper)
            .navigationTitle("between")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Settings") }
            }
            .searchable(text: $search, prompt: "Find a person or note")
            .safeAreaInset(edge: .bottom) {
                Button { showingAdd = true } label: {
                    Label("Add an entry", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(18)
                        .background(Palette.ink, in: Capsule()).foregroundStyle(.white)
                }.disabled(store.recoveryRequired).padding(.horizontal, 20).padding(.vertical, 10).background(.regularMaterial)
            }
            .sheet(isPresented: $showingAdd) { AddEntryView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .alert("Something needs attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label("AT A GLANCE", systemImage: "arrow.left.arrow.right").font(.caption.weight(.bold)).tracking(1)
                Spacer()
                Text(store.ledger.currency).font(.caption.bold()).padding(.horizontal, 9).padding(.vertical, 5).background(.white.opacity(0.12), in: Capsule())
            }.foregroundStyle(.white.opacity(0.75))
            VStack(alignment: .leading, spacing: 5) {
                Text("Owed to you").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Text(store.money(store.total(.owedToMe))).font(.system(size: 38, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(Palette.mint)
            }
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("You owe").font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text(store.money(store.total(.iOwe))).font(.title3.weight(.semibold)).foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Net balance").font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text(store.money(store.total(.owedToMe) - store.total(.iOwe))).font(.title3.weight(.semibold)).foregroundStyle(.white)
                }
            }.minimumScaleFactor(0.6).lineLimit(1)
        }.padding(24).background(Palette.ink, in: RoundedRectangle(cornerRadius: 28))
    }
}

struct PersonCard: View {
    @EnvironmentObject private var store: LedgerStore
    let debts: [Debt]
    private var incoming: Int64 { debts.filter { $0.direction == .owedToMe }.reduce(0) { $0 + $1.remaining } }
    private var outgoing: Int64 { debts.filter { $0.direction == .iOwe }.reduce(0) { $0 + $1.remaining } }
    var body: some View {
        HStack(spacing: 14) {
            Text(String((debts.first?.person ?? "?").prefix(1)).uppercased()).font(.title3.weight(.semibold))
                .frame(width: 46, height: 46).background(Palette.mint.opacity(0.4), in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Palette.green)
            VStack(alignment: .leading, spacing: 5) {
                Text(debts.first?.person ?? "").font(.headline)
                Text("\(debts.count) \(debts.count == 1 ? "entry" : "entries")\(debts.contains(where: \.isOverdue) ? " · Overdue" : "")")
                    .font(.caption).foregroundStyle(debts.contains(where: \.isOverdue) ? Palette.orange : .secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                if incoming > 0 { Text("+" + store.money(incoming)).foregroundStyle(Palette.green).accessibilityLabel("Owes you \(store.money(incoming))") }
                if outgoing > 0 { Text("−" + store.money(outgoing)).foregroundStyle(Palette.orange).accessibilityLabel("You owe \(store.money(outgoing))") }
                if incoming == 0 && outgoing == 0 { Label("Settled", systemImage: "checkmark").foregroundStyle(.secondary) }
            }.font(.subheadline.weight(.semibold)).minimumScaleFactor(0.6).lineLimit(1)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct PersonView: View {
    @EnvironmentObject private var store: LedgerStore
    let personKey: String
    @State private var adding = false
    private var debts: [Debt] { store.ledger.debts.filter { $0.personKey == personKey }.sorted { $0.createdAt > $1.createdAt } }
    var body: some View {
        List {
            Section {
                PersonCard(debts: debts).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            } footer: { Text("+ They owe you    − You owe them\nOpposite debts stay separate until you record a repayment.") }
            Section("Open entries") {
                ForEach(debts.filter { !$0.isSettled }) { debt in
                    NavigationLink { DebtDetailView(debtID: debt.id) } label: { DebtRow(debt: debt) }
                }
                if debts.allSatisfy(\.isSettled) { Text("Nothing outstanding. You're all square.").foregroundStyle(.secondary) }
            }
            if debts.contains(where: \.isSettled) {
                Section("Settled") {
                    ForEach(debts.filter(\.isSettled)) { debt in
                        NavigationLink { DebtDetailView(debtID: debt.id) } label: { DebtRow(debt: debt) }
                    }
                }
            }
        }.navigationTitle(debts.first?.person ?? "Person")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add entry for this person") }
            .sheet(isPresented: $adding) { AddEntryView(person: debts.first?.person ?? "") }
    }
}

struct DebtRow: View {
    @EnvironmentObject private var store: LedgerStore
    let debt: Debt
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(debt.note.isEmpty ? debt.direction.title : debt.note).font(.headline).lineLimit(2)
                Spacer()
                Text(store.money(debt.remaining)).font(.headline).foregroundStyle(debt.direction == .owedToMe ? Palette.green : Palette.orange)
            }
            HStack {
                Text(debt.isSettled ? "Settled" : debt.direction.title)
                Spacer()
                if let due = debt.dueDate, !debt.isSettled {
                    Text("\(debt.isOverdue ? "Overdue" : "Due") \(due.formatted(date: .abbreviated, time: .omitted))").foregroundStyle(debt.isOverdue ? Palette.orange : .secondary)
                }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
}

enum BalanceAdjustmentMode: String, Identifiable {
    case add, subtract
    var id: String { rawValue }
    var title: String { self == .add ? "Add to amount" : "Subtract from amount" }
    var fieldTitle: String { self == .add ? "Amount to add" : "Amount to subtract" }
    var buttonTitle: String { self == .add ? "Add" : "Subtract" }
    var footer: String {
        self == .add
        ? "Use this when the total owed has grown."
        : "Use this when the outstanding balance should go down. Subtracting the full balance moves this entry to Settled."
    }
}

struct AddEntryView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State var person = ""
    @State private var direction: Direction = .owedToMe
    @State private var amount = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    private var valid: Bool { !person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && person.count <= 100 && note.count <= 1000 && Money.parse(amount) != nil }
    private var suggestions: [String] { Array(Set(store.ledger.debts.map(\.person))).filter { person.isEmpty || $0.localizedCaseInsensitiveContains(person) }.sorted() }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Who owes whom?", selection: $direction) {
                        ForEach(Direction.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("The person") {
                    TextField("Name", text: $person).textContentType(.name).autocorrectionDisabled()
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions.prefix(10), id: \.self) { name in
                                    Button(name) { person = name }.font(.caption.bold()).buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                Section {
                    HStack {
                        Text(store.ledger.currency).foregroundStyle(.secondary)
                        TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.title2.monospacedDigit()).accessibilityLabel("Amount")
                    }
                    TextField("What's it for? (optional)", text: $note, axis: .vertical).lineLimit(1...4)
                } header: { Text("The details") } footer: {
                    Text("Enter an amount with up to 2 decimal places.\(store.ledger.debts.isEmpty ? " You can change currency in Settings before your first entry." : "")")
                }
                Section {
                    Toggle("Add a due date", isOn: $hasDueDate)
                    if hasDueDate { DatePicker("Due", selection: $dueDate, displayedComponents: .date) }
                } footer: { Text("Due dates are shown in the app. No messages or notifications are sent.") }
            }
            .navigationTitle("New entry").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Money.parse(amount) else { return }
                        let cleanName = person.trimmingCharacters(in: .whitespacesAndNewlines)
                        let debt = Debt(person: cleanName, direction: direction, amount: value, note: note.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: Date(), dueDate: hasDueDate ? dueDate : nil)
                        if store.add(debt) { dismiss() }
                    }.bold().disabled(!valid)
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }
}

struct DebtDetailView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    let debtID: UUID
    @State private var showingRepayment = false
    @State private var adjustmentMode: BalanceAdjustmentMode?
    @State private var confirmingSettle = false
    @State private var confirmingDelete = false
    @State private var paymentToDelete: Repayment?
    private var debt: Debt? { store.ledger.debts.first { $0.id == debtID } }
    var body: some View {
        Group {
            if let debt {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(debt.isSettled ? "ALL SQUARE" : debt.direction.title.uppercased()).font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary)
                            Text(store.money(debt.remaining)).font(.system(size: 38, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                                .foregroundStyle(debt.direction == .owedToMe ? Palette.green : Palette.orange)
                            ProgressView(value: Double(debt.paid), total: Double(debt.amount)).tint(Palette.green)
                                .accessibilityLabel("Repaid \(store.money(debt.paid)) of \(store.money(debt.amount))")
                            Text("\(store.money(debt.paid)) repaid of \(store.money(debt.amount))").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    Section("Details") {
                        LabeledContent("Person", value: debt.person)
                        if !debt.note.isEmpty { LabeledContent("For", value: debt.note) }
                        LabeledContent("Added", value: debt.createdAt.formatted(date: .abbreviated, time: .omitted))
                        if let due = debt.dueDate { LabeledContent(debt.isOverdue ? "Overdue since" : "Due", value: due.formatted(date: .abbreviated, time: .omitted)) }
                    }
                    if !debt.isSettled {
                        Section {
                            Button { adjustmentMode = .add } label: {
                                Label("Add to amount", systemImage: "plus.circle.fill").font(.headline).padding(.vertical, 6)
                            }
                            Button { adjustmentMode = .subtract } label: {
                                Label("Subtract from amount", systemImage: "minus.circle.fill").font(.headline).padding(.vertical, 6)
                            }
                            Button { confirmingSettle = true } label: {
                                Label("Settled", systemImage: "checkmark.circle.fill").font(.headline).padding(.vertical, 6)
                            }
                            Button { showingRepayment = true } label: {
                                Label("Record a repayment", systemImage: "arrow.down.left.circle.fill").font(.headline).padding(.vertical, 6)
                            }
                        } footer: { Text("Settled entries move to the Settled page. Subtract and repayment both lower the outstanding amount.") }
                    }
                    Section("Repayment history") {
                        if debt.repayments.isEmpty { Text("No repayments yet.").foregroundStyle(.secondary) }
                        ForEach(debt.repayments.sorted { $0.date > $1.date }) { payment in
                            HStack {
                                Label(payment.date.formatted(date: .abbreviated, time: .omitted), systemImage: "checkmark.circle.fill").foregroundStyle(Palette.green)
                                Spacer()
                                Text(store.money(payment.amount)).monospacedDigit()
                            }.swipeActions { Button("Undo", role: .destructive) { paymentToDelete = payment } }
                                .contextMenu { Button("Undo repayment", role: .destructive) { paymentToDelete = payment } }
                        }
                    }
                    Section { Button("Delete entry", role: .destructive) { confirmingDelete = true } }
                }
                .navigationTitle(debt.person).navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingRepayment) { RepaymentView(debtID: debtID) }
                .sheet(item: $adjustmentMode) { mode in BalanceAdjustmentView(debtID: debtID, mode: mode) }
                .confirmationDialog("Mark this entry as settled? The remaining amount will be recorded as paid today.", isPresented: $confirmingSettle, titleVisibility: .visible) {
                    Button("Settled") { _ = store.settle(debtID) }
                }
                .confirmationDialog("Delete this entry and its repayment history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete entry", role: .destructive) { if store.delete(debtID) { dismiss() } }
                }
                .confirmationDialog("Undo this repayment? Its amount will be added back to the outstanding balance.", isPresented: Binding(get: { paymentToDelete != nil }, set: { if !$0 { paymentToDelete = nil } }), titleVisibility: .visible) {
                    Button("Undo repayment", role: .destructive) {
                        if let paymentToDelete { store.removePayment(debtID, paymentID: paymentToDelete.id) }
                        paymentToDelete = nil
                    }
                }
            } else { ContentUnavailableView("Entry removed", systemImage: "checkmark.circle") }
        }
    }
}

struct RepaymentView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    let debtID: UUID
    @State private var amount = ""
    @State private var date = Date()
    private var debt: Debt? { store.ledger.debts.first { $0.id == debtID } }
    private var valid: Bool { guard let value = Money.parse(amount), let debt else { return false }; return value <= debt.remaining }
    var body: some View {
        NavigationStack {
            Form {
                if let debt {
                    Section {
                        LabeledContent("Outstanding", value: store.money(debt.remaining))
                        TextField("Amount repaid", text: $amount).keyboardType(.decimalPad)
                        Button("Use full balance") { amount = Money.input(debt.remaining) }
                        DatePicker("Paid on", selection: $date, in: ...Date(), displayedComponents: .date)
                    } footer: { Text("Recording the full balance moves this entry to Settled. You can undo a repayment from its history.") }
                }
            }.navigationTitle("Record repayment").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        if let value = Money.parse(amount), store.repay(debtID, amount: value, date: date) { dismiss() }
                    }.bold().disabled(!valid) }
                }
                .alert("Couldn't save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}

struct BalanceAdjustmentView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    let debtID: UUID
    let mode: BalanceAdjustmentMode
    @State private var amount = ""
    @State private var date = Date()
    private var debt: Debt? { store.ledger.debts.first { $0.id == debtID } }
    private var valid: Bool {
        guard let value = Money.parse(amount), let debt else { return false }
        switch mode {
        case .add:
            return debt.amount <= Money.maximum - value
        case .subtract:
            return value <= debt.remaining
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                if let debt {
                    Section {
                        LabeledContent("Current amount", value: store.money(debt.remaining))
                        HStack {
                            Text(store.ledger.currency).foregroundStyle(.secondary)
                            TextField(mode.fieldTitle, text: $amount).keyboardType(.decimalPad)
                        }
                        if mode == .subtract {
                            Button("Use full balance") { amount = Money.input(debt.remaining) }
                            DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        }
                    } footer: { Text(mode.footer) }
                }
            }.navigationTitle(mode.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(mode.buttonTitle) {
                        guard let value = Money.parse(amount) else { return }
                        let saved = switch mode {
                        case .add: store.increaseAmount(debtID, by: value)
                        case .subtract: store.repay(debtID, amount: value, date: date)
                        }
                        if saved { dismiss() }
                    }.bold().disabled(!valid) }
                }
                .alert("Couldn't save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(ledger: Ledger) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(ledger)
    }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportDocument: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: Ledger?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Currency", selection: Binding(get: { store.ledger.currency }, set: { store.setCurrency($0) })) {
                        ForEach(Ledger.currencies, id: \.self) { Text($0).tag($0) }
                    }.disabled(!store.ledger.debts.isEmpty || store.recoveryRequired)
                } footer: { Text("One currency for your ledger. Choose it before adding entries; existing amounts are never converted or relabeled.") }
                Section("Your data") {
                    Button("Export backup", systemImage: "square.and.arrow.up") {
                        do { exportDocument = try BackupDocument(ledger: store.ledger); exporting = true } catch { self.error = error.localizedDescription }
                    }.disabled(store.recoveryRequired)
                    Button("Restore backup", systemImage: "square.and.arrow.down") { importing = true }
                }
                Section {
                    Label("Stored on your iPhone", systemImage: "iphone")
                    Label("No sign-up or bank connection", systemImage: "lock.shield")
                    Label("No automatic messages", systemImage: "bubble.left")
                } header: { Text("Small app. Clear boundaries.") } footer: {
                    Text("Between keeps a personal record of IOUs. Save backups somewhere safe: deleting the app removes its local data. Backups contain people's names, notes, and amounts and are not encrypted by the app.")
                }
                Section { Text("between · 1.0\nA little clarity between friends.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "Between-backup-\(Date().formatted(.iso8601.year().month().day()))") { result in
                    if case .failure(let failure) = result { error = failure.localizedDescription }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 20_000_000 else { throw LedgerError.invalidBackup }
                        pendingImport = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url)).validated()
                    } catch { self.error = error.localizedDescription }
                }
                .confirmationDialog("Replace your current ledger with \(pendingImport?.debts.count ?? 0) entries from this backup? Export your current data first if you want to keep it.", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                    Button("Replace ledger", role: .destructive) {
                        if let pendingImport { if !store.commit(pendingImport) { error = store.errorMessage; store.errorMessage = nil } }
                        pendingImport = nil
                    }
                }
                .alert("Something needs attention", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
}

struct BetweenPreview: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(LedgerStore(fileURL: URL.temporaryDirectory.appending(path: "between-preview.json")))
    }
}
