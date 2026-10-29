table 50101 "PEN Scheme"
{
    Caption = 'Pension Scheme';
    DataClassification = CustomerContent;
    LookupPageId = "PEN Schemes";
    DrillDownPageId = "PEN Schemes";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            NotBlank = true;
        }
        field(3; "Scheme Type"; Enum "PEN Scheme Type")
        {
            Caption = 'Scheme Type';
        }
        field(4; "Employer Cap %"; Decimal)
        {
            Caption = 'Employer Cap %';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;
        }
        field(5; "Contribution Receivable Acc."; Code[20])
        {
            Caption = 'Contribution Receivable Acc.';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));

            trigger OnValidate()
            begin
                CheckGLAccount("Contribution Receivable Acc.");
            end;
        }
        field(6; "Member Liability Acc."; Code[20])
        {
            Caption = 'Member Liability Acc.';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));

            trigger OnValidate()
            begin
                CheckGLAccount("Member Liability Acc.");
            end;
        }
        field(7; "Penalty Income Acc."; Code[20])
        {
            Caption = 'Penalty Income Acc.';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));

            trigger OnValidate()
            begin
                CheckGLAccount("Penalty Income Acc.");
            end;
        }
        field(8; Blocked; Boolean)
        {
            Caption = 'Blocked';
        }
    }
    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }
    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, "Scheme Type")
        {
        }
    }

    var
        SchemeHasEmployersErr: Label 'You cannot delete scheme %1 because employers are assigned to it.', Comment = '%1 = Scheme Code';

    trigger OnInsert()
    begin
        TestField(Description);
    end;

    trigger OnDelete()
    var
        Employer: Record "PEN Employer";
    begin
        Employer.SetRange("Scheme Code", "Code");
        if not Employer.IsEmpty() then
            Error(SchemeHasEmployersErr, "Code");
    end;

    /// <summary>
    /// Errors if the scheme is blocked. Used by member creation and contribution processing.
    /// </summary>
    procedure CheckNotBlocked()
    begin
        TestField(Blocked, false);
    end;

    /// <summary>
    /// Ensures all G/L accounts needed for posting contributions and penalties are set up.
    /// </summary>
    procedure CheckPostingAccounts()
    begin
        TestField("Contribution Receivable Acc.");
        TestField("Member Liability Acc.");
        TestField("Penalty Income Acc.");
        CheckGLAccount("Contribution Receivable Acc.");
        CheckGLAccount("Member Liability Acc.");
        CheckGLAccount("Penalty Income Acc.");
    end;

    local procedure CheckGLAccount(AccountNo: Code[20])
    var
        GLAccount: Record "G/L Account";
    begin
        if AccountNo = '' then
            exit;
        GLAccount.Get(AccountNo);
        GLAccount.TestField("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.TestField(Blocked, false);
        GLAccount.TestField("Direct Posting", true);
    end;
}
