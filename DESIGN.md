# PEN Pension Contributions – Design & Build Plan

Working design for the "BC Pension Contributions Practical". It becomes the README at the end
(design decisions, double-processing prevention, reconciliation, what is unfinished).

---

## 0. Task list (in order)

Legend: `[x]` done · `[ ]` to do. Details for each step are in section 3.

**Step 0 – Project setup**
- [x] AL project, `app.json` (IDs 50100–50149)
- [x] Design document
- [x] `.gitignore`
- [x] Git repo + GitHub remote (`kimeu254/Pension-Contribution`), initial commit pushed

**Step 1 – Master data (Part 1)**
- [x] Enums: Member Status, Employer Status, Scheme Type
- [x] Table shells: Pension Setup, Scheme, Employer, Member
- [x] Fix naming: `PEN Scheme ` trailing space, Scheme `Primary Key` → `Code`, double spaces, `" Last Name"`
- [x] Pension Setup: defaults (9 / 500 / 3), No. Series relations, value ranges
- [x] Scheme: required fields, G/L account relations
- [x] Employer: number series, KRA PIN format + uniqueness, email validation, Member Count FlowField
- [x] Member: number series, required fields, unique National ID, age 18–65, scheme inherited, suspended/blocked check, salary > 0
- [x] Enum Ledger Entry Type + table PEN Member Ledger Entry
- [x] Member Balance FlowField + drill-down
- [x] Pages: Setup, Schemes, Employer List/Card, Member List/Card, Member Ledger Entries
- [x] Install codeunit: setup record + number series
- [x] Permission set `PEN ALL`
- [x] Compiles cleanly (CodeCop / UICop / PTE cop: only file-naming and namespace hints)
- [ ] Verify acceptance criteria 1–3 in sandbox

**Step 2 – Intake (Part 2)**
- [x] Enums: Queue Line Status, Batch Status, Intake Source
- [x] Tables: Contribution Batch, Contribution Queue
- [x] Intake codeunit (single entry point, structural checks, duplicate message ID, control total)
- [x] JSON reader
- [x] CSV reader (extra credit)
- [x] Pages: Contribution Batches (with Import File action and line-count drill-downs), Contribution Queue
- [x] Sample files in `samples/` (JSON, CSV, bad control total)
- [ ] Verify: sample loads, reload rejected, wrong control total rejected

**Step 3 – Background processing (Part 3)**
- [ ] Line validation codeunit (TryFunction) + `OnBeforeValidateQueueLine` event
- [ ] Queue Processor: stale-claim recovery, retry sweep, claim/commit, per-line processing
- [ ] Dead Letter after Max Retry Attempts
- [ ] Reprocess action
- [ ] Job Queue Entry setup + verify users can keep working

**Step 4 – Posting (Part 4)**
- [ ] Member ledger entries (2 per line, AutoIncrement Entry No.)
- [ ] Summarised GL pair per scheme via Gen. Jnl.-Post Line
- [ ] Late penalty once per batch
- [ ] `OnAfterQueueLinePosted` event
- [ ] Verify reconciliation: member ledger total = GL Member Liability credit

**Step 5 – Member statement (Part 5)**
- [ ] Date Filter on Member, report dataset
- [ ] RDLC layout
- [ ] Actions on Member Card and Member List
- [ ] Verify: opening + contributions = closing; member with no entries still prints

**Step 6 – Generator, tests (Part 6)**
- [ ] Test data generator (1 scheme, 50 employers, 2,000 members, ~3% bad lines) + page action
- [ ] Test app with 3–4 test scenarios

**Step 7 – Stretch goals (optional)**
- [ ] Queue monitor page
- [ ] Telemetry (`Session.LogMessage`)
- [ ] Performance at 20,000 lines (before/after timings)
- [ ] API page intake
- [ ] Parallel processing demo with two Job Queue entries

**Step 8 – Deliverables**
- [ ] README (from this document)
- [ ] Compiled `.app`
- [ ] Source zip / repo link
- [ ] Walkthrough notes

---

## 1. Architecture at a glance

```
 Upload (JSON/CSV page action)  ─┐
 API page (stretch)             ─┼─► PEN Contribution Intake (codeunit) ──► Batch header + Queue lines (Pending)
                                 │      structural checks only, all-or-nothing
                                 │
 Job Queue ─► PEN Queue Processor (codeunit)
                 1. requeue Failed lines (retry) / move exhausted ones to Dead Letter
                 2. claim N Pending lines  → Processing   (short txn, COMMIT)
                 3. per line: validate (TryFunction)  → OnBeforeValidateQueueLine event
                       ok   → PEN Contribution Posting: 2 Member Ledger Entries, line = Posted
                       fail → line = Failed, Last Error, Retry Count += 1
                 4. per batch chunk: summarised GL pair per scheme (+ late penalty once per batch)
                 5. COMMIT, next chunk
 Member Statement report  ◄── PEN Member Ledger Entry
```

Principle: **every route goes through one codeunit** per concern (intake, validation, posting),
so pages, API and tests all exercise the same code.

---

## 2. Object ID plan (50100–50149, prefix PEN)

Enums/tables/pages/codeunits have separate ID spaces, but the test app shares the tenant, so
tests use 50140–50149 to avoid collisions.

| Type | ID | Name | Status |
|---|---|---|---|
| Enum | 50100 | PEN Member Status | exists |
| Enum | 50101 | PEN Employer Status | exists |
| Enum | 50102 | PEN Scheme Type | exists |
| Enum | 50103 | PEN Queue Line Status (Pending, Processing, Posted, Failed, Dead Letter) | |
| Enum | 50104 | PEN Batch Status (Received, In Progress, Completed, Completed with Errors) | |
| Enum | 50105 | PEN Ledger Entry Type (Employee Contribution, Employer Contribution) | |
| Enum | 50106 | PEN Intake Source (File JSON, File CSV, API, Generator) | |
| Table | 50100 | PEN Pension Setup | exists – needs fixes |
| Table | 50101 | PEN Scheme | exists – needs fixes |
| Table | 50102 | PEN Employer | exists – needs fixes |
| Table | 50103 | PEN Member | exists – needs fixes |
| Table | 50104 | PEN Contribution Batch | |
| Table | 50105 | PEN Contribution Queue | |
| Table | 50106 | PEN Member Ledger Entry | |
| Table | 50107 | PEN API Intake Buffer (stretch) | |
| Page | 50100 | PEN Pension Setup (card) | |
| Page | 50101 | PEN Schemes (list) | |
| Page | 50102 | PEN Employer List | |
| Page | 50103 | PEN Employer Card | |
| Page | 50104 | PEN Member List | |
| Page | 50105 | PEN Member Card | |
| Page | 50106 | PEN Contribution Batches (list) | |
| Page | 50107 | (free – no batch card; the brief only requires cards for Employer and Member) | |
| Page | 50108 | PEN Contribution Queue (list, Reprocess action in Step 3) | |
| Page | 50109 | PEN Member Ledger Entries | |
| Page | 50110 | PEN Queue Monitor (stretch) | |
| Page | 50111 | PEN Contribution API (stretch) | |
| Codeunit | 50100 | PEN Contribution Intake | |
| Codeunit | 50101 | PEN JSON Batch Reader | |
| Codeunit | 50102 | PEN CSV Batch Reader | |
| Codeunit | 50103 | PEN Queue Processor (Job Queue entry point) | |
| Codeunit | 50104 | PEN Line Validation | |
| Codeunit | 50105 | PEN Contribution Posting | |
| Codeunit | 50106 | PEN Test Data Generator | |
| Codeunit | 50107 | PEN Install (setup defaults, no. series) | |
| Report | 50100 | PEN Member Statement (RDLC or Word) | |
| Codeunit | 50140–50149 | Test codeunit(s) – separate test app | |

---

## 3. Step-by-step build plan

Each step ends with something deployable and checkable in the sandbox.

### Step 1 – Fix and complete master data (Part 1)

Fixes to what already exists:
- `PEN Scheme ` has a trailing space in the object name and caption → `PEN Scheme`.
- Scheme field 1 is called `Primary Key`; spec says `Code`.
- Double spaces: `Contribution Batch  Nos.`, `Contribution Receivable  Acc.`; leading space in `" Last Name"`.
- `Member Count` and `Balance` are plain fields → must be FlowFields.
- Add `TableRelation`, `NotBlank`, `InitValue`, `DataClassification`, `LookupPageId/DrillDownPageId`.

Rules to enforce:

| Table | Rule | Implementation |
|---|---|---|
| Setup | defaults 9 / 500 / 3 | `InitValue`, `MinValue = 1` on batch size & retries, due day 1–31 |
| Setup | number series | `TableRelation = "No. Series"` |
| Scheme | Code, Description required | `NotBlank` + `TestField` in `OnInsert` |
| Scheme | G/L accounts | `TableRelation = "G/L Account" where(Account Type = Posting, Blocked = false)` |
| Employer | No. from series | `OnInsert` → `No. Series` codeunit (`GetNextNo`) + `AssistEdit` on card |
| Employer | KRA PIN format `A000000000Z` | `OnValidate`: length 11, letter + 9 digits + letter |
| Employer | KRA PIN unique | secondary key + `SetRange/IsEmpty` check in `OnValidate` |
| Employer | Email | `Mail Management.CheckValidEmailAddresses` |
| Employer | Member Count | `FlowField Count("PEN Member" where(Employer No.=field(No.), Status=const(Active)))` |
| Member | Names, National ID, Employer, Date Joined required | `NotBlank` + `TestField` in `OnInsert` |
| Member | National ID unique | secondary key + check in `OnValidate` |
| Member | age 18–65 at joining | validate on both DOB and Date Joined (whichever is set last) |
| Member | inherits scheme | `Employer No.` `OnValidate` sets `Scheme Code`; `Scheme Code` `Editable = false` |
| Member | not against suspended employer / blocked scheme | checked in `Employer No.` `OnValidate` **and** `OnInsert` |
| Member | Pensionable Salary > 0 | `OnValidate` + `OnInsert` |
| Member | Balance | `FlowField Sum("PEN Member Ledger Entry".Amount where(Member No.=field(No.)))`, `DrillDownPageId` = ledger entries page |

Also create the `PEN Member Ledger Entry` table here (needed for the Balance FlowField), plus
pages 50100–50105 and 50109, and the install codeunit that creates setup + number series.

**Check:** create a scheme, employer, member; try suspended employer, blocked scheme,
duplicate National ID, age 17 → all rejected.

### Step 2 – Intake (Part 2)

**PEN Contribution Batch** (header): `No.` (series), `Message ID` Code[50] (unique key), `Employer No.`,
`Period` Code[7], `Received Date`, `Control Total`, `Status`, `Source`, `File Name`, `Created By/At`;
FlowFields: `No. of Lines`, employee / employer totals, line counts by status.
(`Penalty Posted`, `Penalty Amount` added in Step 4.)

**PEN Contribution Queue** (line): `Entry No.` (AutoIncrement PK), `Batch No.`, `Line No.`,
`Employer No.`, `Member No.`, `Period`, `Employee Amount`, `Employer Amount`,
`Status`, `Retry Count`, `Last Error` Text[2048], `Last Attempt At`.
(`Claimed By Session`, `Claimed At` added in Step 3; `Posted Document No.` in Step 4.)
Keys: `(Status, Batch No.)` for the processor, `(Member No., Period, Status)` for the duplicate check,
`(Batch No., Line No.)` for the page.

Flow:
1. Page action `Import File` → `UploadIntoStream` → pick reader by extension (`.json` / `.csv`).
2. Reader parses into **temporary** batch + queue records (no DB writes). CSV uses the standard
   `CSV Buffer` table; JSON uses `JsonObject.ReadFrom(InStream)`.
3. `PEN Contribution Intake.CreateBatch(TempBatch, TempLines)` – the single entry point:
   - structural: message ID / employer / period present; period matches `YYYY-MM`; amounts parse
     and are ≥ 0; at least one line; CSV header values identical on every line.
   - message ID not already received → error "Message ID X was already received in batch Y".
   - Σ(employee + employer) = control total → error showing both figures.
   - insert header + lines, all `Pending`. Any error rolls back everything (no partial batch).
4. No business validation here (member existence etc. is Step 3) → intake stays fast.

**Check:** load the sample file (13,500 + 13,500 = 27,000 ✔), load it again → rejected;
edit one amount → rejected for control total.

### Step 3 – Background processing (Part 3)

Codeunit `PEN Queue Processor` (`TableNo = "Job Queue Entry"`), loop:

1. **Recover stale claims**: lines in `Processing` with `Claimed At` older than e.g. 30 min whose
   session is no longer active → back to `Pending` (a crashed job must not orphan lines).
2. **Retry sweep**: `Failed` lines with `Retry Count ≤ Max Retry Attempts` → `Pending`;
   `Retry Count > Max` → `Dead Letter`.
3. **Claim** (own short transaction): `LockTable`, `FindSet` up to *Queue Batch Size* `Pending` lines
   of one batch, set `Processing` + `Claimed By Session = SessionId()` + `Claimed At`, `Commit()`.
4. **Process** the claimed lines (filter on own session ID + Processing):
   - raise `OnBeforeValidateQueueLine`;
   - validation in a `[TryFunction]` (read-only, so it is allowed in a try function):
     member exists / Active / belongs to batch employer; employer Active; scheme not blocked;
     no Posted line for same member + period (DB **and** an in-memory Dictionary for duplicates
     inside the same chunk); employer amount ≤ Cap % × pensionable salary;
   - pass → posting codeunit writes 2 member ledger entries, line → `Posted`, raise `OnAfterQueueLinePosted`;
   - fail → `Failed`, `Last Error = GetLastErrorText()`, `Retry Count += 1`.
5. Post the GL summary for the chunk (Step 4), `Commit()`, loop until no Pending lines remain.
6. Batch status recalculated (Completed / Completed with Errors).

Reprocess action on the queue lines page: selected `Failed` / `Dead Letter` lines → `Pending`,
`Retry Count = 0`, `Last Error` cleared.

**Preventing two Job Queue entries processing the same line (README answer):**
claiming is a separate, committed transaction that changes the status from `Pending` to
`Processing` under a lock and stamps the session ID. A second job either waits on the lock and then
no longer sees those lines as `Pending`, or claims a different set. Processing only touches lines
stamped with its own session. As a last line of defence, posting re-reads the line with
`UpdLock` and refuses unless it is still `Processing` by this session, and the
"no Posted line for member + period" rule stops a double post even if the status logic were bypassed.

### Step 4 – Posting (Part 4)

Codeunit `PEN Contribution Posting`:
- **Member ledger**: `Entry No.` is `AutoIncrement` (SQL identity, unique under concurrent posting);
  2 entries per line (Employee / Employer type), Posting Date = `CalcDate('<CM>', period start)`,
  `Batch No.`, `Document No.`, `Posted By = UserId()`, `Posted At = CurrentDateTime()`.
- **GL**: per chunk, a `Dictionary of [Code[20], Decimal]` scheme → total posted. For each scheme one
  `Gen. Journal Line` (Account = Contribution Receivable, Bal. Account = Member Liability, Amount = total)
  posted with `Gen. Jnl.-Post Line.RunWithCheck`. Document No. = batch no. (with a suffix if a batch
  needs more than one chunk/retry run) and the same value is stamped on the member ledger entries.
- **Late penalty**: due date = `Remittance Due Day` of the month after the period (clamped to month end).
  If `Received Date > due date` and `Penalty Posted = false` → post Late Penalty % × control total,
  Dr Contribution Receivable / Cr Penalty Income, description "Late remittance penalty EMP0001 2026-10",
  set `Penalty Posted = true` in the same transaction (guarantees once per batch).
  Sample: period 2026-10, due 2026-11-09, received 2026-11-12 → late ✔.
- Member ledger + line status + GL are in one transaction per chunk: if GL posting fails the chunk
  rolls back and the lines are marked Failed in a fresh transaction.
- GL accounts are checked during validation so a misconfigured scheme fails lines, not the job.

**Check (reconciliation):** for a batch, Σ member ledger `Amount where Batch No. = X` = GL credit to
Member Liability `where Document No. = X`; a small FactBox/action on the batch shows both figures.

### Step 5 – Member statement (Part 5)

Report `PEN Member Statement`, RDLC layout, run from Member Card and Member List.
- Request page: Start Date, End Date; dataitem `PEN Member` (multi-member via filters).
- Header: name, no., National ID, employer name, scheme.
- Opening balance = `CalcFields(Balance)` with `Date Filter` `..StartDate-1` (add a `Date Filter`
  FlowFilter to Member and use it in the Balance FlowField).
- Body: ledger entries in the range, grouped by Period / Posting Date, columns Employee, Employer,
  running balance.
- Footer: totals for employee and employer; closing balance = opening + totals.
- A member with no entries still prints (body uses an `Integer` dataitem or the member-level row
  so the header and opening = closing balance appear).

### Step 6 – Generator, events, tests (Part 6)

- **Generator** (page action on Setup or Batches): 1 scheme, 50 employers, 2,000 members
  (40 each), one batch per employer for a chosen period, intake via the **same** intake codeunit
  (`Source = Generator`). ~3% bad lines: inactive member, member of another employer,
  employer amount over cap. Uses a request dialog for the period.
- **Integration events** (in validation/posting codeunits):
  `OnBeforeValidateQueueLine(var QueueLine; var IsHandled)`, `OnAfterQueueLinePosted(QueueLine; DocumentNo)`,
  `OnBeforePostGLSummary(var GenJnlLine)`.
- **Tests** – separate test app (`test/`, depends on main app, Library Assert / Library - ERM):
  1. valid line → 2 member ledger entries, GL Member Liability credit = ledger total;
  2. resubmitted Message ID rejected at intake;
  3. one invalid line fails, the rest post;
  4. line that keeps failing goes to Dead Letter after Max Retry Attempts.
  Each test creates its own scheme/employer/members/G/L accounts.

### Step 7 – Stretch goals (only after 1–6 work)

In order of value for effort: queue monitor page → telemetry (`Session.LogMessage` with batch counts
and durations) → performance at 20,000 lines (SetLoadFields, member/employer Dictionary cache,
keys matching filters, timing before/after) → API page (buffer table whose `OnInsert` calls the
intake codeunit with the JSON) → demonstrated parallel processing with two job queue entries.

### Step 8 – Deliverables

README (from this file), compiled `.app`, zipped source, and a walkthrough script.

---

## 4. Decisions where the brief is silent (to record in README)

| Topic | Decision |
|---|---|
| Control total | equals Σ(employee + employer) over all lines |
| Intake failure | all-or-nothing; no partial batch is created |
| Intake structural checks | message ID, employer no., period (`YYYY-MM`), received date present; values fit their field lengths; amounts are numbers and not negative; control total > 0; at least one line; CSV batch columns identical on every row. Member / employer existence is **not** checked at intake (business validation, Step 3) |
| Message ID uniqueness | explicit check with a clear message, backed by a `Unique` key so two simultaneous uploads cannot both succeed |
| Amount formats | parsed culture-independently (decimal point, `YYYY-MM-DD` dates) so a file reads the same whatever the user's language |
| CSV columns | found by heading name (case-insensitive), so column order does not matter; blank rows are skipped |
| Deleting a batch | allowed only while none of its lines are Processing or Posted; deletes its lines too |
| Batch page | no batch card; the Contribution Batches list drills down to its lines via the Lines action and the line-count fields |
| Penalty base | control total of the batch (what the employer declared) |
| Penalty timing | posted with the first processed chunk of the batch, flag prevents repeats |
| GL summary granularity | one pair per scheme per processed chunk of a batch; with batch size 500 and ~40 lines per employer that is one pair per batch |
| Retry semantics | "Failed more than Max Retry Attempts": Retry Count > Max → Dead Letter |
| Reprocess | resets Retry Count to 0 |
| Age rule | age computed on Date Joined, inclusive; limits held in Pension Setup (`Min. Joining Age` 18, `Max. Joining Age` 65) so they can change without a code change – documented in README "Additional fields" |
| Date of Birth | made required, otherwise the 18–65 rule cannot be enforced |
| Member Count | Active members only (per spec) |
| Added fields | `No. Series` on Employer and Member (standard number series pattern), `Date Filter` FlowFilter on Member (statement opening/closing balance) |
| Required fields | `NotBlank` stops blanking a field; `OnInsert`/`OnModify` checks catch records created from code; cards use `DelayedInsert` so the record is only inserted once filled in |
| Uniqueness | KRA PIN and National ID checked in `OnValidate` (clear message) and backed by a `Unique` key (database guarantee) |
| Member rules on insert | employer status / scheme blocked re-checked in `OnInsert`, so the generator, API and tests cannot bypass them |
| Changing scheme / employer | an employer's scheme cannot change once it has members; a member's employer cannot change once they have ledger entries (keeps the ledger consistent) |
| Deletes | scheme with employers, employer with members, member with ledger entries cannot be deleted |
| Scheme G/L accounts | must be Posting type, not blocked, and Direct Posting (required by Gen. Jnl.-Post Line) |
| Number series | created on install: `PEN-MEM` (MEM00001), `PEN-EMP` (EMP0001), `PEN-BATCH` (PCB000001); manual numbers allowed |
| Late Penalty % default | 5% on install (brief gives no value; needed for the sample's late batch to post a penalty) |
| Posting date | last day of the contribution period |
| Tests | separate test app, IDs 50140–50149 |
