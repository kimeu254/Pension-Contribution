table 50103 "PEN Member"
{
    Caption = 'Pension Member';
    DataClassification = CustomerContent;
    DataCaptionFields = "No.", "First Name", "Last Name";
    LookupPageId = "PEN Member List";
    DrillDownPageId = "PEN Member List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';

            trigger OnValidate()
            var
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    GetPensionSetup();
                    NoSeries.TestManual(PensionSetup."Member Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; "First Name"; Text[50])
        {
            Caption = 'First Name';
            NotBlank = true;
        }
        field(3; "Last Name"; Text[50])
        {
            Caption = 'Last Name';
            NotBlank = true;
        }
        field(4; "National ID No."; Code[20])
        {
            Caption = 'National ID No.';
            NotBlank = true;

            trigger OnValidate()
            begin
                CheckNationalIDUnique();
            end;
        }
        field(5; "Date of Birth"; Date)
        {
            Caption = 'Date of Birth';
            NotBlank = true;

            trigger OnValidate()
            begin
                CheckAgeAtJoining();
            end;
        }
        field(6; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            NotBlank = true;
            TableRelation = "PEN Employer";

            trigger OnValidate()
            var
                Employer: Record "PEN Employer";
            begin
                if "Employer No." = xRec."Employer No." then
                    exit;
                if HasLedgerEntries() then
                    Error(CannotChangeEmployerErr, "No.");
                Employer.Get("Employer No.");
                Employer.CheckCanAcceptContributions();
                "Scheme Code" := Employer."Scheme Code";
            end;
        }
        field(7; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            TableRelation = "PEN Scheme";
            Editable = false;
        }
        field(8; "Date Joined"; Date)
        {
            Caption = 'Date Joined';
            NotBlank = true;

            trigger OnValidate()
            begin
                CheckAgeAtJoining();
            end;
        }
        field(9; "Pensionable Salary"; Decimal)
        {
            Caption = 'Pensionable Salary';
            AutoFormatType = 1;

            trigger OnValidate()
            begin
                CheckPensionableSalary();
            end;
        }
        field(10; Status; Enum "PEN Member Status")
        {
            Caption = 'Status';
        }
        field(11; Balance; Decimal)
        {
            Caption = 'Balance';
            FieldClass = FlowField;
            CalcFormula = sum("PEN Member Ledger Entry".Amount where("Member No." = field("No."), "Posting Date" = field("Date Filter")));
            AutoFormatType = 1;
            Editable = false;
        }
        field(12; "Date Filter"; Date)
        {
            Caption = 'Date Filter';
            FieldClass = FlowFilter;
        }
        field(20; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            TableRelation = "No. Series";
            Editable = false;
        }
    }
    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(NationalID; "National ID No.")
        {
            Unique = true;
        }
        key(Employer; "Employer No.", Status)
        {
        }
    }
    fieldgroups
    {
        fieldgroup(DropDown; "No.", "First Name", "Last Name", "Employer No.")
        {
        }
    }

    var
        PensionSetup: Record "PEN Pension Setup";
        PensionSetupRead: Boolean;
        DuplicateNationalIDErr: Label 'National ID No. %1 is already registered to member %2.', Comment = '%1 = National ID No., %2 = Member No.';
        AgeOutOfRangeErr: Label 'The member must be between %1 and %2 years old on the date joined. Age on %3 is %4.', Comment = '%1 = minimum age, %2 = maximum age, %3 = Date Joined, %4 = age';
        SalaryMustBePositiveErr: Label 'Pensionable Salary must be greater than zero.';
        CannotChangeEmployerErr: Label 'You cannot change the employer of member %1 because the member has ledger entries.', Comment = '%1 = Member No.';
        HasLedgerEntriesErr: Label 'You cannot delete member %1 because the member has ledger entries.', Comment = '%1 = Member No.';

    trigger OnInsert()
    var
        Employer: Record "PEN Employer";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            GetPensionSetup();
            PensionSetup.TestField("Member Nos.");
            "No. Series" := PensionSetup."Member Nos.";
            if NoSeries.AreRelated("No. Series", xRec."No. Series") then
                "No. Series" := xRec."No. Series";
            "No." := NoSeries.GetNextNo("No. Series");
        end;

        CheckMandatoryFields();
        // Re-check on insert so records created from code (generator, API, tests) obey the same rules as the card.
        Employer.Get("Employer No.");
        Employer.CheckCanAcceptContributions();
        "Scheme Code" := Employer."Scheme Code";
        CheckNationalIDUnique();
    end;

    trigger OnModify()
    begin
        CheckMandatoryFields();
    end;

    trigger OnDelete()
    begin
        if HasLedgerEntries() then
            Error(HasLedgerEntriesErr, "No.");
    end;

    procedure AssistEdit(OldMember: Record "PEN Member"): Boolean
    var
        Member: Record "PEN Member";
        NoSeries: Codeunit "No. Series";
    begin
        Member := Rec;
        GetPensionSetup();
        PensionSetup.TestField("Member Nos.");
        if NoSeries.LookupRelatedNoSeries(PensionSetup."Member Nos.", OldMember."No. Series", Member."No. Series") then begin
            Member."No." := NoSeries.GetNextNo(Member."No. Series");
            Rec := Member;
            exit(true);
        end;
    end;

    /// <summary>
    /// Fills Employer No. (and so Scheme Code) when the record is filtered to one employer, for example a new member
    /// created from the Members action on the employer card. Filters set by a page link live in other filter groups.
    /// </summary>
    procedure SetEmployerFromFilter()
    var
        EmployerNo: Code[20];
        OriginalFilterGroup: Integer;
        FilterGroupNo: Integer;
    begin
        OriginalFilterGroup := FilterGroup();
        EmployerNo := '';
        FilterGroupNo := 0;
        repeat
            FilterGroup(FilterGroupNo);
            if GetFilter("Employer No.") <> '' then
                if GetRangeMin("Employer No.") = GetRangeMax("Employer No.") then
                    EmployerNo := GetRangeMin("Employer No.");
            FilterGroupNo += 1;
        until (EmployerNo <> '') or (FilterGroupNo > 4);
        FilterGroup(OriginalFilterGroup);

        if EmployerNo <> '' then
            Validate("Employer No.", EmployerNo);
    end;

    procedure GetFullName(): Text
    begin
        exit(DelChr("First Name" + ' ' + "Last Name", '<>', ' '));
    end;

    procedure GetAgeAt(AtDate: Date): Integer
    var
        Age: Integer;
    begin
        if ("Date of Birth" = 0D) or (AtDate = 0D) then
            exit(0);
        Age := Date2DMY(AtDate, 3) - Date2DMY("Date of Birth", 3);
        // Birthday not reached yet in the year of AtDate
        if (Date2DMY(AtDate, 2) < Date2DMY("Date of Birth", 2)) or
           ((Date2DMY(AtDate, 2) = Date2DMY("Date of Birth", 2)) and (Date2DMY(AtDate, 1) < Date2DMY("Date of Birth", 1)))
        then
            Age -= 1;
        exit(Age);
    end;

    procedure HasLedgerEntries(): Boolean
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
    begin
        if "No." = '' then
            exit(false);
        MemberLedgerEntry.SetRange("Member No.", "No.");
        exit(not MemberLedgerEntry.IsEmpty());
    end;

    local procedure CheckMandatoryFields()
    begin
        TestField("First Name");
        TestField("Last Name");
        TestField("National ID No.");
        TestField("Date of Birth");
        TestField("Employer No.");
        TestField("Date Joined");
        CheckAgeAtJoining();
        CheckPensionableSalary();
    end;

    local procedure CheckAgeAtJoining()
    var
        Age: Integer;
    begin
        if ("Date of Birth" = 0D) or ("Date Joined" = 0D) then
            exit;
        GetPensionSetup();
        PensionSetup.TestField("Min. Joining Age");
        PensionSetup.TestField("Max. Joining Age");
        Age := GetAgeAt("Date Joined");
        if (Age < PensionSetup."Min. Joining Age") or (Age > PensionSetup."Max. Joining Age") then
            Error(AgeOutOfRangeErr, PensionSetup."Min. Joining Age", PensionSetup."Max. Joining Age", "Date Joined", Age);
    end;

    local procedure CheckPensionableSalary()
    begin
        if "Pensionable Salary" <= 0 then
            Error(SalaryMustBePositiveErr);
    end;

    local procedure CheckNationalIDUnique()
    var
        Member: Record "PEN Member";
    begin
        if "National ID No." = '' then
            exit;
        Member.SetRange("National ID No.", "National ID No.");
        Member.SetFilter("No.", '<>%1', "No.");
        if Member.FindFirst() then
            Error(DuplicateNationalIDErr, "National ID No.", Member."No.");
    end;

    local procedure GetPensionSetup()
    begin
        if PensionSetupRead then
            exit;
        PensionSetup.Get();
        PensionSetupRead := true;
    end;
}
