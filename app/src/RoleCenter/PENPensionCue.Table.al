/// <summary>
/// Single record holding the FlowFields behind the cues on the Pension Administrator role center.
/// </summary>
table 50108 "PEN Pension Cue"
{
    Caption = 'Pension Cue';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Pending Lines"; Integer)
        {
            Caption = 'Pending Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Pending)));
            Editable = false;
        }
        field(11; "Processing Lines"; Integer)
        {
            Caption = 'Processing Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Processing)));
            Editable = false;
        }
        field(12; "Failed Lines"; Integer)
        {
            Caption = 'Failed Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Failed)));
            Editable = false;
        }
        field(13; "Dead Letter Lines"; Integer)
        {
            Caption = 'Dead Letter Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const("Dead Letter")));
            Editable = false;
        }
        field(20; "Open Batches"; Integer)
        {
            Caption = 'Open Batches';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Batch" where(Status = filter(Received | "In Progress")));
            Editable = false;
        }
        field(21; "Batches with Errors"; Integer)
        {
            Caption = 'Batches with Errors';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Batch" where(Status = const("Completed with Errors")));
            Editable = false;
        }
        field(30; "Active Employers"; Integer)
        {
            Caption = 'Active Employers';
            FieldClass = FlowField;
            CalcFormula = count("PEN Employer" where(Status = const(Active)));
            Editable = false;
        }
        field(31; "Active Members"; Integer)
        {
            Caption = 'Active Members';
            FieldClass = FlowField;
            CalcFormula = count("PEN Member" where(Status = const(Active)));
            Editable = false;
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
