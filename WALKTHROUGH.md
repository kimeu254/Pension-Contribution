# Walkthrough Notes (30 minutes)

Presenter notes: what to show, in what order, what to say, and the questions to expect.
Timings add up to 30 minutes; keep about 8 of them for questions.

---

## Before the call (10 minutes)

- [ ] Sandbox running, signed in to **CRONUS International Ltd.**, role **Pension Administrator**.
- [ ] Latest app and test app published.
- [ ] Recurring job queue entry **On Hold** (so it does not process the demo batch before you click Process Now).
- [ ] Members **MEM00001–MEM00003** are **Active**.
- [ ] `samples/demo-batch.json` ready: EMP0001, period 2026-12, received 2027-01-12 (late), 27,000.
  Never loaded before, so it is accepted live.
- [ ] `samples/demo-batch.csv` ready: the same members, period 2027-01, received 2027-02-05 (on time, due 9 Feb),
  27,000. Shows the CSV route and a batch with **no** penalty.
- [ ] VS Code open on `Pension Contribution.code-workspace` with these tabs, in this order:
  1. `app/src/Intake/PENContributionIntake.Codeunit.al`
  2. `app/src/Processing/PENQueueProcessor.Codeunit.al`
  3. `app/src/Processing/PENLineValidation.Codeunit.al`
  4. `app/src/Posting/PENContributionPosting.Codeunit.al`
  5. `test/src/PENContributionTests.Codeunit.al`
- [ ] README open in the browser or VS Code preview, at section 4 (double processing).

---

## 1. Introduction (2 min)

Say:
- "A Business Central extension for the full contribution cycle: onboarding, receiving files, background
  processing, posting to a member ledger and the G/L, and the member statement."
- "Three principles: every route goes through one codeunit; intake is fast and only checks structure, business rules
  run in the background; one bad line never stops the others, and nothing can be posted twice."
- Show the **role center**: cues for queue status, open batches, batches with errors; navigation by area.

## 2. Master data and rules (3 min) — Part 1

Show:
1. **Schemes**: Employer Cap %, the three G/L accounts.
2. **Employer card**: number series, KRA PIN format (type `A12345` → error), Member Count.
3. **Member card**: Scheme Code fills from the employer and is not editable.
   Try a 17-year-old (Date of Birth) → error. Mention suspended employer / blocked scheme / duplicate National ID.

Say:
- "Rules are enforced on validate **and** on insert, so the generator, tests and any future API cannot bypass them."
- "Uniqueness has a clear message and a `Unique` key behind it, for two users saving at the same time."
- "The 18–65 limits are in Pension Setup, not hard-coded: my additional fields."

## 3. Intake (4 min) — Part 2

Show:
1. **Contribution Batches → Import File** → `demo-batch.json` → message: batch received, 3 lines Pending.
2. **Lines** → 3 Pending lines.
3. Import `demo-batch.json` **again** → "already been received in batch …" (AC1).
4. Import `bad-control-total.json` → "line amounts add up to 27,000 but the control total is 26,000" (AC2).
5. Import `demo-batch.csv` → accepted, 3 Pending lines (extra credit: CSV). Columns are found by heading name, and
   the batch details must be identical on every row.

Code (`PENContributionIntake.Codeunit.al`):
- `ImportStream` picks the reader by extension; readers only build **temporary** records.
- `CreateBatch` is the single entry point: header checks → message ID → lines → control total → insert.
  Any error rolls back everything: no half-loaded batch.

## 4. Background processing (6 min) — Part 3

Show:
1. Set **MEM00003** to **Exited** (to show a failure).
2. **Process Now** → keep clicking around (members, statement) to show the UI is not blocked → refresh.
3. MEM00001/02 **Posted**; MEM00003 **Failed**, error text and Retry Count 1 (AC1).
4. **Queue Monitor**: counts by status, last run start/end/duration, most common errors.
5. Explain retries: next runs → 2, 3, then Dead Letter on the 4th failure (AC2). Set MEM00003 Active,
   **Reprocess** → Pending → Process Now → Posted (AC3). (If short on time, show an existing Dead Letter line from
   the generated data and Reprocess it.)

Code (`PENQueueProcessor.Codeunit.al`), walk through `ProcessQueue`:
1. `ReleaseStaleClaims` — crashed runs do not strand lines.
2. `RequeueFailedLines` — Failed → Pending (retry on the next run).
3. Loop `ClaimNextChunk` → `ProcessChunk` → `UpdateBatchStatus` → `Commit`.
- `ClaimNextChunk`: `ReadIsolation := UpdLock`, re-check status under the lock, stamp Claim ID, **commit**.
- `ProcessChunk`: validate every line in a `TryFunction` → failures saved and committed → valid lines posted
  together via `Codeunit.Run`, so a posting error rolls back only that chunk.
- `MarkLineFailed`: Retry Count + 1, Dead Letter when it exceeds Max Retry Attempts.

## 5. Posting and reconciliation (5 min) — Part 4

Show (on the demo batch):
1. **Reconcile** → member ledger 21,000 (or 27,000 after MEM00003) = G/L credit to Member Liability (AC1).
2. **Member Ledger Entries** → two per line, Employee and Employer, Batch No. and Document No. (AC2).
3. **G/L Entries** → one summarised pair (not one per member) + **one** penalty: 5% × 27,000 = 1,350,
   description "Late remittance penalty EMP0001 2026-12" (AC3). Due 9 Jan 2027, received 12 Jan → late.
4. If MEM00003 was reprocessed: its entries have document no. `…-2`.
5. The CSV demo batch (period 2027-01, received on time): Reconcile agrees, Penalty Posted is **not** ticked.

Code (`PENContributionPosting.Codeunit.al`), `PostLines`:
- Locks the batch (document number + penalty flag), re-reads each line under lock (must still carry this Claim ID),
  locks the member and repeats the already-posted check.
- Two member ledger entries per line; totals per scheme in a `Dictionary`; one `Gen. Journal Line` per scheme
  through `Gen. Jnl.-Post Line.RunWithCheck`; penalty once (flag on the batch).

## 6. Member statement (2 min) — Part 5

Show:
1. MEM00001 card → **Member Statement**, 01/01/2026 – 31/12/2026: opening, rows per period, running balance, totals,
   closing.
2. Same member from 01/10/2026: opening balance is no longer 0 (AC1).
3. A member with no contributions still gets a page (AC2).

Say: "Opening and closing come from the Balance FlowField independently of the rows, so opening + contributions =
closing is a real check."

## 7. Test data, tests, extensibility (3 min) — Part 6

Show:
1. **Generate Test Data** dialog (do not run it live; mention ~2,000 lines, ~50 bad lines in three kinds,
   every 10th batch late, re-runnable per period).
2. **AL Test Tool** → Run All → 5 passing tests. Open one test in VS Code: Given / When / Then, own data,
   `SetBatchFilter` so it only processes its own batch.
3. Integration events: `OnBeforeValidateQueueLine` (IsHandled), `OnAfterValidateQueueLine`, `OnAfterQueueLinePosted`,
   `OnBeforePostGenJournalLine`, `OnAfterCreateBatch`.

## 8. Wrap-up (1 min)

- Not finished: telemetry, performance timings at 20,000 lines, API page (two-call design), parallel demo
  (README section 8).
- "With more time: telemetry first, then the API page using the same `CreateBatch`."

---

## Likely questions

**How do you stop two Job Queue entries processing the same line?**
Claiming is a separate committed transaction with an update lock: a line is only claimed if it is still Pending under
the lock, and is stamped with a Claim ID. Each run only touches its own Claim ID. Posting re-checks the claim under
lock and repeats the already-posted check with the member locked. Crashed runs are released after their session ends.
(README section 4.)

**Why a `TryFunction` for validation and not `Codeunit.Run` per line?**
Validation only reads, which is what TryFunctions are safe for, and it avoids a commit per line: `Codeunit.Run`
with a return value cannot be called inside a write transaction, so one per line would mean committing every line.
Posting, which writes, does run in `Codeunit.Run`, once per chunk.

**Why commit per chunk and not per line or per batch?**
Per line is slow (thousands of commits) and holds no benefit; per batch could lock thousands of rows for a long
time and block users. Queue Batch Size (500) is the balance, and it is configurable.

**What happens if G/L posting fails half way?**
The whole chunk rolls back: member ledger entries, line statuses and G/L. Every line in the chunk is marked Failed
with the posting error and retried. Validation failures were committed before posting, so they are not lost.

**Why is the member ledger Entry No. safe with two processes posting?**
`AutoIncrement`: SQL Server assigns it as an identity column, so no `FindLast + 1` race.

**Why post one G/L pair per scheme and not per member?**
The brief asks for summarised G/L; the member ledger carries the detail, and the Reconcile action proves both agree.

**Why is the penalty based on the control total?**
It is what the employer declared and remitted late; it does not change if some lines later fail. Recorded as a
decision in the README.

**How do you know the statement is right?**
Opening and closing are calculated independently of the rows from the Balance FlowField; the totals must add up.

**Why a separate test app?**
Test code must not ship in the production extension, and the AL compiler includes every `.al` file under a project
folder, so tests live in their own app that depends on the main one.

**Why did one test need a `Commit()`?**
`asserterror` rolls back the whole open transaction, including the first batch the test created. Committing first
keeps it; the test runner's isolation still rolls everything back at the end.

**How would you build the API page?**
Two calls: POST the request with lines (deep insert into staging tables), then a bound `submit` action that calls the
same `CreateBatch`. BC runs no code after the last line of a deep insert, so one call cannot know the batch is
complete.

**How would you make it faster for 20,000 lines?**
Already: `SetLoadFields`, keys that match the filters, employer and scheme read once per chunk. Next: cache members
in a Dictionary per chunk, measure with telemetry per chunk, tune Queue Batch Size, and run two job queue entries
in parallel (the claiming design already allows it).
