# PEN Pension Contributions

A Business Central extension that runs the core contribution cycle of an occupational pension scheme:
employers and members are onboarded, monthly contribution files are received and checked, processed in the
background by the Job Queue, posted to a member ledger and the General Ledger, and reported on a member statement.

Built for Business Central 2026 release wave 2 (application 29, runtime 18), object IDs 50100–50149, prefix `PEN`.

| | |
|---|---|
| Extension | `app/` → *Pension Contribution* (`JIMMY MUTISO_Pension Contribution_<version>.app`) |
| Tests | `test/` → *Pension Contribution Tests* (separate app, IDs 50140–50149) |
| Design log | [DESIGN.md](DESIGN.md): build plan, object ID plan and every design decision |
| Test evidence | [TESTING.md](TESTING.md): manual test script per acceptance criterion, with results |

---

## Contents

1. [Getting started](#1-getting-started)
2. [How it works](#2-how-it-works)
3. [Design decisions](#3-design-decisions)
4. [How double processing is prevented](#4-how-double-processing-is-prevented)
5. [How the member ledger and General Ledger were verified to reconcile](#5-how-the-member-ledger-and-general-ledger-were-verified-to-reconcile)
6. [Additional fields and objects](#6-additional-fields-and-objects)
7. [Tests](#7-tests)
8. [What is not finished](#8-what-is-not-finished)
9. [Repository layout](#9-repository-layout)

---

## 1. Getting started

1. Open `Pension Contribution.code-workspace` in VS Code (AL Language extension), download symbols, and publish
   **app** first, then **test**.
2. Assign the permission set **PEN ALL** ("Pension - All") to the users who will work with the extension.
3. Switch to the **Pension Administrator** role (My Settings → Role). Everything below is reachable from it.
4. **Pension Setup** is created on install with defaults and three number series
   (`PEN-MEM` MEM00001, `PEN-EMP` EMP0001, `PEN-BATCH` PCB000001).
5. Create a **Scheme** with three posting G/L accounts that allow direct posting
   (Contribution Receivable, Member Liability, Penalty Income) and an Employer Cap %.
6. **Pension Setup → Schedule Background Processing** creates a recurring Job Queue entry that processes the
   queue every minute. **Process Now** (Contribution Batches, Contribution Queue, Queue Monitor) starts a one-off
   background run.
7. Either create employers and members by hand and import the files in `samples/`, or use
   **Generate Test Data** (1 scheme, 50 employers, 2,000 members, one batch per employer).

---

## 2. How it works

```
 Import File (JSON / CSV) ─┐
 Generate Test Data ───────┼──► PEN Contribution Intake.CreateBatch  ──► Batch + queue lines (Pending)
 Tests ────────────────────┘      structural checks only, all or nothing

 Job Queue ──► PEN Queue Processor
                 1. release lines left in Processing by a crashed run
                 2. Failed lines → Pending (retry)
                 3. repeat until nothing is Pending:
                      claim up to Queue Batch Size lines of one batch → Processing   (commit)
                      validate each line on its own (TryFunction) → Failed + error text, or valid
                      post the valid lines: 2 member ledger entries per line,
                        one G/L pair per scheme, late penalty once per batch            (commit)

 PEN Member Ledger Entry ──► Balance (FlowField), Member Statement report
```

| Part of the brief | Where |
|---|---|
| 1. Schemes, employers, members | `app/src/MasterData`, `app/src/Setup` |
| 2. Receiving contributions | `app/src/Intake`: Contribution Batches page → **Import File** (JSON and CSV) |
| 3. Background processing | `app/src/Processing`: Queue Processor (Job Queue), Line Validation, Reprocess |
| 4. Posting | `app/src/Posting`: Member Ledger Entry, Contribution Posting (Gen. Jnl.-Post Line) |
| 5. Member statement | `app/src/Statement`: RDLC report, run from Member Card and Member List |
| 6. Test data, tests, events | `app/src/TestData`, `test/` |
| Role center, Queue Monitor | `app/src/RoleCenter`, `app/src/Processing` |

**Every route uses the same code.** File upload, the generator and the tests all create batches through
`PEN Contribution Intake.CreateBatch`; the readers only turn a file into temporary records. Validation lives in one
codeunit (`PEN Line Validation`) and posting in one (`PEN Contribution Posting`).

**Integration events** for other extensions:

| Event | Publisher | When |
|---|---|---|
| `OnAfterCreateBatch` | PEN Contribution Intake | a batch has been accepted at intake |
| `OnBeforeValidateQueueLine` (with `IsHandled`) | PEN Line Validation | before a line's business validation |
| `OnAfterValidateQueueLine` | PEN Line Validation | after a line passed validation; raise an error to reject it |
| `OnAfterQueueLinePosted` | PEN Contribution Posting | a line has been posted to the member ledger |
| `OnBeforePostGenJournalLine` | PEN Contribution Posting | before a summary or penalty journal line is posted, e.g. to add dimensions |

---

## 3. Design decisions

Where the brief is silent, these are the decisions made. The complete list is in
[DESIGN.md §4](DESIGN.md#4-decisions-where-the-brief-is-silent-to-record-in-readme).

### Master data
- **Required fields** are enforced three ways: `NotBlank` stops a field being cleared, `OnInsert`/`OnModify`
  checks catch records created from code (generator, tests), and the Employer and Member cards use `DelayedInsert`,
  so a record is only saved once it is filled in.
- **KRA PIN and National ID uniqueness** is checked when the field is entered (clear message) and backed by a
  `Unique` key, so two users saving at the same moment cannot both succeed.
- **Suspended employer / blocked scheme** is checked when the member's employer is entered *and* again on insert,
  so no route can bypass it.
- **Date of Birth is required**, because the 18–65 rule cannot be enforced without it. Age is calculated on the
  Date Joined, inclusive.
- **Consistency rules**: an employer's scheme cannot change once it has members; a member's employer cannot change
  once they have ledger entries; schemes, employers and members still in use cannot be deleted.
- **Scheme G/L accounts** must be posting accounts, not blocked, with Direct Posting (required by
  Gen. Jnl.-Post Line).

### Intake
- **Control total** = Σ (employee amount + employer amount) over all lines.
- **All or nothing**: a batch that fails any check is not created at all; nothing is half-loaded.
- **Structural checks only**: message ID, employer no., period (`YYYY-MM`), received date present; values fit their
  fields; amounts are numbers and not negative; at least one line; in CSV, the batch columns are identical on every
  row. Whether the member or employer exists is business validation and happens in the background.
- **Culture-independent parsing**: amounts use a decimal point and dates `YYYY-MM-DD` whatever the user's language.
- **CSV columns are found by heading name**, so column order does not matter.

### Background processing
- **Chunks**: a chunk is up to *Queue Batch Size* lines of **one** batch, committed on its own. A chunk never mixes
  batches, so each G/L summary and each penalty belongs to exactly one batch.
- **One bad line never stops the others**: each line is validated in a `TryFunction`; failures are stored on the line
  (error text, retry count, time) and committed before the valid lines are posted.
- **Retries**: "failed more than Max Retry Attempts" is taken literally. With Max = 3 a line is tried 4 times
  (first attempt + 3 retries); the 4th failure moves it to **Dead Letter**. Failed lines are retried at the start
  of the **next** run, so the job queue interval acts as the retry delay. Dead Letter lines are only picked up
  again after **Reprocess**, which resets the retry count to 0.
- **A posting error** (e.g. a closed posting period) rolls back the whole chunk; every line in it gets that error
  and is retried.
- **Validation order**: employer and scheme first (read once per chunk), then member, already-posted, cap. The first
  rule that fails is the message stored.
- **Employer Cap % of 0** is treated as "not set up": lines fail with a clear message instead of going uncapped.
- **The same member twice in one file**: the second line fails; earlier batches are covered by the
  already-posted check.

### Posting
- **Posting date** of contributions is the last day of the contribution period.
- **G/L**: one summarised pair per scheme per chunk, Dr Contribution Receivable / Cr Member Liability, through
  `Gen. Journal Line` and `Gen. Jnl.-Post Line`. With batch size 500 and ~40 lines per employer this is one pair
  per batch. Accounts are assigned rather than validated on the journal line, so no VAT or posting groups are
  pulled in: these are balance sheet transfers.
- **Document numbers**: the first posting of a batch uses the batch number (e.g. `PCB000051`); postings of lines
  that succeed on a later retry use `PCB000051-2`, `-3`… The member ledger entries carry the same number, and the
  filter `PCB000051|PCB000051-*` finds every posting of a batch. External Document No. = the message ID.
- **Late penalty**: due date = Remittance Due Day of the month after the period (a due day past the month's end
  falls on its last day). If the batch was received after it, Late Penalty % of the **control total** is posted
  once, with the first posting of the batch, Dr Contribution Receivable / Cr Penalty Income, on the **received
  date**, description "Late remittance penalty EMP0001 2026-10". A flag on the batch guarantees it is posted only
  once. The default Late Penalty % is 5 (the brief gives no value).
- **Every line creates both member ledger entries**, as specified, even when one amount is 0.

### Member statement
- One row per **contribution period** with employee and employer side by side, a running balance, totals and
  closing balance; one page per member.
- Opening and closing balances are read from the Balance FlowField **independently** of the rows, so
  "opening + contributions = closing" is a real cross-check, not true by construction.
- A member with no entries in the range still gets a page: header, "No contributions in this period",
  opening = closing.

---

## 4. How double processing is prevented

The risk is two Job Queue entries, or a crashed run and a new one, processing the same line. Four layers stop it:

1. **Claiming is its own short, committed transaction.** A run reads Pending lines with an update lock
   (`ReadIsolation := UpdLock`), re-reads each line under the lock, and only claims it if it is *still* Pending:
   status → Processing, stamped with a new **Claim ID** (a GUID per chunk), the session ID and the time. Then it
   commits. A second run that reads at the same moment waits on the lock, and when it gets the rows they are no
   longer Pending, so it claims different lines.
2. **A run only touches lines carrying its own Claim ID.** Processing and posting filter on it.
3. **Posting re-checks under lock.** Before posting, each line is re-read with an update lock and refused unless it
   is still Processing with this run's Claim ID. The batch row is locked (document number sequence and penalty
   flag), and the member row is locked while the "already posted for this member and period" check is repeated,
   so the same member and period cannot be posted twice, even from two different batches.
4. **Crashed runs do not strand lines.** At the start of every run, lines still in Processing whose session has
   ended, or that were claimed more than an hour ago, go back to Pending.

At intake, the **message ID** is checked with a clear message and backed by a `Unique` key, so the same file cannot
be loaded twice, even by two users uploading at once. Member ledger **Entry No.** is an `AutoIncrement` (SQL
identity) column, so it stays unique when two processes post at the same time.

---

## 5. How the member ledger and General Ledger were verified to reconcile

- **Reconcile action** on Contribution Batches compares, for the selected batch, Σ member ledger `Amount` with the
  credit to the scheme's Member Liability account over all of the batch's document numbers, and reports any
  difference. **Member Ledger Entries** and **G/L Entries** actions open both sides for the batch.
- **Automated test** `ValidLinePostsTwoMemberLedgerEntriesAndGLMatches` posts a line and asserts: two member ledger
  entries (5,000 + 5,000), member ledger total 10,000 = G/L credit to Member Liability 10,000, in exactly one
  summarised G/L entry. `LateBatchPostsOnePenalty` asserts exactly one penalty entry of −1,350 on Penalty Income
  for the brief's sample batch, even when processed twice.
- **In the sandbox** (CRONUS, details in [TESTING.md](TESTING.md)):
  - the brief's sample batch: member ledger 27,000 = G/L Member Liability credit 27,000, including a line that only
    posted after Reprocess (document no. `-2`); one late penalty of 1,350;
  - the generated data: 2,020 lines processed in one background run of about 10 seconds; 1,968 posted
    (3,936 member ledger entries), 52 deliberately bad lines failed with their own errors and moved to Dead Letter
    after 4 attempts; Reconcile agreed on the generated batches checked.

---

## 6. Additional fields and objects

The brief allows extra fields when the design needs them. These were added:

| Table | Field | Why |
|---|---|---|
| PEN Pension Setup | Min. Joining Age (default 18) | The 18–65 rule is held in setup instead of hard-coded, so a change in scheme rules (e.g. retirement age) needs no code change and redeploy. |
| PEN Pension Setup | Max. Joining Age (default 65) | As above. A minimum above the maximum is rejected. |
| PEN Employer, PEN Member | No. Series | Standard BC number series pattern: remembers which series a record came from and supports the Assist Edit button. |
| PEN Member | Date Filter (FlowFilter) | Lets the Balance FlowField be calculated up to a date, for the statement's opening and closing balances. |

The brief left the batch and queue design open. Beyond the required fields:

| Table | Fields | Why |
|---|---|---|
| PEN Contribution Batch | Message ID (unique), Employer No., Period, Received Date, Control Total, Status, Source, File Name, Created By / At | What was received and from where; Received Date drives the late penalty. |
| | Penalty Posted, Penalty Amount, Penalty Document No., No. of Postings | Penalty once per batch; document number sequence for retried postings. |
| | FlowFields: No. of Lines, totals, lines per status, Member Ledger Amount | Progress at a glance and drill-down to the lines. |
| PEN Contribution Queue | Batch No., Line No., Employer No., Member No., Period, the two amounts, Status, Retry Count, Last Error | The minimum from the brief, plus traceability to the file line. |
| | Last Attempt At, Claim ID, Claimed By Session, Claimed At, Posted Document No. | Retry history, safe claiming (section 4) and traceability to the posting. |

Additional objects, beyond what the brief lists: the **Pension Administrator** role center and profile with
Activities cues (table *PEN Pension Cue*), the **Queue Monitor** page (lines by status, last and next run, most
common errors), the **Generate Test Data** dialog, and the **PEN ALL** permission set.

---

## 7. Tests

The test app `test/` contains `PEN Contribution Tests` (codeunit 50140) and a helper `PEN Test Library` (50141).
Each test creates its own scheme, G/L accounts, employer and members with unique keys and processes **only its own
batch** (`PEN Queue Processor.SetBatchFilter`), so it does not depend on the generator or on other data in the
company.

| Test | Brief scenario |
|---|---|
| `ValidLinePostsTwoMemberLedgerEntriesAndGLMatches` | 1. A valid line posts two member ledger entries and the GL totals match |
| `ResubmittedMessageIdIsRejectedAtIntake` | 2. A resubmitted batch with the same message ID is rejected |
| `OneInvalidLineFailsWhileTheOthersPost` | 3. One invalid line fails while the others post |
| `LineThatKeepsFailingMovesToDeadLetter` | 4. A line that keeps failing moves to Dead Letter (and Reprocess brings it back) |
| `LateBatchPostsOnePenalty` | Extra: the brief's late sample batch posts exactly one penalty of 1,350 |

All five pass in the sandbox (AL Test Tool → Get Test Codeunits → 50140 → Run All).

---

## 8. What is not finished

Of the optional stretch goals, only the **queue monitor page** was built. Not done:

| Stretch goal | Status |
|---|---|
| Telemetry with `Session.LogMessage` | Not started. Planned: one event per run and per chunk with line counts and durations, and one per accepted batch. |
| Performance at 20,000 lines with before / after timings | Not measured. Already in place: `SetLoadFields`, keys that match the processor's filters, employer and scheme read once per chunk, 500-line transactions. Baseline: 2,020 lines in about 10 seconds. |
| API page intake | Not built. Designed as two calls: POST the request with its lines (deep insert into staging tables), then a bound `submit` action that calls the same `CreateBatch`. BC runs no code after the last line of a deep insert, so a single call cannot know when a batch is complete. |
| Parallel processing by two Job Queue entries, demonstrated | Supported by the design (section 4) but not demonstrated with two entries running at once. |

Known limitations:
- Batch numbers longer than 17 characters would leave no room for the `-2` retry suffix in the 20-character
  document number; the default series (`PCB000001`) is 9 characters.
- The penalty is a percentage of the declared control total, even if some lines later end in Dead Letter.
- Tested on a local Business Central 29 container (CRONUS), not on a SaaS sandbox.

---

## 9. Repository layout

```
Pension Contribution/
├─ app/                      the extension
│  └─ src/
│     ├─ Setup/              Pension Setup, Install codeunit, PEN ALL permission set
│     ├─ MasterData/         Scheme, Employer, Member
│     ├─ Intake/             Contribution Batch + Queue, intake codeunit, JSON / CSV readers
│     ├─ Processing/         Queue Processor, Line Validation, Queue Monitor
│     ├─ Posting/            Contribution Posting, Member Ledger Entry
│     ├─ Statement/          Member Statement report + RDLC layout
│     ├─ TestData/           test data generator
│     └─ RoleCenter/         Pension Administrator role center and cues
├─ test/                     test app (depends on app)
├─ samples/                  the brief's sample batch as JSON and CSV, plus a bad control total file
├─ DESIGN.md                 build plan, object IDs, full decision log
├─ TESTING.md                manual test script and results
└─ Pension Contribution.code-workspace
```

Source is grouped by feature (one folder per part of the brief); files follow Microsoft's naming convention
`<ObjectName>.<ObjectType>.al`.
