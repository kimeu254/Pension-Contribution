page 50104 "PEN Member List"
{
    ApplicationArea = All;
    Caption = 'Pension Members';
    PageType = List;
    SourceTable = "PEN Member";
    CardPageId = "PEN Member Card";
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Members)
            {
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the number of the member.';
                }
                field("First Name"; Rec."First Name")
                {
                    ToolTip = 'Specifies the member''s first name.';
                }
                field("Last Name"; Rec."Last Name")
                {
                    ToolTip = 'Specifies the member''s last name.';
                }
                field("National ID No."; Rec."National ID No.")
                {
                    ToolTip = 'Specifies the member''s national ID number.';
                }
                field("Employer No."; Rec."Employer No.")
                {
                    ToolTip = 'Specifies the member''s employer.';
                }
                field("Scheme Code"; Rec."Scheme Code")
                {
                    ToolTip = 'Specifies the scheme the member belongs to, inherited from the employer.';
                }
                field("Date Joined"; Rec."Date Joined")
                {
                    ToolTip = 'Specifies the date the member joined the scheme.';
                }
                field("Pensionable Salary"; Rec."Pensionable Salary")
                {
                    ToolTip = 'Specifies the member''s monthly pensionable salary.';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies whether the member is active, exited or deceased.';
                }
                field(Balance; Rec.Balance)
                {
                    ToolTip = 'Specifies the member''s balance. Choose the value to see the ledger entries.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(LedgerEntries)
            {
                Caption = 'Ledger Entries';
                Image = LedgerEntries;
                RunObject = page "PEN Member Ledger Entries";
                RunPageLink = "Member No." = field("No.");
                RunPageView = sorting("Member No.", "Posting Date", "Entry Type");
                ShortcutKey = 'Ctrl+F7';
                ToolTip = 'View the member''s contribution ledger entries.';
            }
        }
        area(Promoted)
        {
            actionref(LedgerEntries_Promoted; LedgerEntries)
            {
            }
        }
    }
}
