/// <summary>
/// One place to see how background processing is doing: lines by status, the last and next run of the
/// queue processor, and the most common errors.
/// </summary>
page 50110 "PEN Queue Monitor"
{
    ApplicationArea = All;
    Caption = 'Queue Monitor';
    PageType = Card;
    SourceTable = "PEN Pension Cue";
    UsageCategory = Tasks;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            group(LinesByStatus)
            {
                Caption = 'Lines by Status';

                field("Pending Lines"; Rec."Pending Lines")
                {
                    DrillDownPageId = "PEN Contribution Queue";
                    ToolTip = 'Specifies the number of lines waiting to be processed.';
                }
                field("Processing Lines"; Rec."Processing Lines")
                {
                    DrillDownPageId = "PEN Contribution Queue";
                    ToolTip = 'Specifies the number of lines claimed by a run that is in progress.';
                }
                field("Posted Lines"; Rec."Posted Lines")
                {
                    DrillDownPageId = "PEN Contribution Queue";
                    ToolTip = 'Specifies the number of lines posted to the member ledger and general ledger.';
                }
                field("Failed Lines"; Rec."Failed Lines")
                {
                    DrillDownPageId = "PEN Contribution Queue";
                    StyleExpr = FailedStyle;
                    ToolTip = 'Specifies the number of lines that failed and will be retried by the next run.';
                }
                field("Dead Letter Lines"; Rec."Dead Letter Lines")
                {
                    DrillDownPageId = "PEN Contribution Queue";
                    StyleExpr = DeadLetterStyle;
                    ToolTip = 'Specifies the number of lines that failed more than the maximum retry attempts and need a manual Reprocess.';
                }
            }
            group(LastRun)
            {
                Caption = 'Last Run';

                field(LastRunStartedAt; LastRunStartedAt)
                {
                    Caption = 'Started At';
                    ToolTip = 'Specifies when the last run of the contribution queue processor started.';
                }
                field(LastRunEndedAt; LastRunEndedAt)
                {
                    Caption = 'Ended At';
                    ToolTip = 'Specifies when the last run of the contribution queue processor ended.';
                }
                field(LastRunDuration; LastRunDuration)
                {
                    Caption = 'Duration';
                    ToolTip = 'Specifies how long the last run took.';
                }
                field(LastRunResult; LastRunResult)
                {
                    Caption = 'Result';
                    StyleExpr = LastRunStyle;
                    ToolTip = 'Specifies whether the last run succeeded. If it failed, choose the value to see the job queue log.';

                    trigger OnDrillDown()
                    begin
                        ShowJobQueueLog();
                    end;
                }
                field(LastRunError; LastRunError)
                {
                    Caption = 'Error';
                    ToolTip = 'Specifies the error of the last run, if it failed. Errors on individual lines are shown below, not here.';
                }
                field(LastLineProcessedAt; LastLineProcessedAt)
                {
                    Caption = 'Last Line Processed At';
                    ToolTip = 'Specifies when a contribution line was last posted or failed.';
                }
            }
            group(Schedule)
            {
                Caption = 'Schedule';

                field(ScheduleStatus; ScheduleStatus)
                {
                    Caption = 'Recurring Job';
                    ToolTip = 'Specifies the status of the recurring job queue entry that processes the queue. Use Schedule Background Processing on the Pension Setup page to create it.';
                }
                field(NextRunAt; NextRunAt)
                {
                    Caption = 'Next Run At';
                    ToolTip = 'Specifies when the recurring job is due to run next.';
                }
            }
            part(ErrorSummary; "PEN Queue Error Summary")
            {
                Caption = 'Most Common Errors';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                Caption = 'Refresh';
                Image = Refresh;
                ToolTip = 'Reload the counts, the last run and the error list.';

                trigger OnAction()
                begin
                    // Re-reads the record, which runs OnAfterGetRecord and reloads everything.
                    CurrPage.Update(false);
                end;
            }
            action(ProcessNow)
            {
                Caption = 'Process Now';
                Image = Start;
                ToolTip = 'Start a background run of the contribution queue now instead of waiting for the next scheduled run.';

                trigger OnAction()
                var
                    QueueProcessor: Codeunit "PEN Queue Processor";
                begin
                    QueueProcessor.RunOnceInBackground();
                end;
            }
        }
        area(Navigation)
        {
            action(Queue)
            {
                Caption = 'Contribution Queue';
                Image = List;
                RunObject = page "PEN Contribution Queue";
                ToolTip = 'View the queue lines, their errors, and reprocess failed lines.';
            }
            action(JobQueueLog)
            {
                Caption = 'Job Queue Log';
                Image = Log;
                ToolTip = 'View the log of every run of the contribution queue processor.';

                trigger OnAction()
                begin
                    ShowJobQueueLog();
                end;
            }
        }
        area(Promoted)
        {
            actionref(Refresh_Promoted; Refresh)
            {
            }
            actionref(ProcessNow_Promoted; ProcessNow)
            {
            }
            actionref(Queue_Promoted; Queue)
            {
            }
            actionref(JobQueueLog_Promoted; JobQueueLog)
            {
            }
        }
    }

    var
        LastRunStartedAt: DateTime;
        LastRunEndedAt: DateTime;
        LastRunDuration: Duration;
        LastRunResult: Text;
        LastRunError: Text;
        LastRunStyle: Text;
        LastLineProcessedAt: DateTime;
        ScheduleStatus: Text;
        NextRunAt: DateTime;
        FailedStyle: Text;
        DeadLetterStyle: Text;
        NeverRunTxt: Label 'Never run';
        NotScheduledTxt: Label 'Not scheduled';

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;

    trigger OnAfterGetRecord()
    begin
        LoadMonitor();
    end;

    local procedure LoadMonitor()
    begin
        Rec.CalcFields("Pending Lines", "Processing Lines", "Posted Lines", "Failed Lines", "Dead Letter Lines");
        FailedStyle := GetWarningStyle(Rec."Failed Lines", 'Ambiguous');
        DeadLetterStyle := GetWarningStyle(Rec."Dead Letter Lines", 'Unfavorable');
        LoadLastRun();
        LoadSchedule();
        LoadLastLineProcessedAt();
        CurrPage.ErrorSummary.Page.Load();
    end;

    local procedure LoadLastRun()
    var
        JobQueueLogEntry: Record "Job Queue Log Entry";
    begin
        Clear(LastRunStartedAt);
        Clear(LastRunEndedAt);
        Clear(LastRunDuration);
        LastRunError := '';
        LastRunResult := NeverRunTxt;
        LastRunStyle := 'Standard';

        FilterJobQueueLog(JobQueueLogEntry);
        if not JobQueueLogEntry.FindLast() then
            exit;
        LastRunStartedAt := JobQueueLogEntry."Start Date/Time";
        LastRunEndedAt := JobQueueLogEntry."End Date/Time";
        if (LastRunStartedAt <> 0DT) and (LastRunEndedAt <> 0DT) then
            LastRunDuration := LastRunEndedAt - LastRunStartedAt;
        LastRunResult := Format(JobQueueLogEntry.Status);
        LastRunError := JobQueueLogEntry."Error Message";
        case JobQueueLogEntry.Status of
            JobQueueLogEntry.Status::Success:
                LastRunStyle := 'Favorable';
            JobQueueLogEntry.Status::Error:
                LastRunStyle := 'Unfavorable';
        end;
    end;

    local procedure LoadSchedule()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        ScheduleStatus := NotScheduledTxt;
        Clear(NextRunAt);
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"PEN Queue Processor");
        JobQueueEntry.SetRange("Recurring Job", true);
        if not JobQueueEntry.FindFirst() then
            exit;
        ScheduleStatus := Format(JobQueueEntry.Status);
        NextRunAt := JobQueueEntry."Earliest Start Date/Time";
    end;

    local procedure LoadLastLineProcessedAt()
    var
        QueueLine: Record "PEN Contribution Queue";
    begin
        Clear(LastLineProcessedAt);
        QueueLine.SetCurrentKey("Last Attempt At");
        QueueLine.SetLoadFields("Last Attempt At");
        if QueueLine.FindLast() then
            LastLineProcessedAt := QueueLine."Last Attempt At";
    end;

    local procedure ShowJobQueueLog()
    var
        JobQueueLogEntry: Record "Job Queue Log Entry";
    begin
        FilterJobQueueLog(JobQueueLogEntry);
        Page.Run(Page::"Job Queue Log Entries", JobQueueLogEntry);
    end;

    local procedure FilterJobQueueLog(var JobQueueLogEntry: Record "Job Queue Log Entry")
    begin
        JobQueueLogEntry.SetRange("Object Type to Run", JobQueueLogEntry."Object Type to Run"::Codeunit);
        JobQueueLogEntry.SetRange("Object ID to Run", Codeunit::"PEN Queue Processor");
    end;

    local procedure GetWarningStyle(CueValue: Integer; WarningStyle: Text): Text
    begin
        if CueValue > 0 then
            exit(WarningStyle);
        exit('Favorable');
    end;
}
