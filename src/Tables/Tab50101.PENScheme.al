table 50101 "PEN Scheme"
{
    Caption = 'PEN Scheme';
    DataClassification = CustomerContent;
    
    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "Scheme Type"; Enum "PEN Scheme Type")
        {
            Caption = 'Scheme Type';
        }
        field(4; "Employer Cap %"; Decimal)
        {
            Caption = 'Employer Cap %';
        }
        field(5; "Contribution Receivable Acc."; Code[20])
        {
            Caption = 'Contribution Receivable Acc.';
        }
        field(6; "Member Liability Acc."; Code[20])
        {
            Caption = 'Member Liability Acc.';
        }
        field(7; "Penalty Income Acc."; Code[20])
        {
            Caption = 'Penalty Income Acc.';
        }
        field(8; Blocked; Boolean)
        {
            Caption = 'Blocked';
        }
    }
    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }
}
