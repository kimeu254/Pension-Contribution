page 50107 "PEN Generate Test Data"
{
    Caption = 'Generate Test Data';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Options';

                field(PeriodField; Period)
                {
                    ApplicationArea = All;
                    Caption = 'Period';
                    ToolTip = 'Specifies the contribution period to create batches for, in the format YYYY-MM.';
                }
                field(NoOfEmployersField; NoOfEmployers)
                {
                    ApplicationArea = All;
                    Caption = 'No. of Employers';
                    MinValue = 1;
                    ToolTip = 'Specifies how many employers to create (or reuse). One batch is created per employer.';
                }
                field(MembersPerEmployerField; MembersPerEmployer)
                {
                    ApplicationArea = All;
                    Caption = 'Members per Employer';
                    MinValue = 1;
                    ToolTip = 'Specifies how many members each employer has, which is also the number of lines in its batch.';
                }
                field(TotalLinesField; NoOfEmployers * MembersPerEmployer)
                {
                    ApplicationArea = All;
                    Caption = 'Approx. Queue Lines';
                    Editable = false;
                    ToolTip = 'Specifies the approximate number of queue lines that will be created.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if Period = '' then
            Period := CopyStr(Format(CalcDate('<-1M>', WorkDate()), 0, '<Year4>-<Month,2>'), 1, MaxStrLen(Period));
        if NoOfEmployers = 0 then
            NoOfEmployers := 50;
        if MembersPerEmployer = 0 then
            MembersPerEmployer := 40;
    end;

    // The dialog runs the generator itself on OK, so any action can open it with a plain RunObject.
    // An error (for example an invalid period) keeps the dialog open so the user can correct it.
    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        TestDataGenerator: Codeunit "PEN Test Data Generator";
    begin
        if CloseAction = Action::OK then
            TestDataGenerator.Generate(Period, NoOfEmployers, MembersPerEmployer);
        exit(true);
    end;

    var
        Period: Code[7];
        NoOfEmployers: Integer;
        MembersPerEmployer: Integer;
}
