# Between

A native iPhone IOU tracker built with SwiftUI. Requires iOS 17 or later. No third-party packages, accounts, or server.

## Run on your iPhone

1. Open `Between.xcodeproj` in Xcode.
2. Select the **Between** target → **Signing & Capabilities**, choose your Apple development team, and change `com.example.between` to a unique bundle identifier.
3. Connect your iPhone, enable Developer Mode if prompted, and select it as the run destination.
4. Press **Run** (⌘R). Xcode may ask you to enable or trust development signing on your phone.

For a simulator, install an iOS 17+ simulator runtime in Xcode, choose an iPhone simulator, and press Run. No signing team is required for a simulator.

This is a source project, not an App Store download or a signed installable IPA. An Apple signing setup is needed to install it on a physical iPhone.

## Using Between

- In **Settings**, choose your currency before adding your first entry. Supported currencies: AUD, CAD, EUR, GBP, INR, NZD, USD.
- Tap **Add an entry**, select **They owe me** or **I owe them**, and enter the person's name and amount. Add a note and due date if useful.
- Select an existing name suggestion to keep entries together. Names differing only in capitalization or accents are grouped.
- Open a person, then an entry, to **Record a repayment**. Partial payments reduce the outstanding balance; full payments move the entry to Settled.
- Swipe a repayment left, or long-press it, to undo it. To correct an incorrectly entered debt, delete it and create a replacement.
- Search names and notes, or filter open, incoming, outgoing, and settled entries.
- Export a JSON backup from Settings to Files. Restoring a backup replaces the ledger only after confirmation; export your current data first if you want to keep it.

The dashboard shows both directions separately. Net balance is money owed to you minus money you owe. Repayments don't automatically offset separate debts. Due dates are labels inside the app; they don't trigger notifications.

## Data and implementation

- `Models.swift`: exact integer minor-unit accounting, currency parsing, balance calculations, and backup validation.
- `LedgerStore.swift`: local JSON storage, atomic writes, repayments, and recovery.
- `BetweenApp.swift`: SwiftUI screens and backup import/export.
- Saved data lives in the app's Application Support directory and uses iOS complete file protection. The app has no network code or analytics.
- Backups are plaintext JSON. Protect exported copies; they contain names, notes, and amounts. Deleting the app removes local data. There is no cross-device sync.
- Currency is fixed while entries exist to avoid changing the meaning of recorded amounts. No currency conversion is performed.

## App Preview

## A look inside

<table>
  <tr>
    <td align="center" width="50%">
      <h3>Your overview</h3>
      <img width="220" alt="Home screen showing your balances" src="https://github.com/user-attachments/assets/1855b837-9b5d-4514-b13f-0cf0b307910f" />
      <p>See what you owe and what you’re owed at a glance.</p>
    </td>
    <td align="center" width="50%">
      <h3>Add an entry</h3>
      <img width="220" alt="Create a new entry" src="https://github.com/user-attachments/assets/a2d1fffb-aebe-4f2f-bc19-76281c2d64a1" />
      <p>Add an amount, a description, and an optional due date.</p>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <h3>Keep track by person</h3>
      <img width="220" alt="Open entries for a person" src="https://github.com/user-attachments/assets/54f34444-5663-4c1f-be0a-854876bdcafe" />
      <p>View your twin's balance and open entries.</p>
    </td>
    <td align="center" width="50%">
      <h3>Manage an entry</h3>
      <img width="220" alt="Entry details and payment actions" src="https://github.com/user-attachments/assets/03c6d8ca-5a1b-42d0-8f1a-503b63164be7" />
      <p>Adjust amounts, record repayments, or mark an entry as settled.</p>
    </td>
  </tr>
</table>

<details>
  <summary><strong>More features — repayment history, settled entries, and data backup</strong></summary>
  <br />

  <table>
    <tr>
      <td align="center" width="50%">
        <h3>Repayment history</h3>
        <img width="220" alt="Repayment history for an entry" src="https://github.com/user-attachments/assets/d3578279-69ca-4bd7-b1ee-59ad6b162ec8" />
        <p>Follow repayments from the entry’s detail page.</p>
      </td>
      <td align="center" width="50%">
        <h3>All settled</h3>
        <img width="220" alt="Settled entries" src="https://github.com/user-attachments/assets/520b3161-ff02-48a3-8612-3dc56bf28e0b" />
        <p>Look back at entries you’ve already settled.</p>
      </td>
    </tr>
    <tr>
      <td align="center" colspan="2">
        <h3>Your data, with you</h3>
        <img width="220" alt="App menu and data options" src="https://github.com/user-attachments/assets/a55a9538-7402-48e0-b75d-403c71614f4e" />
        &nbsp;&nbsp;
        <img width="220" alt="Import and export options" src="https://github.com/user-attachments/assets/24274cbb-46da-441b-bf6e-47bf389e2ada" />
        <p>Import or export your data from the menu at the top right of the home screen.</p>
      </td>
    </tr>
  </table>
</details>



## Verification


An unsigned build for the generic iOS device destination succeeded with Xcode 26.6. The simulator was unavailable in the build environment, so interactive device and visual QA remain to be done.

The included checks cover precision, localized decimals, invalid amounts, repayment limits, settlement, undo, overdue state, per-direction totals, persistence, currency locking, invalid backup rejection, and corrupt-file recovery.

Run the 37 checks on macOS from this directory:

```sh
swiftc Between/Models.swift Between/LedgerStore.swift Tests/LedgerChecks.swift -o /tmp/between-checks
/tmp/between-checks
```

Build without signing:

```sh
xcodebuild -project Between.xcodeproj -scheme Between -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```
