table 50105 "PEN Contribution Queue"
{
    Caption = 'Contribution Queue';
    DataClassification = CustomerContent;
    LookupPageId = "PEN Contribution Queue";
    DrillDownPageId = "PEN Contribution Queue";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Batch No."; Code[20])
        {
            Caption = 'Batch No.';
            TableRelation = "PEN Contribution Batch";
        }
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(4; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = "PEN Employer";
            ValidateTableRelation = false;
        }
        field(5; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            // Not validated at intake: an unknown member is a business error handled by background processing.
            TableRelation = "PEN Member";
            ValidateTableRelation = false;
        }
        field(6; Period; Code[7])
        {
            Caption = 'Period';
        }
        field(7; "Employee Amount"; Decimal)
        {
            Caption = 'Employee Amount';
            AutoFormatType = 1;
        }
        field(8; "Employer Amount"; Decimal)
        {
            Caption = 'Employer Amount';
            AutoFormatType = 1;
        }
        field(9; Status; Enum "PEN Queue Line Status")
        {
            Caption = 'Status';
        }
        field(10; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
        }
        field(11; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
        }
        field(12; "Last Attempt At"; DateTime)
        {
            Caption = 'Last Attempt At';
        }
        // Claim fields: set when a processing run moves the line to Processing, cleared when it leaves Processing.
        field(13; "Claim ID"; Guid)
        {
            Caption = 'Claim ID';
        }
        field(14; "Claimed By Session"; Integer)
        {
            Caption = 'Claimed By Session';
        }
        field(15; "Claimed At"; DateTime)
        {
            Caption = 'Claimed At';
        }
        field(16; "Posted Document No."; Code[20])
        {
            Caption = 'Posted Document No.';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(BatchLine; "Batch No.", "Line No.")
        {
        }
        // Used by the background processor to pick up work.
        key(StatusBatch; Status, "Batch No.")
        {
        }
        // Used by the "no Posted line for the same member and period" check.
        key(MemberPeriod; "Member No.", Period, Status)
        {
        }
        // Used by a processing run to find the lines it claimed.
        key(Claim; "Claim ID", Status)
        {
        }
    }

    /// <summary>
    /// Clears the claim fields when the line leaves Processing.
    /// </summary>
    procedure ClearClaim()
    begin
        Clear("Claim ID");
        "Claimed By Session" := 0;
        "Claimed At" := 0DT;
    end;
}
