/// <summary>
/// Tests for the contribution cycle: intake, background processing, posting and reconciliation.
/// Every test creates its own data through PEN Test Library and processes only its own batch.
/// </summary>
codeunit 50140 "PEN Contribution Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Lib: Codeunit "PEN Test Library";
        PeriodTok: Label '2026-10', Locked = true;
        StatusAfterAttemptTxt: Label 'Status after attempt %1', Locked = true;
        RetryCountAfterAttemptTxt: Label 'Retry count after attempt %1', Locked = true;

    [Test]
    procedure ValidLinePostsTwoMemberLedgerEntriesAndGLMatches()
    var
        Batch: Record "PEN Contribution Batch";
        QueueLine: Record "PEN Contribution Queue";
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
        Scheme: Record "PEN Scheme";
        GLEntry: Record "G/L Entry";
        TempLine: Record "PEN Contribution Queue" temporary;
        ContributionPosting: Codeunit "PEN Contribution Posting";
        SchemeCode: Code[20];
        EmployerNo: Code[20];
        MemberNo: Code[20];
        BatchNo: Code[20];
        MemberLedgerTotal: Decimal;
        GLMemberLiabilityCredit: Decimal;
    begin
        // [GIVEN] A scheme with a 10% employer cap, an employer and a member earning 100,000
        Lib.InitSetup(3);
        SchemeCode := Lib.CreateScheme(10);
        EmployerNo := Lib.CreateEmployer(SchemeCode);
        MemberNo := Lib.CreateMember(EmployerNo, 100000);

        // [GIVEN] A batch received on the due date with one line of 5,000 employee + 5,000 employer
        Lib.AddLine(TempLine, MemberNo, 5000, 5000);
        BatchNo := Lib.CreateBatch(EmployerNo, PeriodTok, 20261109D, Lib.GetUniqueMessageId(), TempLine);

        // [WHEN] The queue is processed
        Lib.ProcessBatch(BatchNo);

        // [THEN] The line is posted
        Lib.GetQueueLine(BatchNo, MemberNo, QueueLine);
        Lib.AreEqual(Format(QueueLine.Status::Posted), Format(QueueLine.Status), 'Queue line status');

        // [THEN] Two member ledger entries are created, one per entry type
        MemberLedgerEntry.SetRange("Batch No.", BatchNo);
        MemberLedgerEntry.SetRange("Member No.", MemberNo);
        Lib.AreEqual(2, MemberLedgerEntry.Count(), 'Number of member ledger entries');
        MemberLedgerEntry.SetRange("Entry Type", MemberLedgerEntry."Entry Type"::"Employee Contribution");
        MemberLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(5000, MemberLedgerEntry.Amount, 'Employee contribution entry');
        MemberLedgerEntry.SetRange("Entry Type", MemberLedgerEntry."Entry Type"::"Employer Contribution");
        MemberLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(5000, MemberLedgerEntry.Amount, 'Employer contribution entry');

        // [THEN] The G/L credit to Member Liability equals the member ledger total, in one summarised entry
        Batch.Get(BatchNo);
        ContributionPosting.GetReconciliation(Batch, MemberLedgerTotal, GLMemberLiabilityCredit);
        Lib.AreEqual(10000, MemberLedgerTotal, 'Member ledger total');
        Lib.AreEqual(10000, GLMemberLiabilityCredit, 'G/L credit to Member Liability');
        Scheme.Get(SchemeCode);
        GLEntry.SetFilter("Document No.", Batch.GetDocumentNoFilter());
        GLEntry.SetRange("G/L Account No.", Scheme."Member Liability Acc.");
        Lib.AreEqual(1, GLEntry.Count(), 'Number of Member Liability G/L entries');

        // [THEN] No penalty, because the batch arrived on the due date
        Lib.IsTrue(not Batch."Penalty Posted", 'An on-time batch must not be charged a penalty');
    end;

    [Test]
    procedure ResubmittedMessageIdIsRejectedAtIntake()
    var
        Batch: Record "PEN Contribution Batch";
        TempLine: Record "PEN Contribution Queue" temporary;
        EmployerNo: Code[20];
        MemberNo: Code[20];
        MessageId: Code[50];
    begin
        // [GIVEN] A batch that has been received
        Lib.InitSetup(3);
        EmployerNo := Lib.CreateEmployer(Lib.CreateScheme(10));
        MemberNo := Lib.CreateMember(EmployerNo, 100000);
        MessageId := Lib.GetUniqueMessageId();
        Lib.AddLine(TempLine, MemberNo, 1000, 1000);
        Lib.CreateBatch(EmployerNo, PeriodTok, 20261109D, MessageId, TempLine);

        // [WHEN] The same message ID is received again
        asserterror Lib.CreateBatch(EmployerNo, PeriodTok, 20261109D, MessageId, TempLine);

        // [THEN] It is rejected and only one batch exists
        Lib.ExpectedErrorContains('has already been received');
        Batch.SetRange("Message ID", MessageId);
        Lib.AreEqual(1, Batch.Count(), 'Number of batches with the message ID');
    end;

    [Test]
    procedure OneInvalidLineFailsWhileTheOthersPost()
    var
        QueueLine: Record "PEN Contribution Queue";
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
        TempLine: Record "PEN Contribution Queue" temporary;
        EmployerNo: Code[20];
        MemberNo1: Code[20];
        MemberNo2: Code[20];
        MemberNo3: Code[20];
        BatchNo: Code[20];
    begin
        // [GIVEN] Three members, the second of whom has exited
        Lib.InitSetup(3);
        EmployerNo := Lib.CreateEmployer(Lib.CreateScheme(10));
        MemberNo1 := Lib.CreateMember(EmployerNo, 100000);
        MemberNo2 := Lib.CreateMember(EmployerNo, 100000);
        MemberNo3 := Lib.CreateMember(EmployerNo, 100000);
        Lib.SetMemberStatus(MemberNo2, "PEN Member Status"::Exited);

        // [GIVEN] A batch with a line for each of them
        Lib.AddLine(TempLine, MemberNo1, 4000, 4000);
        Lib.AddLine(TempLine, MemberNo2, 3000, 3000);
        Lib.AddLine(TempLine, MemberNo3, 2000, 2000);
        BatchNo := Lib.CreateBatch(EmployerNo, PeriodTok, 20261109D, Lib.GetUniqueMessageId(), TempLine);

        // [WHEN] The queue is processed
        Lib.ProcessBatch(BatchNo);

        // [THEN] The exited member's line fails with its own error and one retry counted
        Lib.GetQueueLine(BatchNo, MemberNo2, QueueLine);
        Lib.AreEqual(Format(QueueLine.Status::Failed), Format(QueueLine.Status), 'Status of the invalid line');
        Lib.IsTrue(StrPos(QueueLine."Last Error", 'is not active') > 0, 'Error text of the invalid line: ' + QueueLine."Last Error");
        Lib.AreEqual(1, QueueLine."Retry Count", 'Retry count of the invalid line');

        // [THEN] The other two lines are posted
        Lib.GetQueueLine(BatchNo, MemberNo1, QueueLine);
        Lib.AreEqual(Format(QueueLine.Status::Posted), Format(QueueLine.Status), 'Status of line 1');
        Lib.GetQueueLine(BatchNo, MemberNo3, QueueLine);
        Lib.AreEqual(Format(QueueLine.Status::Posted), Format(QueueLine.Status), 'Status of line 3');

        // [THEN] Only the valid lines reach the member ledger
        MemberLedgerEntry.SetRange("Batch No.", BatchNo);
        Lib.AreEqual(4, MemberLedgerEntry.Count(), 'Number of member ledger entries');
        MemberLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(12000, MemberLedgerEntry.Amount, 'Member ledger total');
    end;

    [Test]
    procedure LineThatKeepsFailingMovesToDeadLetter()
    var
        QueueLine: Record "PEN Contribution Queue";
        TempLine: Record "PEN Contribution Queue" temporary;
        QueueProcessor: Codeunit "PEN Queue Processor";
        EmployerNo: Code[20];
        MemberNo: Code[20];
        BatchNo: Code[20];
        Attempt: Integer;
    begin
        // [GIVEN] Max Retry Attempts = 2 and a line for an exited member, which fails every time
        Lib.InitSetup(2);
        EmployerNo := Lib.CreateEmployer(Lib.CreateScheme(10));
        MemberNo := Lib.CreateMember(EmployerNo, 100000);
        Lib.SetMemberStatus(MemberNo, "PEN Member Status"::Exited);
        Lib.AddLine(TempLine, MemberNo, 1000, 1000);
        BatchNo := Lib.CreateBatch(EmployerNo, PeriodTok, 20261109D, Lib.GetUniqueMessageId(), TempLine);

        // [WHEN] The queue is processed once plus once per retry
        // [THEN] The line stays Failed while retries remain
        for Attempt := 1 to 2 do begin
            Lib.ProcessBatch(BatchNo);
            Lib.GetQueueLine(BatchNo, MemberNo, QueueLine);
            Lib.AreEqual(Format(QueueLine.Status::Failed), Format(QueueLine.Status), StrSubstNo(StatusAfterAttemptTxt, Attempt));
            Lib.AreEqual(Attempt, QueueLine."Retry Count", StrSubstNo(RetryCountAfterAttemptTxt, Attempt));
        end;

        // [THEN] Failing more than Max Retry Attempts moves it to Dead Letter
        Lib.ProcessBatch(BatchNo);
        Lib.GetQueueLine(BatchNo, MemberNo, QueueLine);
        Lib.AreEqual(Format(QueueLine.Status::"Dead Letter"), Format(QueueLine.Status), 'Status after the last attempt');
        Lib.AreEqual(3, QueueLine."Retry Count", 'Retry count after the last attempt');

        // [THEN] A Dead Letter line is not picked up again by later runs
        Lib.ProcessBatch(BatchNo);
        Lib.GetQueueLine(BatchNo, MemberNo, QueueLine);
        Lib.AreEqual(3, QueueLine."Retry Count", 'Retry count after a further run');

        // [WHEN] The line is reprocessed manually
        QueueLine.SetRecFilter();
        QueueProcessor.ReprocessLines(QueueLine);

        // [THEN] It is Pending again with a fresh retry count
        Lib.GetQueueLine(BatchNo, MemberNo, QueueLine);
        Lib.AreEqual(Format(QueueLine.Status::Pending), Format(QueueLine.Status), 'Status after Reprocess');
        Lib.AreEqual(0, QueueLine."Retry Count", 'Retry count after Reprocess');
    end;

    [Test]
    procedure LateBatchPostsOnePenalty()
    var
        Batch: Record "PEN Contribution Batch";
        Scheme: Record "PEN Scheme";
        GLEntry: Record "G/L Entry";
        TempLine: Record "PEN Contribution Queue" temporary;
        SchemeCode: Code[20];
        EmployerNo: Code[20];
        BatchNo: Code[20];
    begin
        // [GIVEN] The sample batch from the brief: period 2026-10, due 2026-11-09, received 2026-11-12 (late), total 27,000
        Lib.InitSetup(3);
        SchemeCode := Lib.CreateScheme(10);
        EmployerNo := Lib.CreateEmployer(SchemeCode);
        Lib.AddLine(TempLine, Lib.CreateMember(EmployerNo, 100000), 6000, 6000);
        Lib.AddLine(TempLine, Lib.CreateMember(EmployerNo, 100000), 4500, 4500);
        Lib.AddLine(TempLine, Lib.CreateMember(EmployerNo, 100000), 3000, 3000);
        BatchNo := Lib.CreateBatch(EmployerNo, PeriodTok, 20261112D, Lib.GetUniqueMessageId(), TempLine);

        // [WHEN] The queue is processed, and processed again
        Lib.ProcessBatch(BatchNo);
        Lib.ProcessBatch(BatchNo);

        // [THEN] One penalty of 5% x 27,000 = 1,350 is posted to Penalty Income
        Batch.Get(BatchNo);
        Lib.IsTrue(Batch."Penalty Posted", 'A late batch must be charged a penalty');
        Lib.AreEqual(1350, Batch."Penalty Amount", 'Penalty amount');
        Scheme.Get(SchemeCode);
        GLEntry.SetFilter("Document No.", Batch.GetDocumentNoFilter());
        GLEntry.SetRange("G/L Account No.", Scheme."Penalty Income Acc.");
        Lib.AreEqual(1, GLEntry.Count(), 'Number of penalty G/L entries');
        GLEntry.CalcSums(Amount);
        Lib.AreEqual(-1350, GLEntry.Amount, 'Penalty Income G/L amount');
    end;
}
