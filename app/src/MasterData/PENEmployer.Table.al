table 50102 "PEN Employer"
{
    Caption = 'Pension Employer';
    DataClassification = CustomerContent;
    DataCaptionFields = "No.", Name;
    LookupPageId = "PEN Employer List";
    DrillDownPageId = "PEN Employer List";

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
                    NoSeries.TestManual(PensionSetup."Employer Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';
            NotBlank = true;
        }
        field(3; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            NotBlank = true;
            TableRelation = "PEN Scheme";

            trigger OnValidate()
            var
                Scheme: Record "PEN Scheme";
            begin
                if "Scheme Code" = xRec."Scheme Code" then
                    exit;
                if HasMembers() then
                    Error(CannotChangeSchemeErr, "No.");
                Scheme.Get("Scheme Code");
                Scheme.CheckNotBlocked();
            end;
        }
        field(4; "KRA PIN"; Code[20])
        {
            Caption = 'KRA PIN';
            NotBlank = true;

            trigger OnValidate()
            begin
                CheckKRAPINFormat("KRA PIN");
                CheckKRAPINUnique();
            end;
        }
        field(5; Email; Text[80])
        {
            Caption = 'Email';
            ExtendedDatatype = EMail;

            trigger OnValidate()
            var
                MailManagement: Codeunit "Mail Management";
            begin
                if Email <> '' then
                    MailManagement.CheckValidEmailAddress(Email);
            end;
        }
        field(6; Status; Enum "PEN Employer Status")
        {
            Caption = 'Status';
        }
        field(7; "Member Count"; Integer)
        {
            Caption = 'Member Count';
            FieldClass = FlowField;
            CalcFormula = count("PEN Member" where("Employer No." = field("No."), Status = const(Active)));
            Editable = false;
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
        key(KRAPIN; "KRA PIN")
        {
            Unique = true;
        }
        key(Scheme; "Scheme Code")
        {
        }
    }
    fieldgroups
    {
        fieldgroup(DropDown; "No.", Name, "Scheme Code", Status)
        {
        }
    }

    var
        PensionSetup: Record "PEN Pension Setup";
        PensionSetupRead: Boolean;
        CannotChangeSchemeErr: Label 'You cannot change the scheme of employer %1 because it has members.', Comment = '%1 = Employer No.';
        HasMembersErr: Label 'You cannot delete employer %1 because it has members.', Comment = '%1 = Employer No.';
        InvalidKRAPINErr: Label 'KRA PIN %1 is not valid. The format must be a letter, nine digits and a letter, for example A000000000Z.', Comment = '%1 = KRA PIN';
        DuplicateKRAPINErr: Label 'KRA PIN %1 is already used by employer %2.', Comment = '%1 = KRA PIN, %2 = Employer No.';

    trigger OnInsert()
    var
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            GetPensionSetup();
            PensionSetup.TestField("Employer Nos.");
            "No. Series" := PensionSetup."Employer Nos.";
            if NoSeries.AreRelated("No. Series", xRec."No. Series") then
                "No. Series" := xRec."No. Series";
            "No." := NoSeries.GetNextNo("No. Series");
        end;
        CheckMandatoryFields();
    end;

    trigger OnModify()
    begin
        CheckMandatoryFields();
    end;

    trigger OnDelete()
    begin
        if HasMembers() then
            Error(HasMembersErr, "No.");
    end;

    procedure AssistEdit(OldEmployer: Record "PEN Employer"): Boolean
    var
        Employer: Record "PEN Employer";
        NoSeries: Codeunit "No. Series";
    begin
        Employer := Rec;
        GetPensionSetup();
        PensionSetup.TestField("Employer Nos.");
        if NoSeries.LookupRelatedNoSeries(PensionSetup."Employer Nos.", OldEmployer."No. Series", Employer."No. Series") then begin
            Employer."No." := NoSeries.GetNextNo(Employer."No. Series");
            Rec := Employer;
            exit(true);
        end;
    end;

    /// <summary>
    /// Errors unless the employer is Active and its scheme is not blocked.
    /// </summary>
    procedure CheckCanAcceptContributions()
    var
        Scheme: Record "PEN Scheme";
    begin
        TestField(Status, Status::Active);
        Scheme.Get("Scheme Code");
        Scheme.CheckNotBlocked();
    end;

    procedure HasMembers(): Boolean
    var
        Member: Record "PEN Member";
    begin
        if "No." = '' then
            exit(false);
        Member.SetRange("Employer No.", "No.");
        exit(not Member.IsEmpty());
    end;

    local procedure CheckMandatoryFields()
    begin
        TestField(Name);
        TestField("Scheme Code");
        TestField("KRA PIN");
    end;

    local procedure CheckKRAPINFormat(KRAPIN: Code[20])
    var
        i: Integer;
    begin
        if KRAPIN = '' then
            exit;
        if StrLen(KRAPIN) <> 11 then
            Error(InvalidKRAPINErr, KRAPIN);
        if not IsLetter(KRAPIN[1]) or not IsLetter(KRAPIN[11]) then
            Error(InvalidKRAPINErr, KRAPIN);
        for i := 2 to 10 do
            if not (KRAPIN[i] in ['0' .. '9']) then
                Error(InvalidKRAPINErr, KRAPIN);
    end;

    local procedure IsLetter(Character: Char): Boolean
    begin
        exit(Character in ['A' .. 'Z']);
    end;

    local procedure CheckKRAPINUnique()
    var
        Employer: Record "PEN Employer";
    begin
        if "KRA PIN" = '' then
            exit;
        Employer.SetRange("KRA PIN", "KRA PIN");
        Employer.SetFilter("No.", '<>%1', "No.");
        if Employer.FindFirst() then
            Error(DuplicateKRAPINErr, "KRA PIN", Employer."No.");
    end;

    local procedure GetPensionSetup()
    begin
        if PensionSetupRead then
            exit;
        PensionSetup.Get();
        PensionSetupRead := true;
    end;
}
