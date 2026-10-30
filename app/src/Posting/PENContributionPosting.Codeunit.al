/// <summary>
/// Posts the validated lines of one processing chunk: two member ledger entries per line, one summarised G/L pair
/// per scheme, and the late remittance penalty once per batch.
/// Run with Codeunit.Run so that any posting error rolls back the whole chunk and the processor can record it.
/// </summary>
codeunit 50105 "PEN Contribution Posting"
{
    TableNo = "PEN Contribution Batch";

    var
        TempLineToPost: Record "PEN Contribution Queue" temporary;
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        LineNoLongerClaimedErr: Label 'Queue line %1 (member %2) is no longer claimed by this processing run. It may have been processed by another job.', Comment = '%1 = Entry No., %2 = Member No.';
        PostedElsewhereErr: Label 'A contribution for member %1 and period %2 has already been posted (batch %3).', Comment = '%1 = Member No., %2 = period, %3 = Batch No.';
        ContributionDescTxt: Label 'Contributions %1 %2 batch %3', Comment = '%1 = Employer No., %2 = period, %3 = Batch No.';
        PenaltyDescTxt: Label 'Late remittance penalty %1 %2', Comment = '%1 = Employer No., %2 = period';

    trigger OnRun()
    begin
        PostLines(Rec);
    end;

    /// <summary>
    /// Sets the validated lines to post. Call before running the codeunit.
    /// </summary>
    procedure SetLinesToPost(var TempValidLine: Record "PEN Contribution Queue" temporary)
    begin
        TempLineToPost.Copy(TempValidLine, true);
    end;

    /// <summary>
    /// Returns the two figures that must agree for a processed batch: the member ledger total and the credit
    /// to the Member Liability account across all postings of the batch.
    /// </summary>
    procedure GetReconciliation(Batch: Record "PEN Contribution Batch"; var MemberLedgerTotal: Decimal; var GLMemberLiabilityCredit: Decimal)
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
        GLEntry: Record "G/L Entry";
        Employer: Record "PEN Employer";
        Scheme: Record "PEN Scheme";
    begin
        MemberLedgerEntry.SetCurrentKey("Batch No.");
        MemberLedgerEntry.SetRange("Batch No.", Batch."No.");
        MemberLedgerEntry.CalcSums(Amount);
        MemberLedgerTotal := MemberLedgerEntry.Amount;

        GLMemberLiabilityCredit := 0;
        if not Employer.Get(Batch."Employer No.") then
            exit;
        if not Scheme.Get(Employer."Scheme Code") then
            exit;
        GLEntry.SetRange("G/L Account No.", Scheme."Member Liability Acc.");
        GLEntry.SetFilter("Document No.", Batch.GetDocumentNoFilter());
        GLEntry.CalcSums(Amount);
        GLMemberLiabilityCredit := -GLEntry.Amount;
    end;

    local procedure PostLines(var Batch: Record "PEN Contribution Batch")
    var
        PensionSetup: Record "PEN Pension Setup";
        QueueLine: Record "PEN Contribution Queue";
        Member: Record "PEN Member";
        SchemeTotals: Dictionary of [Code[20], Decimal];
        SchemeCode: Code[20];
        DocumentNo: Code[20];
        PostingDate: Date;
    begin
        PensionSetup.Get();

        // Lock the batch: chunks of the same batch post one after the other, which keeps the document number
        // sequence and the "penalty posted once" flag safe when two job queue entries run at the same time.
        Batch.ReadIsolation := IsolationLevel::UpdLock;
        Batch.Get(Batch."No.");
        Batch."No. of Postings" += 1;
        DocumentNo := Batch.GetPostingDocumentNo();
        PostingDate := Batch.GetPeriodEndDate();

        TempLineToPost.FindSet();
        repeat
            LockClaimedLine(TempLineToPost, QueueLine);
            LockMember(QueueLine."Member No.", Member);
            CheckNotPostedElsewhere(QueueLine);

            InsertMemberLedgerEntry(QueueLine, Member, Batch, "PEN Ledger Entry Type"::"Employee Contribution", QueueLine."Employee Amount", DocumentNo, PostingDate);
            InsertMemberLedgerEntry(QueueLine, Member, Batch, "PEN Ledger Entry Type"::"Employer Contribution", QueueLine."Employer Amount", DocumentNo, PostingDate);
            AddToSchemeTotal(SchemeTotals, Member."Scheme Code", QueueLine."Employee Amount" + QueueLine."Employer Amount");

            QueueLine.Status := QueueLine.Status::Posted;
            QueueLine."Posted Document No." := DocumentNo;
            QueueLine."Last Error" := '';
            QueueLine."Last Attempt At" := CurrentDateTime();
            QueueLine.ClearClaim();
            QueueLine.Modify();

            OnAfterQueueLinePosted(QueueLine, DocumentNo);
        until TempLineToPost.Next() = 0;

        foreach SchemeCode in SchemeTotals.Keys() do
            PostContributionSummary(Batch, SchemeCode, SchemeTotals.Get(SchemeCode), DocumentNo, PostingDate);

        PostLatePenaltyIfDue(Batch, PensionSetup, DocumentNo);
        Batch.Modify();
    end;

    /// <summary>
    /// Re-reads the line with an update lock and refuses to post it unless it still carries this run's claim.
    /// Last line of defence against two runs posting the same line.
    /// </summary>
    local procedure LockClaimedLine(TempLine: Record "PEN Contribution Queue" temporary; var QueueLine: Record "PEN Contribution Queue")
    begin
        QueueLine.ReadIsolation := IsolationLevel::UpdLock;
        QueueLine.Get(TempLine."Entry No.");
        if (QueueLine.Status <> QueueLine.Status::Processing) or (QueueLine."Claim ID" <> TempLine."Claim ID") then
            Error(LineNoLongerClaimedErr, QueueLine."Entry No.", QueueLine."Member No.");
    end;

    /// <summary>
    /// Locks the member so two runs posting the same member (from different batches) are serialised, and the
    /// already-posted check below sees the other run's committed result.
    /// </summary>
    local procedure LockMember(MemberNo: Code[20]; var Member: Record "PEN Member")
    begin
        Member.ReadIsolation := IsolationLevel::UpdLock;
        Member.SetLoadFields("No.", "Scheme Code");
        Member.Get(MemberNo);
    end;

    local procedure CheckNotPostedElsewhere(QueueLine: Record "PEN Contribution Queue")
    var
        PostedLine: Record "PEN Contribution Queue";
    begin
        PostedLine.SetCurrentKey("Member No.", Period, Status);
        PostedLine.SetRange("Member No.", QueueLine."Member No.");
        PostedLine.SetRange(Period, QueueLine.Period);
        PostedLine.SetRange(Status, PostedLine.Status::Posted);
        PostedLine.SetLoadFields("Batch No.");
        if PostedLine.FindFirst() then
            Error(PostedElsewhereErr, QueueLine."Member No.", QueueLine.Period, PostedLine."Batch No.");
    end;

    local procedure InsertMemberLedgerEntry(QueueLine: Record "PEN Contribution Queue"; Member: Record "PEN Member"; Batch: Record "PEN Contribution Batch"; EntryType: Enum "PEN Ledger Entry Type"; EntryAmount: Decimal; DocumentNo: Code[20]; PostingDate: Date)
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
    begin
        MemberLedgerEntry.Init();
        MemberLedgerEntry."Entry No." := 0; // AutoIncrement assigns the number
        MemberLedgerEntry."Member No." := QueueLine."Member No.";
        MemberLedgerEntry."Employer No." := Batch."Employer No.";
        MemberLedgerEntry."Scheme Code" := Member."Scheme Code";
        MemberLedgerEntry."Posting Date" := PostingDate;
        MemberLedgerEntry.Period := QueueLine.Period;
        MemberLedgerEntry."Entry Type" := EntryType;
        MemberLedgerEntry.Amount := EntryAmount;
        MemberLedgerEntry."Batch No." := Batch."No.";
        MemberLedgerEntry."Document No." := DocumentNo;
        MemberLedgerEntry."Posted By" := CopyStr(UserId(), 1, MaxStrLen(MemberLedgerEntry."Posted By"));
        MemberLedgerEntry."Posted At" := CurrentDateTime();
        MemberLedgerEntry.Insert();
    end;

    local procedure AddToSchemeTotal(var SchemeTotals: Dictionary of [Code[20], Decimal]; SchemeCode: Code[20]; LineAmount: Decimal)
    begin
        if SchemeTotals.ContainsKey(SchemeCode) then
            SchemeTotals.Set(SchemeCode, SchemeTotals.Get(SchemeCode) + LineAmount)
        else
            SchemeTotals.Add(SchemeCode, LineAmount);
    end;

    /// <summary>
    /// One G/L pair per scheme for the whole chunk: debit Contribution Receivable, credit Member Liability.
    /// </summary>
    local procedure PostContributionSummary(Batch: Record "PEN Contribution Batch"; SchemeCode: Code[20]; TotalAmount: Decimal; DocumentNo: Code[20]; PostingDate: Date)
    var
        Scheme: Record "PEN Scheme";
        GenJournalLine: Record "Gen. Journal Line";
    begin
        if TotalAmount = 0 then
            exit;
        Scheme.Get(SchemeCode);
        InitGenJournalLine(GenJournalLine, Batch, PostingDate, DocumentNo);
        GenJournalLine."Account No." := Scheme."Contribution Receivable Acc.";
        GenJournalLine."Bal. Account No." := Scheme."Member Liability Acc.";
        GenJournalLine.Description := CopyStr(StrSubstNo(ContributionDescTxt, Batch."Employer No.", Batch.Period, Batch."No."), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine.Validate(Amount, TotalAmount);
        PostGenJournalLine(GenJournalLine, Batch);
    end;

    /// <summary>
    /// Posts the late remittance penalty the first time any line of a late batch is posted:
    /// Late Penalty % of the control total, debit Contribution Receivable, credit Penalty Income.
    /// </summary>
    local procedure PostLatePenaltyIfDue(var Batch: Record "PEN Contribution Batch"; PensionSetup: Record "PEN Pension Setup"; DocumentNo: Code[20])
    var
        Employer: Record "PEN Employer";
        Scheme: Record "PEN Scheme";
        GenJournalLine: Record "Gen. Journal Line";
        PenaltyAmount: Decimal;
    begin
        if Batch."Penalty Posted" then
            exit;
        if not Batch.IsLate() then
            exit;
        PenaltyAmount := Round(Batch."Control Total" * PensionSetup."Late Penalty %" / 100);
        if PenaltyAmount <= 0 then
            exit;

        Employer.Get(Batch."Employer No.");
        Scheme.Get(Employer."Scheme Code");
        InitGenJournalLine(GenJournalLine, Batch, Batch."Received Date", DocumentNo);
        GenJournalLine."Account No." := Scheme."Contribution Receivable Acc.";
        GenJournalLine."Bal. Account No." := Scheme."Penalty Income Acc.";
        GenJournalLine.Description := CopyStr(StrSubstNo(PenaltyDescTxt, Batch."Employer No.", Batch.Period), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine.Validate(Amount, PenaltyAmount);
        PostGenJournalLine(GenJournalLine, Batch);

        Batch."Penalty Posted" := true;
        Batch."Penalty Amount" := PenaltyAmount;
        Batch."Penalty Document No." := DocumentNo;
    end;

    local procedure InitGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; Batch: Record "PEN Contribution Batch"; PostingDate: Date; DocumentNo: Code[20])
    begin
        GenJournalLine.Init();
        GenJournalLine."Posting Date" := PostingDate;
        GenJournalLine."Document Date" := PostingDate;
        GenJournalLine."Document No." := DocumentNo;
        GenJournalLine."External Document No." := CopyStr(Batch."Message ID", 1, MaxStrLen(GenJournalLine."External Document No."));
        // Accounts are assigned, not validated, so no VAT or posting groups are copied from the G/L accounts:
        // these are balance-sheet transfers, not taxable transactions.
        GenJournalLine."Account Type" := GenJournalLine."Account Type"::"G/L Account";
        GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"G/L Account";
        GenJournalLine."System-Created Entry" := true;
    end;

    local procedure PostGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; Batch: Record "PEN Contribution Batch")
    begin
        OnBeforePostGenJournalLine(GenJournalLine, Batch);
        GenJnlPostLine.RunWithCheck(GenJournalLine);
    end;

    /// <summary>
    /// Raised after a queue line has been posted to the member ledger, inside the posting transaction.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterQueueLinePosted(var QueueLine: Record "PEN Contribution Queue"; DocumentNo: Code[20])
    begin
    end;

    /// <summary>
    /// Raised before a summary or penalty journal line is posted, for example to add dimensions or a source code.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnBeforePostGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; Batch: Record "PEN Contribution Batch")
    begin
    end;
}
