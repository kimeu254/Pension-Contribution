/// <summary>
/// Background processor for the contribution queue, run by the Job Queue.
/// Each run: releases claims left by crashed runs, requeues Failed lines for retry, then repeatedly claims a chunk
/// of Pending lines (Queue Batch Size, one batch at a time), validates and posts them, and commits.
/// </summary>
codeunit 50103 "PEN Queue Processor"
{
    TableNo = "Job Queue Entry";

    var
        PensionSetup: Record "PEN Pension Setup";
        DuplicateInChunkErr: Label 'Member %1 appears more than once for period %2 in this batch.', Comment = '%1 = Member No., %2 = period';
        JobDescriptionTxt: Label 'Process pension contribution queue';
        JobScheduledMsg: Label 'Background processing is scheduled to run every %1 minute(s).', Comment = '%1 = minutes';
        JobRestartedMsg: Label 'Background processing was already scheduled and has been set to Ready.';
        RunOnceScheduledMsg: Label 'Processing has started in the background. Refresh the page to follow the progress.';

    trigger OnRun()
    begin
        ProcessQueue();
    end;

    procedure ProcessQueue()
    var
        BatchNo: Code[20];
        ClaimId: Guid;
    begin
        PensionSetup.Get();
        ReleaseStaleClaims();
        RequeueFailedLines();
        Commit();

        while ClaimNextChunk(BatchNo, ClaimId) do begin
            ProcessChunk(BatchNo, ClaimId);
            UpdateBatchStatus(BatchNo);
            Commit();
        end;
    end;

    /// <summary>
    /// Resets the selected Failed or Dead Letter lines to Pending with a fresh retry count. Other lines are skipped.
    /// </summary>
    /// <returns>The number of lines reset.</returns>
    procedure ReprocessLines(var SelectedLine: Record "PEN Contribution Queue"): Integer
    var
        QueueLine: Record "PEN Contribution Queue";
        BatchNos: List of [Code[20]];
        BatchNo: Code[20];
        LinesReset: Integer;
    begin
        if SelectedLine.FindSet() then
            repeat
                if SelectedLine.Status in [SelectedLine.Status::Failed, SelectedLine.Status::"Dead Letter"] then begin
                    QueueLine.Get(SelectedLine."Entry No.");
                    QueueLine.Status := QueueLine.Status::Pending;
                    QueueLine."Retry Count" := 0;
                    QueueLine."Last Error" := '';
                    QueueLine.ClearClaim();
                    QueueLine.Modify();
                    LinesReset += 1;
                    if not BatchNos.Contains(QueueLine."Batch No.") then
                        BatchNos.Add(QueueLine."Batch No.");
                end;
            until SelectedLine.Next() = 0;

        foreach BatchNo in BatchNos do
            UpdateBatchStatus(BatchNo);
        exit(LinesReset);
    end;

    /// <summary>
    /// Creates (or restarts) a recurring Job Queue Entry that runs this codeunit every minute.
    /// </summary>
    procedure ScheduleRecurringJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"PEN Queue Processor");
        JobQueueEntry.SetRange("Recurring Job", true);
        if JobQueueEntry.FindFirst() then begin
            JobQueueEntry.Restart();
            Message(JobRestartedMsg);
            exit;
        end;

        InitJobQueueEntry(JobQueueEntry);
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."No. of Minutes between Runs" := 1;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
        Message(JobScheduledMsg, JobQueueEntry."No. of Minutes between Runs");
    end;

    /// <summary>
    /// Starts a one-off background run, so the user does not have to wait for the next scheduled run.
    /// </summary>
    procedure RunOnceInBackground()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        InitJobQueueEntry(JobQueueEntry);
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
        Message(RunOnceScheduledMsg);
    end;

    local procedure InitJobQueueEntry(var JobQueueEntry: Record "Job Queue Entry")
    begin
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"PEN Queue Processor";
        JobQueueEntry.Description := JobDescriptionTxt;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 60;
    end;

    /// <summary>
    /// Returns Processing lines to Pending when the run that claimed them is gone: its session has ended
    /// (crash, restart) or the claim is more than an hour old.
    /// </summary>
    local procedure ReleaseStaleClaims()
    var
        QueueLine: Record "PEN Contribution Queue";
        LineToRelease: Record "PEN Contribution Queue";
    begin
        QueueLine.SetCurrentKey(Status, "Batch No.");
        QueueLine.SetRange(Status, QueueLine.Status::Processing);
        QueueLine.SetLoadFields("Claimed By Session", "Claimed At");
        if QueueLine.FindSet() then
            repeat
                if IsClaimStale(QueueLine) then begin
                    LineToRelease.Get(QueueLine."Entry No.");
                    LineToRelease.Status := LineToRelease.Status::Pending;
                    LineToRelease.ClearClaim();
                    LineToRelease.Modify();
                end;
            until QueueLine.Next() = 0;
    end;

    local procedure IsClaimStale(QueueLine: Record "PEN Contribution Queue"): Boolean
    var
        ActiveSession: Record "Active Session";
        OneHour: Duration;
    begin
        // This run has not claimed anything yet, so a claim carrying our session ID is left over from an earlier session.
        if QueueLine."Claimed By Session" = SessionId() then
            exit(true);
        OneHour := 60 * 60 * 1000;
        if (QueueLine."Claimed At" = 0DT) or (CurrentDateTime() - QueueLine."Claimed At" > OneHour) then
            exit(true);
        ActiveSession.SetRange("Session ID", QueueLine."Claimed By Session");
        exit(ActiveSession.IsEmpty());
    end;

    /// <summary>
    /// Failed lines go back to Pending to be retried. Lines that failed more than Max Retry Attempts are
    /// already in Dead Letter (see MarkLineFailed), so they are not picked up.
    /// </summary>
    local procedure RequeueFailedLines()
    var
        QueueLine: Record "PEN Contribution Queue";
    begin
        QueueLine.SetCurrentKey(Status, "Batch No.");
        QueueLine.SetRange(Status, QueueLine.Status::Failed);
        if not QueueLine.IsEmpty() then
            QueueLine.ModifyAll(Status, QueueLine.Status::Pending);
    end;

    /// <summary>
    /// Claims up to Queue Batch Size Pending lines of one batch: sets them to Processing, stamps them with a new
    /// claim ID and commits. The rows are read with an update lock, so a second job queue entry claiming at the
    /// same time waits and then no longer sees these lines as Pending.
    /// </summary>
    local procedure ClaimNextChunk(var BatchNo: Code[20]; var ClaimId: Guid): Boolean
    var
        QueueLine: Record "PEN Contribution Queue";
        LineToClaim: Record "PEN Contribution Queue";
        LinesClaimed: Integer;
    begin
        QueueLine.ReadIsolation := IsolationLevel::UpdLock;
        QueueLine.SetCurrentKey(Status, "Batch No.");
        QueueLine.SetRange(Status, QueueLine.Status::Pending);
        QueueLine.SetLoadFields("Batch No.");
        if not QueueLine.FindFirst() then
            exit(false);

        BatchNo := QueueLine."Batch No.";
        ClaimId := CreateGuid();
        QueueLine.SetRange("Batch No.", BatchNo);
        QueueLine.FindSet();
        repeat
            LineToClaim.ReadIsolation := IsolationLevel::UpdLock;
            LineToClaim.Get(QueueLine."Entry No.");
            // Re-check under the lock: another run may have claimed the line after our first read.
            if LineToClaim.Status = LineToClaim.Status::Pending then begin
                LineToClaim.Status := LineToClaim.Status::Processing;
                LineToClaim."Claim ID" := ClaimId;
                LineToClaim."Claimed By Session" := SessionId();
                LineToClaim."Claimed At" := CurrentDateTime();
                LineToClaim.Modify();
                LinesClaimed += 1;
            end;
        until (QueueLine.Next() = 0) or (LinesClaimed >= PensionSetup."Queue Batch Size");
        Commit();
        exit(true);
    end;

    /// <summary>
    /// Validates every claimed line on its own, so one bad line cannot stop the others. Failures are committed
    /// first; the valid lines are then posted together in one transaction.
    /// </summary>
    local procedure ProcessChunk(BatchNo: Code[20]; ClaimId: Guid)
    var
        Batch: Record "PEN Contribution Batch";
        QueueLine: Record "PEN Contribution Queue";
        TempClaimedLine: Record "PEN Contribution Queue" temporary;
        TempValidLine: Record "PEN Contribution Queue" temporary;
        LineValidation: Codeunit "PEN Line Validation";
        ContributionPosting: Codeunit "PEN Contribution Posting";
        ValidMemberPeriods: Dictionary of [Text, Boolean];
        PostingError: Text;
    begin
        Batch.Get(BatchNo);

        QueueLine.SetCurrentKey("Claim ID", Status);
        QueueLine.SetRange("Claim ID", ClaimId);
        QueueLine.SetRange(Status, QueueLine.Status::Processing);
        if QueueLine.FindSet() then
            repeat
                TempClaimedLine := QueueLine;
                TempClaimedLine.Insert();
            until QueueLine.Next() = 0;

        if TempClaimedLine.FindSet() then
            repeat
                ClearLastError();
                if TryValidateLine(LineValidation, TempClaimedLine, Batch, ValidMemberPeriods) then begin
                    TempValidLine := TempClaimedLine;
                    TempValidLine.Insert();
                end else
                    MarkLineFailed(TempClaimedLine."Entry No.", GetLastErrorText());
            until TempClaimedLine.Next() = 0;
        // Save the failures now, so they are kept even if posting the valid lines fails.
        Commit();

        if TempValidLine.IsEmpty() then
            exit;

        ContributionPosting.SetLinesToPost(TempValidLine);
        ClearLastError();
        if not ContributionPosting.Run(Batch) then begin
            // Posting rolled back as a whole; every line of the chunk gets the posting error and will be retried.
            PostingError := GetLastErrorText();
            TempValidLine.FindSet();
            repeat
                MarkLineFailed(TempValidLine."Entry No.", PostingError);
            until TempValidLine.Next() = 0;
        end;
    end;

    [TryFunction]
    local procedure TryValidateLine(var LineValidation: Codeunit "PEN Line Validation"; var QueueLine: Record "PEN Contribution Queue"; Batch: Record "PEN Contribution Batch"; var ValidMemberPeriods: Dictionary of [Text, Boolean])
    var
        MemberPeriodKey: Text;
    begin
        LineValidation.ValidateLine(QueueLine, Batch);
        // The posted-line check only sees earlier posts; this catches the same member twice in one chunk.
        MemberPeriodKey := QueueLine."Member No." + '|' + QueueLine.Period;
        if ValidMemberPeriods.ContainsKey(MemberPeriodKey) then
            Error(DuplicateInChunkErr, QueueLine."Member No.", QueueLine.Period);
        ValidMemberPeriods.Add(MemberPeriodKey, true);
    end;

    /// <summary>
    /// Records a failed attempt. A line that has failed more than Max Retry Attempts goes to Dead Letter,
    /// otherwise to Failed, from where the next run requeues it.
    /// </summary>
    local procedure MarkLineFailed(EntryNo: Integer; ErrorText: Text)
    var
        QueueLine: Record "PEN Contribution Queue";
    begin
        QueueLine.Get(EntryNo);
        QueueLine."Retry Count" += 1;
        QueueLine."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(QueueLine."Last Error"));
        QueueLine."Last Attempt At" := CurrentDateTime();
        if QueueLine."Retry Count" > PensionSetup."Max Retry Attempts" then
            QueueLine.Status := QueueLine.Status::"Dead Letter"
        else
            QueueLine.Status := QueueLine.Status::Failed;
        QueueLine.ClearClaim();
        QueueLine.Modify();
    end;

    local procedure UpdateBatchStatus(BatchNo: Code[20])
    var
        Batch: Record "PEN Contribution Batch";
        NewStatus: Enum "PEN Batch Status";
    begin
        if not Batch.Get(BatchNo) then
            exit;
        Batch.CalcFields("Pending Lines", "Processing Lines", "Failed Lines", "Dead Letter Lines", "Posted Lines");
        case true of
            Batch."Pending Lines" + Batch."Processing Lines" + Batch."Failed Lines" > 0:
                if Batch."Posted Lines" + Batch."Dead Letter Lines" + Batch."Failed Lines" + Batch."Processing Lines" > 0 then
                    NewStatus := NewStatus::"In Progress"
                else
                    NewStatus := NewStatus::Received;
            Batch."Dead Letter Lines" > 0:
                NewStatus := NewStatus::"Completed with Errors";
            else
                NewStatus := NewStatus::Completed;
        end;
        if Batch.Status <> NewStatus then begin
            Batch.Status := NewStatus;
            Batch.Modify();
        end;
    end;
}
