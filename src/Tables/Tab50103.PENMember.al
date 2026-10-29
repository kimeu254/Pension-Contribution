table 50103 "PEN Member"
{
    Caption = 'PEN Member';
    DataClassification = CustomerContent;
    
    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(2; "First Name"; Text[50])
        {
            Caption = 'First Name';
        }
        field(3; "Last Name"; Text[50])
        {
            Caption = 'Last Name';
        }
        field(4; "National ID No."; Code[20])
        {
            Caption = 'National ID No.';
        }
        field(5; "Date of Birth"; Date)
        {
            Caption = 'Date of Birth';
        }
        field(6; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
        }
        field(7; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
        }
        field(8; "Date Joined"; Date)
        {
            Caption = 'Date Joined';
        }
        field(9; "Pensionable Salary"; Decimal)
        {
            Caption = 'Pensionable Salary';
        }
        field(10; Status; Enum "PEN Member Status")
        {
            Caption = 'Status';
        }
        field(11; Balance; Decimal)
        {
            Caption = 'Balance';
        }
    }
    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
    }
}
