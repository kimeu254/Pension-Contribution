/// <summary>
/// Reads a contribution batch in CSV format into temporary records. The first row is the header; columns are
/// found by name, so their order does not matter. Batch details are repeated on every row and must be identical.
/// </summary>
codeunit 50102 "PEN CSV Batch Reader"
{
    var
        Intake: Codeunit "PEN Contribution Intake";
        NoDataRowsErr: Label 'The file has no data rows. The first row must be the column headings, followed by one row per member.';
        MissingColumnErr: Label 'The column "%1" is missing from the heading row.', Comment = '%1 = column name';
        BatchValueDiffersErr: Label 'Row %1: %2 is "%3" but the first data row has "%4". All rows in a file must belong to the same batch.', Comment = '%1 = row number, %2 = column name, %3 = value on this row, %4 = value on the first row';
        MessageIdColTok: Label 'messageId', Locked = true;
        EmployerNoColTok: Label 'employerNo', Locked = true;
        PeriodColTok: Label 'period', Locked = true;
        ReceivedDateColTok: Label 'receivedDate', Locked = true;
        ControlTotalColTok: Label 'controlTotal', Locked = true;
        MemberNoColTok: Label 'memberNo', Locked = true;
        EmployeeAmountColTok: Label 'employeeAmount', Locked = true;
        EmployerAmountColTok: Label 'employerAmount', Locked = true;

    procedure ReadBatch(var CsvInStream: InStream; var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Contribution Queue" temporary)
    var
        TempCSVBuffer: Record "CSV Buffer" temporary;
        Columns: Dictionary of [Text, Integer];
        LastRowNo: Integer;
        RowNo: Integer;
        FirstDataRowNo: Integer;
        LineNo: Integer;
    begin
        TempCSVBuffer.LoadDataFromStream(CsvInStream, ',');
        if TempCSVBuffer.FindLast() then
            LastRowNo := TempCSVBuffer."Line No.";
        if LastRowNo < 2 then
            Error(NoDataRowsErr);

        ReadHeadingRow(TempCSVBuffer, Columns);

        for RowNo := 2 to LastRowNo do
            if not IsBlankRow(TempCSVBuffer, RowNo) then begin
                LineNo += 1;
                if LineNo = 1 then begin
                    FirstDataRowNo := RowNo;
                    ReadBatchColumns(TempCSVBuffer, Columns, RowNo, TempBatch);
                end else
                    CheckBatchColumnsMatch(TempCSVBuffer, Columns, RowNo, FirstDataRowNo);

                TempLine.Init();
                TempLine."Entry No." := LineNo;
                TempLine."Line No." := LineNo;
                TempLine."Member No." := CopyStr(GetText(TempCSVBuffer, Columns, RowNo, MemberNoColTok, MaxStrLen(TempLine."Member No.")), 1, MaxStrLen(TempLine."Member No."));
                TempLine."Employee Amount" := Intake.ParseDecimal(GetCell(TempCSVBuffer, Columns, RowNo, EmployeeAmountColTok), EmployeeAmountColTok, RowNo);
                TempLine."Employer Amount" := Intake.ParseDecimal(GetCell(TempCSVBuffer, Columns, RowNo, EmployerAmountColTok), EmployerAmountColTok, RowNo);
                TempLine.Insert();
            end;

        if LineNo = 0 then
            Error(NoDataRowsErr);
    end;

    local procedure ReadHeadingRow(var TempCSVBuffer: Record "CSV Buffer" temporary; var Columns: Dictionary of [Text, Integer])
    var
        ColumnName: Text;
    begin
        TempCSVBuffer.SetRange("Line No.", 1);
        if TempCSVBuffer.FindSet() then
            repeat
                ColumnName := LowerCase(TempCSVBuffer.Value.Trim());
                if (ColumnName <> '') and not Columns.ContainsKey(ColumnName) then
                    Columns.Add(ColumnName, TempCSVBuffer."Field No.");
            until TempCSVBuffer.Next() = 0;
        TempCSVBuffer.SetRange("Line No.");

        CheckColumnExists(Columns, MessageIdColTok);
        CheckColumnExists(Columns, EmployerNoColTok);
        CheckColumnExists(Columns, PeriodColTok);
        CheckColumnExists(Columns, ReceivedDateColTok);
        CheckColumnExists(Columns, ControlTotalColTok);
        CheckColumnExists(Columns, MemberNoColTok);
        CheckColumnExists(Columns, EmployeeAmountColTok);
        CheckColumnExists(Columns, EmployerAmountColTok);
    end;

    local procedure ReadBatchColumns(var TempCSVBuffer: Record "CSV Buffer" temporary; Columns: Dictionary of [Text, Integer]; RowNo: Integer; var TempBatch: Record "PEN Contribution Batch" temporary)
    begin
        TempBatch.Init();
        TempBatch."Message ID" := CopyStr(GetText(TempCSVBuffer, Columns, RowNo, MessageIdColTok, MaxStrLen(TempBatch."Message ID")), 1, MaxStrLen(TempBatch."Message ID"));
        TempBatch."Employer No." := CopyStr(GetText(TempCSVBuffer, Columns, RowNo, EmployerNoColTok, MaxStrLen(TempBatch."Employer No.")), 1, MaxStrLen(TempBatch."Employer No."));
        TempBatch.Period := CopyStr(GetText(TempCSVBuffer, Columns, RowNo, PeriodColTok, MaxStrLen(TempBatch.Period)), 1, MaxStrLen(TempBatch.Period));
        TempBatch."Received Date" := Intake.ParseDate(GetCell(TempCSVBuffer, Columns, RowNo, ReceivedDateColTok), ReceivedDateColTok, RowNo);
        TempBatch."Control Total" := Intake.ParseDecimal(GetCell(TempCSVBuffer, Columns, RowNo, ControlTotalColTok), ControlTotalColTok, RowNo);
        TempBatch.Insert();
    end;

    local procedure CheckBatchColumnsMatch(var TempCSVBuffer: Record "CSV Buffer" temporary; Columns: Dictionary of [Text, Integer]; RowNo: Integer; FirstDataRowNo: Integer)
    begin
        CheckColumnMatchesFirstRow(TempCSVBuffer, Columns, RowNo, FirstDataRowNo, MessageIdColTok);
        CheckColumnMatchesFirstRow(TempCSVBuffer, Columns, RowNo, FirstDataRowNo, EmployerNoColTok);
        CheckColumnMatchesFirstRow(TempCSVBuffer, Columns, RowNo, FirstDataRowNo, PeriodColTok);
        CheckColumnMatchesFirstRow(TempCSVBuffer, Columns, RowNo, FirstDataRowNo, ReceivedDateColTok);
        CheckColumnMatchesFirstRow(TempCSVBuffer, Columns, RowNo, FirstDataRowNo, ControlTotalColTok);
    end;

    local procedure CheckColumnMatchesFirstRow(var TempCSVBuffer: Record "CSV Buffer" temporary; Columns: Dictionary of [Text, Integer]; RowNo: Integer; FirstDataRowNo: Integer; ColumnName: Text)
    var
        Value: Text;
        FirstRowValue: Text;
    begin
        Value := GetCell(TempCSVBuffer, Columns, RowNo, ColumnName);
        FirstRowValue := GetCell(TempCSVBuffer, Columns, FirstDataRowNo, ColumnName);
        if Value <> FirstRowValue then
            Error(BatchValueDiffersErr, RowNo, ColumnName, Value, FirstRowValue);
    end;

    local procedure GetText(var TempCSVBuffer: Record "CSV Buffer" temporary; Columns: Dictionary of [Text, Integer]; RowNo: Integer; ColumnName: Text; MaxLength: Integer): Text
    var
        Value: Text;
    begin
        Value := GetCell(TempCSVBuffer, Columns, RowNo, ColumnName);
        Intake.CheckValue(Value, ColumnName, MaxLength, RowNo);
        exit(Value);
    end;

    local procedure GetCell(var TempCSVBuffer: Record "CSV Buffer" temporary; Columns: Dictionary of [Text, Integer]; RowNo: Integer; ColumnName: Text): Text
    begin
        if not TempCSVBuffer.Get(RowNo, Columns.Get(LowerCase(ColumnName))) then
            exit('');
        exit(TempCSVBuffer.Value.Trim());
    end;

    local procedure IsBlankRow(var TempCSVBuffer: Record "CSV Buffer" temporary; RowNo: Integer): Boolean
    var
        IsBlank: Boolean;
    begin
        IsBlank := true;
        TempCSVBuffer.SetRange("Line No.", RowNo);
        if TempCSVBuffer.FindSet() then
            repeat
                if TempCSVBuffer.Value.Trim() <> '' then
                    IsBlank := false;
            until (TempCSVBuffer.Next() = 0) or not IsBlank;
        TempCSVBuffer.SetRange("Line No.");
        exit(IsBlank);
    end;

    local procedure CheckColumnExists(Columns: Dictionary of [Text, Integer]; ColumnName: Text)
    begin
        if not Columns.ContainsKey(LowerCase(ColumnName)) then
            Error(MissingColumnErr, ColumnName);
    end;
}
