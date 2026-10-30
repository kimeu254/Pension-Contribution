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
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the unique number of the queue line.';
                    Visible = false;
                }
            }
        }
    }

    var
        StatusStyle: Text;

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
