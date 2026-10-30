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
   - [ ] Number series PEN-MEM, PEN-EMP, PEN-BATCH
   - [ ] Remittance Due Day 9, Late Penalty % 5, Queue Batch Size 500, Max Retry Attempts 3
   - [ ] Min. / Max. Joining Age 18 / 65

3. **Schemes**: add **DC01**, "Defined Contribution Scheme", Employer Cap % = **10**,
   Contribution Receivable = PEN-RECV, Member Liability = PEN-LIAB, Penalty Income = PEN-PENALTY, not blocked.
   - [ ] A blank Description is rejected when leaving the row
   - [ ] A G/L account that does not exist is rejected

## 1. Schemes, employers and members (Part 1)

**Employer** (New → Employer)
- [ ] "Acme Ltd", scheme DC01, email `payroll@acme.co.ke` → gets **EMP0001**
- [ ] KRA PIN `A12345` → rejected (format must be letter + 9 digits + letter)
- [ ] KRA PIN `A123456789Z` → accepted
- [ ] Email `not-an-email` → rejected

**Second employer** (for the rule tests)
- [ ] "Beta Ltd", scheme DC01, KRA PIN `B123456789Z` → gets EMP0002
- [ ] Changing Beta's KRA PIN to `A123456789Z` → rejected as a duplicate

**Members for Acme** (New → Member, Employer No. = EMP0001, unique National ID, date of birth around 1990,
Date Joined 01/01/2020)
- [ ] MEM00001, Pensionable Salary 60,000
- [ ] MEM00002, Pensionable Salary 45,000
- [ ] MEM00003, Pensionable Salary 30,000
- [ ] Scheme Code fills in as DC01 by itself and cannot be edited
- [ ] Acme's **Member Count** shows 3

**Acceptance criteria**
- [ ] **AC1**: set Beta Ltd to **Suspended** → a new member under EMP0002 is rejected. Set Beta back to Active.
- [ ] **AC1**: block scheme DC01 → a new member under EMP0002 is rejected. Unblock DC01.
- [ ] **AC2**: a new member with MEM00001's National ID → rejected as a duplicate
- [ ] Age rule: a date of birth that makes the member 17 on Date Joined → rejected
- [ ] Salary rule: Pensionable Salary 0 → rejected
- [ ] **AC3** (Balance drills down to ledger entries) is checked in step 4, after posting

## 2. Receiving contributions (Part 2)

**Contribution Batches → Import File**, using the files in `samples/`:
- [ ] **AC3**: `sample-batch.json` → accepted; **Lines** shows 3 lines, all **Pending**
- [ ] **AC1**: `sample-batch.json` again → rejected: "…has already been received in batch …"
- [ ] **AC2**: `bad-control-total.json` → rejected: "…line amounts add up to 27,000 but the control total is 26,000…"
- [ ] Extra credit: `sample-batch.csv` → accepted, 3 Pending lines (period 2026-09, received on time)

## 3. Background processing (Part 3)

1. Set member **MEM00003** to Status **Exited**, so one line fails.
2. **Contribution Batches → Process Now**. Keep working; refresh after 30–60 seconds
   (the role center cues show the progress).

- [ ] **AC1**: JSON batch: MEM00001 and MEM00002 **Posted**; MEM00003 **Failed**, Last Error
  "Member MEM00003 is not active…", Retry Count 1
- [ ] CSV batch: all 3 lines **Posted**
- [ ] **AC2**: **Process Now** 3 more times (refresh after each) → Retry Count 2, 3, then the line moves to
  **Dead Letter** on the 4th failure; the batch shows "Completed with Errors"
- [ ] **AC3**: set MEM00003 back to **Active**; on **Contribution Queue** select the line → **Reprocess**
  → Pending, Retry Count 0; **Process Now** → **Posted**

## 4. Posting to the member ledger and General Ledger (Part 4)

Using the JSON batch:
- [ ] **AC1**: **Reconcile** → "reconciles": member ledger total **27,000** = G/L credit to Member Liability
- [ ] **Member Ledger Entries** (from the batch) → 6 entries, an Employee and an Employer entry per member
- [ ] **AC2**: entries and **G/L Entries** carry the batch number as Document No.; the MEM00003 entries posted
  after Reprocess carry **batch no. + "-2"**
- [ ] **AC3**: Penalty Posted ticked, Penalty Amount **1,350** (5% × 27,000); **G/L Entries** shows exactly one
  credit to PEN-PENALTY
- [ ] The CSV batch has **no** penalty (received on time)
- [ ] **Part 1 AC3**: member MEM00001 → Balance 24,000; choosing it opens the ledger entries

## 5. Member statement (Part 5)

- [ ] MEM00001 card → **Member Statement**, 01/01/2026 – 31/12/2026: opening 0; 2026-09 row 6,000 / 6,000,
  balance 12,000; 2026-10 row 6,000 / 6,000, balance 24,000; totals 12,000 / 12,000; closing 24,000
- [ ] **AC1**: same member, 01/10/2026 – 31/12/2026 → opening **12,000**, one 2026-10 row, closing 24,000
- [ ] **AC2**: create a member under Beta Ltd with no contributions → statement page shows
  "No contributions in this period", opening = closing = 0
- [ ] **Member List** → select 3 members → **Member Statement** → one page per member

## 6. Test data and tests (Part 6)

**Generator** (role center → Generate Test Data): period `2026-11`, 50 employers, 40 members each
- [ ] Summary: 50 employers, 2,000 members, 50 batches, about 2,016 lines, about 50 deliberately bad lines.
  Time taken: ________
- [ ] **Process Now** → when done, about 50 lines **Failed** with three kinds of error:
  "exceeds the cap", "is not active", "belongs to employer … not to employer …"
- [ ] The batches of generated employers 10, 20, 30, 40, 50 have a penalty
- [ ] **Reconcile** agrees on any generated batch

**Automated tests** (search **AL Test Tool** → Actions → Get Test Codeunits → Select Test Codeunits →
50140 PEN Contribution Tests → **Run All**)
- [ ] `ValidLinePostsTwoMemberLedgerEntriesAndGLMatches`
- [ ] `ResubmittedMessageIdIsRejectedAtIntake`
- [ ] `OneInvalidLineFailsWhileTheOthersPost`
- [ ] `LineThatKeepsFailingMovesToDeadLetter`
- [ ] `LateBatchPostsOnePenalty`

---

## Results log

| Step | Result | Notes |
|---|---|---|
| | | |
