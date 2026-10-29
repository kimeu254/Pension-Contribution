table 50100 "PEN Pension Setup"
{
    Caption = 'PEN Pension Setup';
    DataClassification = CustomerContent;
    
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Member Nos."; Code[20])
        {
            Caption = 'Member Nos.';
        }
        field(3; "Employer Nos."; Code[20])
        {
            Caption = 'Employer Nos.';
        }
        field(4; "Contribution Batch Nos."; Code[20])
        {
            Caption = 'Contribution Batch Nos.';
        }
        field(5; "Remittance Due Day"; Integer)
        {
            Caption = 'Remittance Due Day';
        }
        field(6; "Late Penalty %"; Decimal)
        {
            Caption = 'Late Penalty %';
        }
        field(7; "Queue Batch Size"; Integer)
        {
            Caption = 'Queue Batch Size';
        }
        field(8; "Max Retry Attempts"; Integer)
        {
            Caption = 'Max Retry Attempts';
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
