table 50102 "PEN Employer"
{
    Caption = 'PEN Employer';
    DataClassification = CustomerContent;
    
    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';
        }
        field(3; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
        }
        field(4; "KRA PIN"; Code[20])
        {
            Caption = 'KRA PIN';
        }
        field(5; Email; Text[80])
        {
            Caption = 'Email';
        }
        field(6; Status; Enum "PEN Employer Status")
        {
            Caption = 'Status';
        }
        field(7; "Member Count"; Integer)
        {
            Caption = 'Member Count';
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
