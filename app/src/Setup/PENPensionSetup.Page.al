page 50100 "PEN Pension Setup"
{
    ApplicationArea = All;
    Caption = 'Pension Setup';
    PageType = Card;
    SourceTable = "PEN Pension Setup";
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Numbering)
            {
                Caption = 'Numbering';

                field("Member Nos."; Rec."Member Nos.")
                {
                    ToolTip = 'Specifies the number series used for members.';
                }
                field("Employer Nos."; Rec."Employer Nos.")
                {
                    ToolTip = 'Specifies the number series used for employers.';
                }
                field("Contribution Batch Nos."; Rec."Contribution Batch Nos.")
                {
                    ToolTip = 'Specifies the number series used for contribution batches.';
                }
            }
            group(Membership)
            {
                Caption = 'Membership';

                field("Min. Joining Age"; Rec."Min. Joining Age")
                {
                    ToolTip = 'Specifies the minimum age, on the date joined, at which a member can join a scheme.';
                }
                field("Max. Joining Age"; Rec."Max. Joining Age")
                {
                    ToolTip = 'Specifies the maximum age, on the date joined, at which a member can join a scheme.';
                }
            }
            group(Remittance)
            {
                Caption = 'Remittance';

                field("Remittance Due Day"; Rec."Remittance Due Day")
                {
                    ToolTip = 'Specifies the day of the month following the contribution period by which contributions are due.';
                }
                field("Late Penalty %"; Rec."Late Penalty %")
                {
                    ToolTip = 'Specifies the penalty charged to the employer on late remittances, as a percentage of the batch total.';
                }
            }
            group(Processing)
            {
                Caption = 'Background Processing';

                field("Queue Batch Size"; Rec."Queue Batch Size")
                {
                    ToolTip = 'Specifies how many contribution lines are processed per commit.';
                }
                field("Max Retry Attempts"; Rec."Max Retry Attempts")
                {
                    ToolTip = 'Specifies how many times a failed line is retried before it moves to Dead Letter.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ScheduleProcessing)
            {
                ApplicationArea = All;
                Caption = 'Schedule Background Processing';
                Image = Timesheet;
                ToolTip = 'Create a recurring job queue entry that processes the contribution queue every minute, or set the existing one to Ready.';

                trigger OnAction()
                var
                    QueueProcessor: Codeunit "PEN Queue Processor";
                begin
                    QueueProcessor.ScheduleRecurringJob();
                end;
            }
            action(GenerateTestData)
            {
                ApplicationArea = All;
                Caption = 'Generate Test Data';
                Image = CreateDocuments;
                ToolTip = 'Create a test scheme, employers, members and one contribution batch per employer for a period, including a few deliberately bad lines.';
                RunObject = page "PEN Generate Test Data";
            }
        }
        area(Navigation)
        {
            action(JobQueueEntries)
            {
                ApplicationArea = All;
                Caption = 'Job Queue Entries';
                Image = JobListSetup;
                RunObject = page "Job Queue Entries";
                RunPageLink = "Object Type to Run" = const(Codeunit), "Object ID to Run" = const(50103);
                ToolTip = 'View the job queue entries that process the contribution queue.';
            }
        }
        area(Promoted)
        {
            actionref(ScheduleProcessing_Promoted; ScheduleProcessing)
            {
            }
            actionref(GenerateTestData_Promoted; GenerateTestData)
            {
            }
            actionref(JobQueueEntries_Promoted; JobQueueEntries)
            {
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
    end;
}
