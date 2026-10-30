table 50104 "PEN Contribution Batch"
{
    Caption = 'Contribution Batch';
    DataClassification = CustomerContent;
    DataCaptionFields = "No.", "Message ID";
    LookupPageId = "PEN Contribution Batches";
    DrillDownPageId = "PEN Contribution Batches";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(2; "Message ID"; Code[50])
        {
            Caption = 'Message ID';
        }
        field(3; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            // Not validated at intake: an unknown employer is a business error handled by background processing.
            TableRelation = "PEN Employer";
            ValidateTableRelation = false;
        }
        field(4; Period; Code[7])
        {
            Caption = 'Period';
        }
        field(5; "Received Date"; Date)
        {
            Caption = 'Received Date';
        }
        field(6; "Control Total"; Decimal)
        {
            Caption = 'Control Total';
            AutoFormatType = 1;
        }
        field(7; Status; Enum "PEN Batch Status")
        {
            Caption = 'Status';
        }
        field(8; Source; Enum "PEN Intake Source")
        {
            Caption = 'Source';
        }
        field(9; "File Name"; Text[250])
        {
            Caption = 'File Name';
        }
        field(10; "Created By"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(12; "Penalty Posted"; Boolean)
        {
            Caption = 'Penalty Posted';
            Editable = false;
        }
        field(13; "Penalty Amount"; Decimal)
        {
            Caption = 'Penalty Amount';
            AutoFormatType = 1;
            Editable = false;
        }
        field(14; "Penalty Document No."; Code[20])
        {
            Caption = 'Penalty Document No.';
            Editable = false;
        }
        // Counts the postings for this batch, so each one gets its own G/L document number (see GetPostingDocumentNo).
        field(15; "No. of Postings"; Integer)
        {
            Caption = 'No. of Postings';
            Editable = false;
        }
        field(20; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No.")));
            Editable = false;
        }
        field(21; "Total Employee Amount"; Decimal)
        {
            Caption = 'Total Employee Amount';
            FieldClass = FlowField;
            CalcFormula = sum("PEN Contribution Queue"."Employee Amount" where("Batch No." = field("No.")));
            AutoFormatType = 1;
            Editable = false;
        }
        field(22; "Total Employer Amount"; Decimal)
        {
            Caption = 'Total Employer Amount';
            FieldClass = FlowField;
            CalcFormula = sum("PEN Contribution Queue"."Employer Amount" where("Batch No." = field("No.")));
            AutoFormatType = 1;
            Editable = false;
        }
        field(23; "Pending Lines"; Integer)
        {
            Caption = 'Pending Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Pending)));
            Editable = false;
        }
        field(24; "Processing Lines"; Integer)
        {
            Caption = 'Processing Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Processing)));
            Editable = false;
        }
        field(25; "Posted Lines"; Integer)
        {
            Caption = 'Posted Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Posted)));
            Editable = false;
        }
        field(26; "Failed Lines"; Integer)
        {
            Caption = 'Failed Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Failed)));
            Editable = false;
        }
        field(27; "Dead Letter Lines"; Integer)
        {
            Caption = 'Dead Letter Lines';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const("Dead Letter")));
            Editable = false;
        }
        field(28; "Member Ledger Amount"; Decimal)
        {
            Caption = 'Member Ledger Amount';
            FieldClass = FlowField;
            CalcFormula = sum("PEN Member Ledger Entry".Amount where("Batch No." = field("No.")));
            AutoFormatType = 1;
            Editable = false;
        }
    }
    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        // Database-level guarantee that the same file cannot be loaded twice, even by two sessions at once.
        key(MessageID; "Message ID")
        {
            Unique = true;
        }
        key(EmployerPeriod; "Employer No.", Period)
        {
        }
    }

    var
        CannotDeleteBatchErr: Label 'You cannot delete batch %1 because some of its lines are being processed or have been posted.', Comment = '%1 = Batch No.';

    trigger OnInsert()
    var
        PensionSetup: Record "PEN Pension Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            PensionSetup.Get();
            PensionSetup.TestField("Contribution Batch Nos.");
            "No." := NoSeries.GetNextNo(PensionSetup."Contribution Batch Nos.");
        end;
    end;

    trigger OnDelete()
    var
        QueueLine: Record "PEN Contribution Queue";
    begin
        QueueLine.SetRange("Batch No.", "No.");
        QueueLine.SetFilter(Status, '%1|%2', QueueLine.Status::Processing, QueueLine.Status::Posted);
        if not QueueLine.IsEmpty() then
            Error(CannotDeleteBatchErr, "No.");
        QueueLine.SetRange(Status);
        QueueLine.DeleteAll();
    end;

    procedure GetPeriodStartDate(): Date
    var
        Intake: Codeunit "PEN Contribution Intake";
    begin
        exit(Intake.GetPeriodStartDate(Period));
    end;

    /// <summary>
    /// The last day of the contribution period; used as the posting date of the contributions.
    /// </summary>
    procedure GetPeriodEndDate(): Date
    begin
        exit(CalcDate('<CM>', GetPeriodStartDate()));
    end;

    /// <summary>
    /// Remittance Due Day of the month after the period. A due day past the end of that month (e.g. 31 in
    /// February) falls on the month's last day.
    /// </summary>
    procedure GetRemittanceDueDate(): Date
    var
        PensionSetup: Record "PEN Pension Setup";
        NextMonthStart: Date;
        DueDay: Integer;
        LastDayOfMonth: Integer;
    begin
        PensionSetup.Get();
        NextMonthStart := CalcDate('<1M>', GetPeriodStartDate());
        LastDayOfMonth := Date2DMY(CalcDate('<CM>', NextMonthStart), 1);
        DueDay := PensionSetup."Remittance Due Day";
        if DueDay > LastDayOfMonth then
            DueDay := LastDayOfMonth;
        exit(DMY2Date(DueDay, Date2DMY(NextMonthStart, 2), Date2DMY(NextMonthStart, 3)));
    end;

    procedure IsLate(): Boolean
    begin
        exit("Received Date" > GetRemittanceDueDate());
    end;

    /// <summary>
    /// G/L document number of the current posting: the batch number for the first posting, then
    /// batch number + "-2", "-3"... for postings of retried lines, so every posting can be traced to the batch.
    /// </summary>
    procedure GetPostingDocumentNo(): Code[20]
    begin
        if "No. of Postings" <= 1 then
            exit("No.");
        exit(CopyStr(StrSubstNo('%1-%2', "No.", "No. of Postings"), 1, 20));
    end;

    /// <summary>
    /// Filter on Document No. that matches every posting of this batch.
    /// </summary>
    procedure GetDocumentNoFilter(): Text
    begin
        exit("No." + '|' + "No." + '-*');
    end;
}
