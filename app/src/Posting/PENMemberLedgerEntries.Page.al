page 50109 "PEN Member Ledger Entries"
{
    ApplicationArea = All;
    Caption = 'Member Ledger Entries';
    PageType = List;
    SourceTable = "PEN Member Ledger Entry";
    UsageCategory = History;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the unique number of the entry.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the posting date, the last day of the contribution period.';
                }
                field(Period; Rec.Period)
                {
                    ToolTip = 'Specifies the contribution period, for example 2026-10.';
                }
                field("Member No."; Rec."Member No.")
                {
                    ToolTip = 'Specifies the member the entry belongs to.';
                }
                field("Employer No."; Rec."Employer No.")
                {
                    ToolTip = 'Specifies the employer that remitted the contribution.';
                }
                field("Scheme Code"; Rec."Scheme Code")
                {
                    ToolTip = 'Specifies the scheme of the contribution.';
                }
                field("Entry Type"; Rec."Entry Type")
                {
                    ToolTip = 'Specifies whether the entry is an employee or employer contribution.';
                }
                field(Amount; Rec.Amount)
                {
                    ToolTip = 'Specifies the amount of the entry.';
                }
                field("Batch No."; Rec."Batch No.")
                {
                    ToolTip = 'Specifies the contribution batch the entry came from.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ToolTip = 'Specifies the document number, which matches the G/L entries for the same posting.';
                }
                field("Posted By"; Rec."Posted By")
                {
                    ToolTip = 'Specifies the user who posted the entry.';
                }
                field("Posted At"; Rec."Posted At")
                {
                    ToolTip = 'Specifies when the entry was posted.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(GLEntries)
            {
                Caption = 'G/L Entries';
                Image = GLRegisters;
                RunObject = page "General Ledger Entries";
                RunPageLink = "Document No." = field("Document No.");
                ToolTip = 'View the general ledger entries posted with the same document number.';
            }
        }
        area(Promoted)
        {
            actionref(GLEntries_Promoted; GLEntries)
            {
            }
        }
    }
}
