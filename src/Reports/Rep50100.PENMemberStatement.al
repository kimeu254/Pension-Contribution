/// <summary>
/// Statement for one or more members over a date range: opening balance, each period's employee and employer
/// contributions with a running balance, totals, and the closing balance. One page per member.
/// </summary>
report 50100 "PEN Member Statement"
{
    ApplicationArea = All;
    Caption = 'Member Statement';
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = RDLCLayout;

    dataset
    {
        dataitem(Member; "PEN Member")
        {
            RequestFilterFields = "No.", "Employer No.", "Scheme Code";
            DataItemTableView = sorting("No.");

            column(CompanyName; CompanyProperty.DisplayName())
            {
            }
            column(MemberNo; "No.")
            {
            }
            column(MemberName; GetFullName())
            {
            }
            column(NationalIDNo; "National ID No.")
            {
            }
            column(EmployerNo; "Employer No.")
            {
            }
            column(EmployerName; EmployerName)
            {
            }
            column(SchemeCode; "Scheme Code")
            {
            }
            column(SchemeDescription; SchemeDescription)
            {
            }
            column(StartDateText; Format(StartDate))
            {
            }
            column(EndDateText; Format(EndDate))
            {
            }
            column(OpeningBalance; OpeningBalance)
            {
            }
            column(TotalEmployeeAmount; TotalEmployeeAmount)
            {
            }
            column(TotalEmployerAmount; TotalEmployerAmount)
            {
            }
            column(ClosingBalance; ClosingBalance)
            {
            }
            dataitem(PeriodLine; Integer)
            {
                DataItemTableView = sorting(Number);

                column(Period; CurrentPeriod)
                {
                }
                column(PostingDateText; Format(CurrentPostingDate))
                {
                }
                column(EmployeeAmount; CurrentEmployeeAmount)
                {
                }
                column(EmployerAmount; CurrentEmployerAmount)
                {
                }
                column(RunningBalance; RunningBalance)
                {
                }

                trigger OnPreDataItem()
                begin
                    // No periods in range gives an empty data item; the member's header, balances and totals still print.
                    SetRange(Number, 1, Periods.Count());
                    RunningBalance := OpeningBalance;
                end;

                trigger OnAfterGetRecord()
                begin
                    CurrentPeriod := Periods.Get(Number);
                    CurrentPostingDate := PostingDateByPeriod.Get(CurrentPeriod);
                    CurrentEmployeeAmount := EmployeeByPeriod.Get(CurrentPeriod);
                    CurrentEmployerAmount := EmployerByPeriod.Get(CurrentPeriod);
                    RunningBalance += CurrentEmployeeAmount + CurrentEmployerAmount;
                end;
            }

            trigger OnAfterGetRecord()
            begin
                LoadStatement(Member);
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';

                    field(StartDateField; StartDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Start Date';
                        ToolTip = 'Specifies the first date of the statement. The opening balance is the balance at the end of the previous day.';
                    }
                    field(EndDateField; EndDate)
                    {
                        ApplicationArea = All;
                        Caption = 'End Date';
                        ToolTip = 'Specifies the last date of the statement. The closing balance is the balance on this date.';
                    }
                }
            }
        }

        trigger OnOpenPage()
        begin
            if EndDate = 0D then
                EndDate := WorkDate();
            if StartDate = 0D then
                StartDate := CalcDate('<-CY>', EndDate);
        end;
    }

    rendering
    {
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = './src/Reports/Rep50100.PENMemberStatement.rdlc';
            Caption = 'Member Statement (RDLC)';
        }
    }

    labels
    {
        StatementTitleLbl = 'Member Statement';
        MemberNoLbl = 'Member No.';
        MemberNameLbl = 'Name';
        NationalIDLbl = 'National ID No.';
        EmployerLbl = 'Employer';
        SchemeLbl = 'Scheme';
        StatementPeriodLbl = 'Statement Period';
        ToLbl = 'to';
        PeriodLbl = 'Period';
        PostingDateLbl = 'Posting Date';
        EmployeeContributionLbl = 'Employee Contribution';
        EmployerContributionLbl = 'Employer Contribution';
        RunningBalanceLbl = 'Balance';
        OpeningBalanceLbl = 'Opening Balance';
        TotalsLbl = 'Total Contributions';
        ClosingBalanceLbl = 'Closing Balance';
        NoContributionsLbl = 'No contributions in this period.';
    }

    trigger OnPreReport()
    begin
        if StartDate = 0D then
            Error(StartDateMissingErr);
        if EndDate = 0D then
            Error(EndDateMissingErr);
        if StartDate > EndDate then
            Error(StartAfterEndErr, StartDate, EndDate);
    end;

    var
        Periods: List of [Code[7]];
        PostingDateByPeriod: Dictionary of [Code[7], Date];
        EmployeeByPeriod: Dictionary of [Code[7], Decimal];
        EmployerByPeriod: Dictionary of [Code[7], Decimal];
        StartDate: Date;
        EndDate: Date;
        EmployerName: Text[100];
        SchemeDescription: Text[100];
        OpeningBalance: Decimal;
        ClosingBalance: Decimal;
        TotalEmployeeAmount: Decimal;
        TotalEmployerAmount: Decimal;
        CurrentPeriod: Code[7];
        CurrentPostingDate: Date;
        CurrentEmployeeAmount: Decimal;
        CurrentEmployerAmount: Decimal;
        RunningBalance: Decimal;
        StartDateMissingErr: Label 'Enter a start date.';
        EndDateMissingErr: Label 'Enter an end date.';
        StartAfterEndErr: Label 'The start date %1 is after the end date %2.', Comment = '%1 = start date, %2 = end date';

    /// <summary>
    /// Sets the date range, so the report can be run from code (for example from a test) without the request page.
    /// </summary>
    procedure SetDateRange(NewStartDate: Date; NewEndDate: Date)
    begin
        StartDate := NewStartDate;
        EndDate := NewEndDate;
    end;

    local procedure LoadStatement(StatementMember: Record "PEN Member")
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
    begin
        Clear(Periods);
        Clear(PostingDateByPeriod);
        Clear(EmployeeByPeriod);
        Clear(EmployerByPeriod);
        TotalEmployeeAmount := 0;
        TotalEmployerAmount := 0;
        LoadMasterData(StatementMember);

        // Opening and closing come from the Balance FlowField, independently of the period lines,
        // so "opening + contributions = closing" is a real check rather than true by construction.
        OpeningBalance := GetBalanceUpTo(StatementMember."No.", StartDate - 1);
        ClosingBalance := GetBalanceUpTo(StatementMember."No.", EndDate);

        MemberLedgerEntry.SetCurrentKey("Member No.", "Posting Date", "Entry Type");
        MemberLedgerEntry.SetRange("Member No.", StatementMember."No.");
        MemberLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        MemberLedgerEntry.SetLoadFields(Period, "Posting Date", "Entry Type", Amount);
        if MemberLedgerEntry.FindSet() then
            repeat
                // Entries come in posting date order, so periods are added in date order.
                if not Periods.Contains(MemberLedgerEntry.Period) then begin
                    Periods.Add(MemberLedgerEntry.Period);
                    PostingDateByPeriod.Add(MemberLedgerEntry.Period, MemberLedgerEntry."Posting Date");
                    EmployeeByPeriod.Add(MemberLedgerEntry.Period, 0);
                    EmployerByPeriod.Add(MemberLedgerEntry.Period, 0);
                end;
                case MemberLedgerEntry."Entry Type" of
                    MemberLedgerEntry."Entry Type"::"Employee Contribution":
                        begin
                            EmployeeByPeriod.Set(MemberLedgerEntry.Period, EmployeeByPeriod.Get(MemberLedgerEntry.Period) + MemberLedgerEntry.Amount);
                            TotalEmployeeAmount += MemberLedgerEntry.Amount;
                        end;
                    MemberLedgerEntry."Entry Type"::"Employer Contribution":
                        begin
                            EmployerByPeriod.Set(MemberLedgerEntry.Period, EmployerByPeriod.Get(MemberLedgerEntry.Period) + MemberLedgerEntry.Amount);
                            TotalEmployerAmount += MemberLedgerEntry.Amount;
                        end;
                end;
            until MemberLedgerEntry.Next() = 0;
    end;

    local procedure LoadMasterData(StatementMember: Record "PEN Member")
    var
        Employer: Record "PEN Employer";
        Scheme: Record "PEN Scheme";
    begin
        EmployerName := '';
        SchemeDescription := '';
        Employer.SetLoadFields(Name);
        if Employer.Get(StatementMember."Employer No.") then
            EmployerName := Employer.Name;
        Scheme.SetLoadFields(Description);
        if Scheme.Get(StatementMember."Scheme Code") then
            SchemeDescription := Scheme.Description;
    end;

    local procedure GetBalanceUpTo(MemberNo: Code[20]; BalanceDate: Date): Decimal
    var
        BalanceMember: Record "PEN Member";
    begin
        BalanceMember.SetLoadFields("No.");
        BalanceMember.Get(MemberNo);
        BalanceMember.SetRange("Date Filter", 0D, BalanceDate);
        BalanceMember.CalcFields(Balance);
        exit(BalanceMember.Balance);
    end;
}
