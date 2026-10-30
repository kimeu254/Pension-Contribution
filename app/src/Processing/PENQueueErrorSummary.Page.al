page 50114 "PEN Queue Error Summary"
{
    Caption = 'Most Common Errors';
    PageType = ListPart;
    SourceTable = "PEN Error Summary Buffer";
    SourceTableTemporary = true;
    SourceTableView = sorting("Line Count") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Errors)
            {
                field("Error Pattern"; Rec."Error Pattern")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the error, with numbers replaced by # so that the same error for different members or amounts is counted together.';
                }
                field("Line Count"; Rec."Line Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many failed and dead-letter lines have this error.';
                }
                field("Failed Lines"; Rec."Failed Lines")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many of the lines are Failed and will be retried.';
                }
                field("Dead Letter Lines"; Rec."Dead Letter Lines")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many of the lines are in Dead Letter and need a manual Reprocess.';
                }
                field("Example Error"; Rec."Example Error")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the full text of one of the errors.';
                }
                field("Last Seen At"; Rec."Last Seen At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the error last occurred.';
                }
            }
        }
    }

    /// <summary>
    /// Rebuilds the list from the current Failed and Dead Letter queue lines.
    /// </summary>
    procedure Load()
    var
        QueueLine: Record "PEN Contribution Queue";
        EntryNoByPattern: Dictionary of [Text, Integer];
        ErrorPattern: Text[250];
        NextEntryNo: Integer;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        QueueLine.SetCurrentKey(Status, "Batch No.");
        QueueLine.SetFilter(Status, '%1|%2', QueueLine.Status::Failed, QueueLine.Status::"Dead Letter");
        QueueLine.SetLoadFields(Status, "Last Error", "Last Attempt At");
        if QueueLine.FindSet() then
            repeat
                ErrorPattern := GetErrorPattern(QueueLine."Last Error");
                if EntryNoByPattern.ContainsKey(ErrorPattern) then
                    Rec.Get(EntryNoByPattern.Get(ErrorPattern))
                else begin
                    NextEntryNo += 1;
                    EntryNoByPattern.Add(ErrorPattern, NextEntryNo);
                    Rec.Init();
                    Rec."Entry No." := NextEntryNo;
                    Rec."Error Pattern" := ErrorPattern;
                    Rec."Example Error" := QueueLine."Last Error";
                    Rec.Insert();
                end;
                Rec."Line Count" += 1;
                if QueueLine.Status = QueueLine.Status::Failed then
                    Rec."Failed Lines" += 1
                else
                    Rec."Dead Letter Lines" += 1;
                if QueueLine."Last Attempt At" > Rec."Last Seen At" then
                    Rec."Last Seen At" := QueueLine."Last Attempt At";
                Rec.Modify();
            until QueueLine.Next() = 0;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Replaces each run of digits with a single '#', so errors that differ only in member numbers or amounts match.
    /// </summary>
    local procedure GetErrorPattern(ErrorText: Text): Text[250]
    var
        Pattern: TextBuilder;
        i: Integer;
        InDigits: Boolean;
    begin
        for i := 1 to StrLen(ErrorText) do
            if ErrorText[i] in ['0' .. '9'] then begin
                if not InDigits then
                    Pattern.Append('#');
                InDigits := true;
            end else begin
                Pattern.Append(ErrorText[i]);
                InDigits := false;
            end;
        exit(CopyStr(Pattern.ToText(), 1, 250));
    end;
}
