/// <summary>
/// Posts the validated lines of one processing chunk to the member ledger and the general ledger.
/// Run with Codeunit.Run so that a posting error rolls back the whole chunk and the processor can record it.
/// </summary>
codeunit 50105 "PEN Contribution Posting"
{
    TableNo = "PEN Contribution Batch";

    var
        TempLineToPost: Record "PEN Contribution Queue" temporary;
        NotImplementedErr: Label 'Posting is not implemented yet (Step 4).';

    trigger OnRun()
    begin
        PostLines(Rec);
    end;

    /// <summary>
    /// Sets the validated lines to post. Call before running the codeunit.
    /// </summary>
    procedure SetLinesToPost(var TempValidLine: Record "PEN Contribution Queue" temporary)
    begin
        TempLineToPost.Copy(TempValidLine, true);
    end;

    local procedure PostLines(var Batch: Record "PEN Contribution Batch")
    begin
        // TODO Step 4: member ledger entries, summarised G/L pair per scheme, late penalty, lines -> Posted.
        // Until then every valid line fails here, so no line is ever marked Posted without ledger entries.
        Error(NotImplementedErr);
    end;
}
