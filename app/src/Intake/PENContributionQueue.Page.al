page 50108 "PEN Contribution Queue"
{
    ApplicationArea = All;
    Caption = 'Contribution Queue';
    PageType = List;
    SourceTable = "PEN Contribution Queue";
    UsageCategory = Lists;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Batch No."; Rec."Batch No.")
                {
                    ToolTip = 'Specifies the batch the line belongs to.';
                }
                field("Line No."; Rec."Line No.")
                {
                    ToolTip = 'Specifies the position of the line in the received file.';
                }
                field("Employer No."; Rec."Employer No.")
                {
                    ToolTip = 'Specifies the employer that sent the line.';
                }
                field("Member No."; Rec."Member No.")
                {
                    ToolTip = 'Specifies the member the contribution is for.';
                }
                field(Period; Rec.Period)
                {
                    ToolTip = 'Specifies the contribution period, for example 2026-10.';
                }
                field("Employee Amount"; Rec."Employee Amount")
                {
                    ToolTip = 'Specifies the employee contribution.';
                }
                field("Employer Amount"; Rec."Employer Amount")
                {
                    ToolTip = 'Specifies the employer contribution.';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies the processing status of the line.';
                    StyleExpr = StatusStyle;
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies how many times processing the line has failed.';
                }
                field("Last Error"; Rec."Last Error")
                {
                    ToolTip = 'Specifies the error from the last failed processing attempt.';
                }
                field("Last Attempt At"; Rec."Last Attempt At")
                {
                    ToolTip = 'Specifies when the line was last processed.';
                }
                field("Posted Document No."; Rec."Posted Document No.")
                {
                    ToolTip = 'Specifies the document number of the member ledger and G/L entries posted for the line.';
                }
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the unique number of the queue line.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Reprocess)
            {
                Caption = 'Reprocess';
                Image = Restore;
                ToolTip = 'Reset the selected Failed or Dead Letter lines to Pending with a fresh retry count, so the background process picks them up again. Lines in other statuses are skipped.';

                trigger OnAction()
                var
                    SelectedLine: Record "PEN Contribution Queue";
                    QueueProcessor: Codeunit "PEN Queue Processor";
                    LinesReset: Integer;
                begin
                    CurrPage.SetSelectionFilter(SelectedLine);
                    LinesReset := QueueProcessor.ReprocessLines(SelectedLine);
                    Message(LinesResetMsg, LinesReset);
                    CurrPage.Update(false);
                end;
            }
            action(ProcessNow)
            {
                Caption = 'Process Now';
                Image = Start;
                ToolTip = 'Start a background run of the contribution queue now instead of waiting for the next scheduled run. You can keep working while it runs.';

                trigger OnAction()
                var
                    QueueProcessor: Codeunit "PEN Queue Processor";
                begin
                    QueueProcessor.RunOnceInBackground();
                end;
            }
        }
        area(Promoted)
        {
            actionref(Reprocess_Promoted; Reprocess)
            {
            }
            actionref(ProcessNow_Promoted; ProcessNow)
            {
            }
        }
    }

    var
        StatusStyle: Text;
        LinesResetMsg: Label '%1 line(s) were reset to Pending.', Comment = '%1 = number of lines';

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Posted:
                StatusStyle := 'Favorable';
            Rec.Status::Failed:
                StatusStyle := 'Ambiguous';
            Rec.Status::"Dead Letter":
                StatusStyle := 'Unfavorable';
            else
                StatusStyle := 'Standard';
        end;
    end;
}
