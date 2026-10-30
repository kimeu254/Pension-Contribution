page 50106 "PEN Contribution Batches"
{
    ApplicationArea = All;
    Caption = 'Contribution Batches';
    PageType = List;
    SourceTable = "PEN Contribution Batch";
    UsageCategory = Lists;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Batches)
            {
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the number of the batch.';
                }
                field("Message ID"; Rec."Message ID")
                {
                    ToolTip = 'Specifies the employer''s message ID. A message ID can only be received once.';
                }
                field("Employer No."; Rec."Employer No.")
                {
                    ToolTip = 'Specifies the employer that sent the batch.';
                }
                field(Period; Rec.Period)
                {
                    ToolTip = 'Specifies the contribution period, for example 2026-10.';
                }
                field("Received Date"; Rec."Received Date")
                {
                    ToolTip = 'Specifies the date the employer remitted the batch. Used to decide whether a late penalty applies.';
                }
                field("Control Total"; Rec."Control Total")
                {
                    ToolTip = 'Specifies the total the employer declared for the batch. It must equal the sum of the line amounts.';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies the processing status of the batch.';
                }
                field("No. of Lines"; Rec."No. of Lines")
                {
                    ToolTip = 'Specifies the number of member lines in the batch. Choose the value to see the lines.';
                }
                field("Pending Lines"; Rec."Pending Lines")
                {
                    ToolTip = 'Specifies the number of lines waiting to be processed.';
                }
                field("Posted Lines"; Rec."Posted Lines")
                {
                    ToolTip = 'Specifies the number of lines posted to the member ledger and general ledger.';
                }
                field("Failed Lines"; Rec."Failed Lines")
                {
                    ToolTip = 'Specifies the number of lines that failed and will be retried.';
                }
                field("Dead Letter Lines"; Rec."Dead Letter Lines")
                {
                    ToolTip = 'Specifies the number of lines that failed more than the maximum retry attempts and need a manual reprocess.';
                }
                field("Total Employee Amount"; Rec."Total Employee Amount")
                {
                    ToolTip = 'Specifies the total employee contributions in the batch.';
                    Visible = false;
                }
                field("Total Employer Amount"; Rec."Total Employer Amount")
                {
                    ToolTip = 'Specifies the total employer contributions in the batch.';
                    Visible = false;
                }
                field(Source; Rec.Source)
                {
                    ToolTip = 'Specifies how the batch was received.';
                }
                field("File Name"; Rec."File Name")
                {
                    ToolTip = 'Specifies the name of the uploaded file.';
                    Visible = false;
                }
                field("Created By"; Rec."Created By")
                {
                    ToolTip = 'Specifies the user who loaded the batch.';
                    Visible = false;
                }
                field("Created At"; Rec."Created At")
                {
                    ToolTip = 'Specifies when the batch was loaded.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportFile)
            {
                Caption = 'Import File';
                Image = Import;
                ToolTip = 'Load a contribution batch from a JSON or CSV file. The batch is checked for structure only; the lines are validated and posted in the background.';

                trigger OnAction()
                var
                    Batch: Record "PEN Contribution Batch";
                    Intake: Codeunit "PEN Contribution Intake";
                    BatchNo: Code[20];
                begin
                    BatchNo := Intake.ImportFromFile();
                    if BatchNo = '' then
                        exit;
                    Batch.Get(BatchNo);
                    Batch.CalcFields("No. of Lines");
                    Message(BatchCreatedMsg, Batch."No.", Batch."Message ID", Batch."No. of Lines");
                    Rec := Batch;
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(Lines)
            {
                Caption = 'Lines';
                Image = AllLines;
                RunObject = page "PEN Contribution Queue";
                RunPageLink = "Batch No." = field("No.");
                RunPageView = sorting("Batch No.", "Line No.");
                ToolTip = 'View the member lines of the batch.';
            }
        }
        area(Promoted)
        {
            actionref(ImportFile_Promoted; ImportFile)
            {
            }
            actionref(Lines_Promoted; Lines)
            {
            }
        }
    }

    var
        BatchCreatedMsg: Label 'Batch %1 (message ID %2) was received with %3 lines. The lines are Pending and will be processed in the background.', Comment = '%1 = Batch No., %2 = Message ID, %3 = number of lines';
}
