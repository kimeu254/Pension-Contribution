page 50113 "PEN Pension Activities"
{
    Caption = 'Activities';
    PageType = CardPart;
    RefreshOnActivate = true;
    ShowFilter = false;
    SourceTable = "PEN Pension Cue";

    layout
    {
        area(Content)
        {
            cuegroup(ContributionQueue)
            {
                Caption = 'Contribution Queue';

                field("Pending Lines"; Rec."Pending Lines")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Contribution Queue";
                    ToolTip = 'Specifies the number of contribution lines waiting to be processed.';
                }
                field("Processing Lines"; Rec."Processing Lines")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Contribution Queue";
                    ToolTip = 'Specifies the number of contribution lines being processed by a background run right now.';
                }
                field("Failed Lines"; Rec."Failed Lines")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Contribution Queue";
                    StyleExpr = FailedStyle;
                    ToolTip = 'Specifies the number of contribution lines that failed and will be retried by the next run.';
                }
                field("Dead Letter Lines"; Rec."Dead Letter Lines")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Contribution Queue";
                    StyleExpr = DeadLetterStyle;
                    ToolTip = 'Specifies the number of contribution lines that failed more than the maximum retry attempts and need a manual Reprocess.';
                }
            }
            cuegroup(QuickActions)
            {
                Caption = 'Actions';

                actions
                {
                    action(ImportFile)
                    {
                        ApplicationArea = All;
                        Caption = 'Import Contribution File';
                        Image = TileNew;
                        RunObject = page "PEN Contribution Batches";
                        ToolTip = 'Open the contribution batches to import a JSON or CSV file.';
                    }
                    action(Setup)
                    {
                        ApplicationArea = All;
                        Caption = 'Pension Setup';
                        Image = TileSettings;
                        RunObject = page "PEN Pension Setup";
                        ToolTip = 'Set up number series, remittance rules, background processing and test data.';
                    }
                }
            }
            cuegroup(Batches)
            {
                Caption = 'Contribution Batches';

                field("Open Batches"; Rec."Open Batches")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Contribution Batches";
                    ToolTip = 'Specifies the number of batches that are received or in progress.';
                }
                field("Batches with Errors"; Rec."Batches with Errors")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Contribution Batches";
                    StyleExpr = BatchesWithErrorsStyle;
                    ToolTip = 'Specifies the number of batches that finished with Dead Letter lines.';
                }
            }
            cuegroup(Membership)
            {
                Caption = 'Membership';

                field("Active Employers"; Rec."Active Employers")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Employer List";
                    ToolTip = 'Specifies the number of active employers.';
                }
                field("Active Members"; Rec."Active Members")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "PEN Member List";
                    ToolTip = 'Specifies the number of active members.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;

    trigger OnAfterGetRecord()
    begin
        FailedStyle := GetWarningStyle(Rec."Failed Lines", 'Ambiguous');
        DeadLetterStyle := GetWarningStyle(Rec."Dead Letter Lines", 'Unfavorable');
        BatchesWithErrorsStyle := GetWarningStyle(Rec."Batches with Errors", 'Unfavorable');
    end;

    var
        FailedStyle: Text;
        DeadLetterStyle: Text;
        BatchesWithErrorsStyle: Text;

    local procedure GetWarningStyle(CueValue: Integer; WarningStyle: Text): Text
    begin
        if CueValue > 0 then
            exit(WarningStyle);
        exit('Favorable');
    end;
}
