table 50106 "PEN Member Ledger Entry"
{
    Caption = 'Member Ledger Entry';
    DataClassification = CustomerContent;
    LookupPageId = "PEN Member Ledger Entries";
    DrillDownPageId = "PEN Member Ledger Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            // SQL identity column: unique even when two sessions post at the same time.
            AutoIncrement = true;
        }
        field(2; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            TableRelation = "PEN Member";
        }
        field(3; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = "PEN Employer";
        }
        field(4; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            TableRelation = "PEN Scheme";
        }
        field(5; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(6; Period; Code[7])
        {
            Caption = 'Period';
        }
        field(7; "Entry Type"; Enum "PEN Ledger Entry Type")
        {
            Caption = 'Entry Type';
        }
        field(8; Amount; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
        }
        field(9; "Batch No."; Code[20])
        {
            Caption = 'Batch No.';
        }
        field(10; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(11; "Posted By"; Code[50])
        {
            Caption = 'Posted By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(12; "Posted At"; DateTime)
        {
            Caption = 'Posted At';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(MemberDate; "Member No.", "Posting Date", "Entry Type")
        {
            SumIndexFields = Amount;
        }
        key(Batch; "Batch No.")
        {
            SumIndexFields = Amount;
        }
        key(Document; "Document No.")
        {
            SumIndexFields = Amount;
        }
    }
}
