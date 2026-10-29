table 50100 "PEN Pension Setup"
{
    Caption = 'Pension Setup';
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
            TableRelation = "No. Series";
        }
        field(3; "Employer Nos."; Code[20])
        {
            Caption = 'Employer Nos.';
            TableRelation = "No. Series";
        }
        field(4; "Contribution Batch Nos."; Code[20])
        {
            Caption = 'Contribution Batch Nos.';
            TableRelation = "No. Series";
        }
        field(5; "Remittance Due Day"; Integer)
        {
            Caption = 'Remittance Due Day';
            InitValue = 9;
            MinValue = 1;
            MaxValue = 31;
        }
        field(6; "Late Penalty %"; Decimal)
        {
            Caption = 'Late Penalty %';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;
        }
        field(7; "Queue Batch Size"; Integer)
        {
            Caption = 'Queue Batch Size';
            InitValue = 500;
            MinValue = 1;
        }
        field(8; "Max Retry Attempts"; Integer)
        {
            Caption = 'Max Retry Attempts';
            InitValue = 3;
            MinValue = 0;
        }
        field(9; "Min. Joining Age"; Integer)
        {
            Caption = 'Min. Joining Age';
            InitValue = 18;
            MinValue = 1;

            trigger OnValidate()
            begin
                CheckJoiningAgeRange();
            end;
        }
        field(10; "Max. Joining Age"; Integer)
        {
            Caption = 'Max. Joining Age';
            InitValue = 65;
            MinValue = 1;

            trigger OnValidate()
            begin
                CheckJoiningAgeRange();
            end;
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        InvalidAgeRangeErr: Label 'Min. Joining Age (%1) cannot be greater than Max. Joining Age (%2).', Comment = '%1 = minimum age, %2 = maximum age';

    procedure InsertIfNotExists()
    begin
        Reset();
        if not Get() then begin
            Init();
            Insert(true);
        end;
    end;

    local procedure CheckJoiningAgeRange()
    begin
        if ("Max. Joining Age" <> 0) and ("Min. Joining Age" > "Max. Joining Age") then
            Error(InvalidAgeRangeErr, "Min. Joining Age", "Max. Joining Age");
    end;
}
