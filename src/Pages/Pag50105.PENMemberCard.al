page 50105 "PEN Member Card"
{
    Caption = 'Pension Member Card';
    PageType = Card;
    SourceTable = "PEN Member";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the member.';

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field("First Name"; Rec."First Name")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the member''s first name.';
                }
                field("Last Name"; Rec."Last Name")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the member''s last name.';
                }
                field("National ID No."; Rec."National ID No.")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the member''s national ID number. It must be unique.';
                }
                field("Date of Birth"; Rec."Date of Birth")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the member''s date of birth. The member''s age on the date joined must be within the joining age limits in Pension Setup.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the member is active, exited or deceased.';
                }
            }
            group(Membership)
            {
                Caption = 'Membership';

                field("Employer No."; Rec."Employer No.")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the member''s employer. The member inherits the employer''s scheme.';
                }
                field("Scheme Code"; Rec."Scheme Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the scheme the member belongs to, inherited from the employer.';
                }
                field("Date Joined"; Rec."Date Joined")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the date the member joined the scheme.';
                }
                field("Pensionable Salary"; Rec."Pensionable Salary")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the member''s monthly pensionable salary. It must be greater than zero.';
                }
                field(Balance; Rec.Balance)
                {
                    ApplicationArea = All;
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
                ApplicationArea = All;
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
