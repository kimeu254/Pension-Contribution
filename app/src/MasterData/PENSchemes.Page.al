page 50101 "PEN Schemes"
{
    ApplicationArea = All;
    Caption = 'Pension Schemes';
    PageType = List;
    SourceTable = "PEN Scheme";
    UsageCategory = Lists;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Schemes)
            {
                field("Code"; Rec."Code")
                {
                    ToolTip = 'Specifies the code of the scheme.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the scheme.';
                }
                field("Scheme Type"; Rec."Scheme Type")
                {
                    ToolTip = 'Specifies whether the scheme is a defined contribution or an umbrella scheme.';
                }
                field("Employer Cap %"; Rec."Employer Cap %")
                {
                    ToolTip = 'Specifies the maximum employer contribution as a percentage of the member''s pensionable salary.';
                }
                field("Contribution Receivable Acc."; Rec."Contribution Receivable Acc.")
                {
                    ToolTip = 'Specifies the G/L account debited with contributions receivable from employers.';
                }
                field("Member Liability Acc."; Rec."Member Liability Acc.")
                {
                    ToolTip = 'Specifies the G/L account credited with the scheme''s liability to members.';
                }
                field("Penalty Income Acc."; Rec."Penalty Income Acc.")
                {
                    ToolTip = 'Specifies the G/L account credited with late remittance penalties.';
                }
                field(Blocked; Rec.Blocked)
                {
                    ToolTip = 'Specifies that no new members or contributions are accepted for the scheme.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Employers)
            {
                Caption = 'Employers';
                Image = Customer;
                RunObject = page "PEN Employer List";
                RunPageLink = "Scheme Code" = field("Code");
                ToolTip = 'View the employers that participate in the scheme.';
            }
        }
        area(Promoted)
        {
            actionref(Employers_Promoted; Employers)
            {
            }
        }
    }
}
