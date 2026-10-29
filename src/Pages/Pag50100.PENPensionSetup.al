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

    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
    end;
}
