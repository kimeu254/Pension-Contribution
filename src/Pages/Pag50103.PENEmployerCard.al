page 50103 "PEN Employer Card"
{
    Caption = 'Pension Employer Card';
    PageType = Card;
    SourceTable = "PEN Employer";
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
                    ToolTip = 'Specifies the number of the employer.';

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the name of the employer.';
                }
                field("Scheme Code"; Rec."Scheme Code")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the pension scheme the employer participates in.';
                }
                field("KRA PIN"; Rec."KRA PIN")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the employer''s KRA PIN, in the format A000000000Z.';
                }
                field(Email; Rec.Email)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the employer''s email address.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the employer is active or suspended. Suspended employers cannot take new members or contributions.';
                }
                field("Member Count"; Rec."Member Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of active members of the employer.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Members)
            {
                ApplicationArea = All;
                Caption = 'Members';
                Image = Employee;
                RunObject = page "PEN Member List";
                RunPageLink = "Employer No." = field("No.");
                ToolTip = 'View the members of the employer.';
            }
        }
        area(Promoted)
        {
            actionref(Members_Promoted; Members)
            {
            }
        }
    }
}
