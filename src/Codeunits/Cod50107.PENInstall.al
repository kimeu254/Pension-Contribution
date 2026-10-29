codeunit 50107 "PEN Install"
{
    Subtype = Install;

    var
        MemberNosTok: Label 'PEN-MEM', Locked = true;
        EmployerNosTok: Label 'PEN-EMP', Locked = true;
        BatchNosTok: Label 'PEN-BATCH', Locked = true;
        MemberNosDescTxt: Label 'Pension Members';
        EmployerNosDescTxt: Label 'Pension Employers';
        BatchNosDescTxt: Label 'Pension Contribution Batches';

    trigger OnInstallAppPerCompany()
    begin
        InitializeSetup();
    end;

    // Install code only runs for companies that exist at install time; this covers companies created later.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", OnCompanyInitialize, '', false, false)]
    local procedure OnCompanyInitialize()
    begin
        InitializeSetup();
    end;

    /// <summary>
    /// Creates the setup record and default number series if they are missing. Safe to call repeatedly.
    /// </summary>
    procedure InitializeSetup()
    var
        PensionSetup: Record "PEN Pension Setup";
        Changed: Boolean;
    begin
        if not PensionSetup.Get() then begin
            PensionSetup.Init();
            PensionSetup."Late Penalty %" := 5;
            PensionSetup.Insert(true);
        end;

        if PensionSetup."Member Nos." = '' then begin
            PensionSetup."Member Nos." := CreateNoSeries(MemberNosTok, MemberNosDescTxt, 'MEM00001');
            Changed := true;
        end;
        if PensionSetup."Employer Nos." = '' then begin
            PensionSetup."Employer Nos." := CreateNoSeries(EmployerNosTok, EmployerNosDescTxt, 'EMP0001');
            Changed := true;
        end;
        if PensionSetup."Contribution Batch Nos." = '' then begin
            PensionSetup."Contribution Batch Nos." := CreateNoSeries(BatchNosTok, BatchNosDescTxt, 'PCB000001');
            Changed := true;
        end;
        if Changed then
            PensionSetup.Modify(true);
    end;

    local procedure CreateNoSeries(SeriesCode: Code[20]; Description: Text[100]; StartingNo: Code[20]): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if NoSeries.Get(SeriesCode) then
            exit(SeriesCode);

        NoSeries.Init();
        NoSeries.Code := SeriesCode;
        NoSeries.Description := Description;
        NoSeries."Default Nos." := true;
        NoSeries."Manual Nos." := true;
        NoSeries.Insert(true);

        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := SeriesCode;
        NoSeriesLine."Line No." := 10000;
        NoSeriesLine."Starting No." := StartingNo;
        NoSeriesLine."Increment-by No." := 1;
        NoSeriesLine.Insert(true);
        exit(SeriesCode);
    end;
}
