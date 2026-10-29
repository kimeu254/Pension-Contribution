page 50102 "PEN Employer List"
{
    ApplicationArea = All;
    Caption = 'Pension Employers';
    PageType = List;
    SourceTable = "PEN Employer";
    CardPageId = "PEN Employer Card";
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Employers)
            {
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the number of the employer.';
                }
                field(Name; Rec.Name)
                {
                    ToolTip = 'Specifies the name of the employer.';
                }
                field("Scheme Code"; Rec."Scheme Code")
                {
                    ToolTip = 'Specifies the pension scheme the employer participates in.';
                }
                field("KRA PIN"; Rec."KRA PIN")
                {
                    ToolTip = 'Specifies the employer''s KRA PIN.';
                }
                field(Email; Rec.Email)
                {
                    ToolTip = 'Specifies the employer''s email address.';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies whether the employer is active or suspended.';
                }
                field("Member Count"; Rec."Member Count")
                {
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
