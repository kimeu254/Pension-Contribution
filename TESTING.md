# Manual Test Script

Step-by-step checks in the `bcsandbox` sandbox, following the acceptance criteria (AC) of each part of the brief.
Sign in to **CRONUS International Ltd.** and switch to the **Pension Administrator** role
(My Settings → Role).

> **Order matters.** Steps 0–1 create employer **EMP0001** and members **MEM00001–03**, which the sample
> files in `samples/` refer to. Do **not** run Generate Test Data, or create other employers or members,
> before step 2.

Legend: `[ ]` to do · `[x]` passed · note anything that does not match under the step.

---

## 0. Setup

1. **Chart of Accounts**: create three G/L accounts, each with Account Type = **Posting** and **Direct Posting** = Yes
   (the test data generator reuses these codes later).

   | No. | Name | Income/Balance |
   |---|---|---|
   | `PEN-RECV` | Contributions Receivable | Balance Sheet |
   | `PEN-LIAB` | Member Liability | Balance Sheet |
   | `PEN-PENALTY` | Late Penalty Income | Income Statement |

2. **Pension Setup**: check the values.
   - [x] Number series PEN-MEM, PEN-EMP, PEN-BATCH
   - [x] Remittance Due Day 9, Late Penalty % 5, Queue Batch Size 500, Max Retry Attempts 3
   - [x] Min. / Max. Joining Age 18 / 65

3. **Schemes**: add **DC01**, "Defined Contribution Scheme", Employer Cap % = **10**,
   Contribution Receivable = PEN-RECV, Member Liability = PEN-LIAB, Penalty Income = PEN-PENALTY, not blocked.
   - [x] A blank Description is rejected when leaving the row
   - [x] A G/L account that does not exist is rejected

## 1. Schemes, employers and members (Part 1)

**Employer** (New → Employer)
- [x] "Acme Ltd", scheme DC01, email `payroll@acme.co.ke` → gets **EMP0001**
- [x] KRA PIN `A12345` → rejected (format must be letter + 9 digits + letter)
- [x] KRA PIN `A123456789Z` → accepted
- [x] Email `not-an-email` → rejected

**Second employer** (for the rule tests)
- [x] "Beta Ltd", scheme DC01, KRA PIN `B123456789Z` → gets EMP0002
- [x] Changing Beta's KRA PIN to `A123456789Z` → rejected as a duplicate

**Members for Acme** (New → Member, Employer No. = EMP0001, unique National ID, date of birth around 1990,
Date Joined 01/01/2020)
- [x] MEM00001, Pensionable Salary 60,000
- [x] MEM00002, Pensionable Salary 45,000
- [x] MEM00003, Pensionable Salary 30,000
- [x] Scheme Code fills in as DC01 by itself and cannot be edited
- [x] Acme's **Member Count** shows 3

**Acceptance criteria**
- [x] **AC1**: set Beta Ltd to **Suspended** → a new member under EMP0002 is rejected. Set Beta back to Active.
- [x] **AC1**: block scheme DC01 → a new member under EMP0002 is rejected. Unblock DC01.
- [x] **AC2**: a new member with MEM00001's National ID → rejected as a duplicate
- [x] Age rule: a date of birth that makes the member 17 on Date Joined → rejected
- [x] Salary rule: Pensionable Salary 0 → rejected
- [x] **AC3** (Balance drills down to ledger entries) is checked in step 4, after posting

## 2. Receiving contributions (Part 2)

**Contribution Batches → Import File**, using the files in `samples/`:
- [x] **AC3**: `sample-batch.json` → accepted; **Lines** shows 3 lines, all **Pending**
- [x] **AC1**: `sample-batch.json` again → rejected: "…has already been received in batch …"
- [x] **AC2**: `bad-control-total.json` → rejected: "…line amounts add up to 27,000 but the control total is 26,000…"
- [x] Extra credit: `sample-batch.csv` → accepted, 3 Pending lines (period 2026-09, received on time)

## 3. Background processing (Part 3)

1. Set member **MEM00003** to Status **Exited**, so one line fails.
2. **Contribution Batches → Process Now**. Keep working; refresh after 30–60 seconds
   (the role center cues show the progress).

- [x] **AC1**: JSON batch: MEM00001 and MEM00002 **Posted**; MEM00003 **Failed**, Last Error
  "Member MEM00003 is not active…", Retry Count 1
- [x] CSV batch: all 3 lines **Posted**
- [x] **AC2**: **Process Now** 3 more times (refresh after each) → Retry Count 2, 3, then the line moves to
  **Dead Letter** on the 4th failure; the batch shows "Completed with Errors"
- [x] **AC3**: set MEM00003 back to **Active**; on **Contribution Queue** select the line → **Reprocess**
  → Pending, Retry Count 0; **Process Now** → **Posted**

## 4. Posting to the member ledger and General Ledger (Part 4)

Using the JSON batch:
- [x] **AC1**: **Reconcile** → "reconciles": member ledger total **27,000** = G/L credit to Member Liability
- [x] **Member Ledger Entries** (from the batch) → 6 entries, an Employee and an Employer entry per member
- [x] **AC2**: entries and **G/L Entries** carry the batch number as Document No.; the MEM00003 entries posted
  after Reprocess carry **batch no. + "-2"**
- [x] **AC3**: Penalty Posted ticked, Penalty Amount **1,350** (5% × 27,000); **G/L Entries** shows exactly one
  credit to PEN-PENALTY
- [x] The CSV batch has **no** penalty (received on time)
- [x] **Part 1 AC3**: member MEM00001 → Balance 24,000; choosing it opens the ledger entries

## 5. Member statement (Part 5)

- [x] MEM00001 card → **Member Statement**, 01/01/2026 – 31/12/2026: opening 0; 2026-09 row 6,000 / 6,000,
  balance 12,000; 2026-10 row 6,000 / 6,000, balance 24,000; totals 12,000 / 12,000; closing 24,000
- [x] **AC1**: same member, 01/10/2026 – 31/12/2026 → opening **12,000**, one 2026-10 row, closing 24,000
- [x] **AC2**: create a member under Beta Ltd with no contributions → statement page shows
  "No contributions in this period", opening = closing = 0
- [x] **Member List** → select 3 members → **Member Statement** → one page per member

## 6. Test data and tests (Part 6)

**Generator** (role center → Generate Test Data): period `2026-11`, 50 employers, 40 members each
- [x] Summary: 50 employers, 2,000 members, 50 batches, about 2,016 lines, about 50 deliberately bad lines.
  Time taken: ________
- [x] **Process Now** → when done, about 50 lines **Failed** with three kinds of error:
  "exceeds the cap", "is not active", "belongs to employer … not to employer …"
- [x] The batches of generated employers 10, 20, 30, 40, 50 have a penalty
- [x] **Reconcile** agrees on any generated batch

**Automated tests** (search **AL Test Tool** → Actions → Get Test Codeunits → Select Test Codeunits →
50140 PEN Contribution Tests → **Run All**)
- [x] `ValidLinePostsTwoMemberLedgerEntriesAndGLMatches`
- [x] `ResubmittedMessageIdIsRejectedAtIntake`
- [x] `OneInvalidLineFailsWhileTheOthersPost`
- [x] `LineThatKeepsFailingMovesToDeadLetter`
- [x] `LateBatchPostsOnePenalty`

---

## Results log

| Step | Result | Notes |
|---|---|---|
| 6 – Automated tests | 5 / 5 passed (2026-10-30) | First run: `ResubmittedMessageIdIsRejectedAtIntake` failed because `asserterror` rolled back the first batch; fixed with a `Commit()` before `asserterror` |
| 3 – Background processing | Passed (2026-10-30) | One Process Now handled all 2,020 lines in ~10 s; after 4 runs the 52 bad lines were Dead Letter (Retry Count 4, Max 3) and all 51 batches Completed with Errors |
| 3 – Recurring Job Queue | Passed (2026-10-30) | Schedule Background Processing created a recurring entry (every 1 min); generated period 2026-10 batches were processed with no manual action and no errors |
| 0 – Setup | Passed (2026-10-30) | Setup defaults, number series and scheme DC01 checks as expected |
| 1 – Master data | Passed (2026-10-30) | AC1 (suspended employer / blocked scheme), AC2 (duplicate National ID), KRA PIN, email, age and salary rules |
| 2 – Intake | Passed (2026-10-30) | AC1 duplicate message ID, AC2 control total mismatch, AC3 lines Pending; CSV import accepted |
| 4 – Posting | Passed (2026-10-30) | Reconcile agrees, 2 member ledger entries per line, Document No. traceability, one late penalty; Balance drill-down (Part 1 AC3) |
| 5 – Member statement | Passed (2026-10-30) | Opening + contributions = closing; member with no entries still gets a statement; one page per member |
| 6 – Generator | Passed (2026-10-30) | Bad lines fail with their own errors; late batches get a penalty; generated batches reconcile |
| | | |
