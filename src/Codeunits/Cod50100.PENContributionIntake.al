/// <summary>
/// Single entry point for receiving contribution batches. File upload, the API and the test data generator
/// all end in CreateBatch, so every route gets the same structural checks.
/// Intake only checks the shape of the data; business validation happens in background processing.
/// </summary>
codeunit 50100 "PEN Contribution Intake"
{
    var
        SelectFileTxt: Label 'Select a contribution file';
        FileFilterTxt: Label 'Contribution files (*.json;*.csv)|*.json;*.csv', Locked = true;
        UnsupportedFileErr: Label 'The file %1 is not supported. Upload a .json or .csv file.', Comment = '%1 = file name';
        MissingValueErr: Label '%1 is missing%2.', Comment = '%1 = element name, %2 = line context';
        ValueTooLongErr: Label '%1 "%2" is longer than the maximum of %3 characters%4.', Comment = '%1 = element name, %2 = value, %3 = maximum length, %4 = line context';
        InvalidDecimalErr: Label '%1 "%2" is not a valid amount%3. Use a decimal point, for example 6000.00.', Comment = '%1 = element name, %2 = value, %3 = line context';
        InvalidDateErr: Label '%1 "%2" is not a valid date%3. Use the format YYYY-MM-DD.', Comment = '%1 = element name, %2 = value, %3 = line context';
        InvalidPeriodErr: Label 'Period "%1" is not valid. Use the format YYYY-MM, for example 2026-10.', Comment = '%1 = period';
        NegativeAmountErr: Label '%1 cannot be negative%2.', Comment = '%1 = field caption, %2 = line context';
        ControlTotalNotPositiveErr: Label 'The control total of batch %1 must be greater than zero.', Comment = '%1 = Message ID';
        NoLinesErr: Label 'Batch %1 has no lines.', Comment = '%1 = Message ID';
        DuplicateMessageErr: Label 'Message ID %1 has already been received in batch %2. The same file cannot be loaded twice.', Comment = '%1 = Message ID, %2 = Batch No.';
        ControlTotalMismatchErr: Label 'Batch %1 was rejected: the line amounts add up to %2 but the control total is %3 (difference %4).', Comment = '%1 = Message ID, %2 = sum of lines, %3 = control total, %4 = difference';
        LineContextTxt: Label ' on line %1', Comment = '%1 = line number';

    /// <summary>
    /// Asks the user for a JSON or CSV file and creates a batch from it.
    /// </summary>
    /// <returns>The new batch number, or blank if the user cancelled.</returns>
    procedure ImportFromFile(): Code[20]
    var
        FileInStream: InStream;
        FileName: Text;
    begin
        if not UploadIntoStream(SelectFileTxt, '', FileFilterTxt, FileName, FileInStream) then
            exit('');
        exit(ImportStream(FileInStream, FileName));
    end;

    /// <summary>
    /// Creates a batch from a JSON or CSV stream; the format is chosen by the file extension.
    /// </summary>
    procedure ImportStream(var FileInStream: InStream; FileName: Text): Code[20]
    var
        TempBatch: Record "PEN Contribution Batch" temporary;
        TempLine: Record "PEN Contribution Queue" temporary;
        FileManagement: Codeunit "File Management";
        JsonBatchReader: Codeunit "PEN JSON Batch Reader";
        CsvBatchReader: Codeunit "PEN CSV Batch Reader";
    begin
        case LowerCase(FileManagement.GetExtension(FileName)) of
            'json':
                begin
                    JsonBatchReader.ReadBatch(FileInStream, TempBatch, TempLine);
                    TempBatch.Source := TempBatch.Source::"JSON File";
                end;
            'csv':
                begin
                    CsvBatchReader.ReadBatch(FileInStream, TempBatch, TempLine);
                    TempBatch.Source := TempBatch.Source::"CSV File";
                end;
            else
                Error(UnsupportedFileErr, FileName);
        end;
        TempBatch."File Name" := CopyStr(FileName, 1, MaxStrLen(TempBatch."File Name"));
        exit(CreateBatch(TempBatch, TempLine));
    end;

    /// <summary>
    /// Runs the structural checks and, if they pass, stores the batch and its lines with status Pending.
    /// All or nothing: any error leaves no batch behind.
    /// </summary>
    /// <param name="TempBatch">The batch header as read from the source. Source and File Name are kept.</param>
    /// <param name="TempLine">The lines as read from the source.</param>
    /// <returns>The new batch number.</returns>
    procedure CreateBatch(var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Contribution Queue" temporary): Code[20]
    var
        Batch: Record "PEN Contribution Batch";
        QueueLine: Record "PEN Contribution Queue";
        LineTotal: Decimal;
        LineNo: Integer;
    begin
        CheckBatchHeader(TempBatch);
        CheckMessageIDNotReceived(TempBatch."Message ID");

        TempLine.Reset();
        if not TempLine.FindSet() then
            Error(NoLinesErr, TempBatch."Message ID");
        repeat
            CheckLine(TempLine);
            LineTotal += TempLine."Employee Amount" + TempLine."Employer Amount";
        until TempLine.Next() = 0;

        if Round(LineTotal) <> Round(TempBatch."Control Total") then
            Error(ControlTotalMismatchErr, TempBatch."Message ID", LineTotal, TempBatch."Control Total", TempBatch."Control Total" - LineTotal);

        Batch.Init();
        Batch.TransferFields(TempBatch);
        Batch."No." := '';
        Batch.Status := Batch.Status::Received;
        Batch."Created By" := CopyStr(UserId(), 1, MaxStrLen(Batch."Created By"));
        Batch."Created At" := CurrentDateTime();
        Batch.Insert(true);

        TempLine.FindSet();
        repeat
            LineNo += 1;
            QueueLine.Init();
            QueueLine.TransferFields(TempLine);
            QueueLine."Entry No." := 0;
            QueueLine."Batch No." := Batch."No.";
            QueueLine."Line No." := LineNo;
            QueueLine."Employer No." := Batch."Employer No.";
            QueueLine.Period := Batch.Period;
            QueueLine.Status := QueueLine.Status::Pending;
            QueueLine."Retry Count" := 0;
            QueueLine."Last Error" := '';
            QueueLine.Insert();
        until TempLine.Next() = 0;

        OnAfterCreateBatch(Batch);
        exit(Batch."No.");
    end;

    /// <summary>
    /// Returns the first day of a period in the format YYYY-MM; errors if the period is not valid.
    /// </summary>
    procedure GetPeriodStartDate(Period: Code[7]): Date
    var
        Year: Integer;
        Month: Integer;
    begin
        if (StrLen(Period) <> 7) or (CopyStr(Period, 5, 1) <> '-') then
            Error(InvalidPeriodErr, Period);
        if not Evaluate(Year, CopyStr(Period, 1, 4)) then
            Error(InvalidPeriodErr, Period);
        if not Evaluate(Month, CopyStr(Period, 6, 2)) then
            Error(InvalidPeriodErr, Period);
        if (Year < 1900) or (Month < 1) or (Month > 12) then
            Error(InvalidPeriodErr, Period);
        exit(DMY2Date(1, Month, Year));
    end;

    // Parsing helpers shared by the JSON and CSV readers, so both formats report errors the same way.

    procedure CheckValue(Value: Text; ElementName: Text; MaxLength: Integer; LineNo: Integer)
    begin
        if Value = '' then
            Error(MissingValueErr, ElementName, GetLineContext(LineNo));
        if StrLen(Value) > MaxLength then
            Error(ValueTooLongErr, ElementName, Value, MaxLength, GetLineContext(LineNo));
    end;

    procedure ParseDecimal(Value: Text; ElementName: Text; LineNo: Integer): Decimal
    var
        Result: Decimal;
    begin
        if Value = '' then
            Error(MissingValueErr, ElementName, GetLineContext(LineNo));
        // Format 9 = XML format: culture-independent, always a decimal point.
        if not Evaluate(Result, Value, 9) then
            Error(InvalidDecimalErr, ElementName, Value, GetLineContext(LineNo));
        exit(Result);
    end;

    procedure ParseDate(Value: Text; ElementName: Text; LineNo: Integer): Date
    var
        Result: Date;
    begin
        if Value = '' then
            Error(MissingValueErr, ElementName, GetLineContext(LineNo));
        if not Evaluate(Result, Value, 9) then
            Error(InvalidDateErr, ElementName, Value, GetLineContext(LineNo));
        exit(Result);
    end;

    procedure GetLineContext(LineNo: Integer): Text
    begin
        if LineNo = 0 then
            exit('');
        exit(StrSubstNo(LineContextTxt, LineNo));
    end;

    local procedure CheckBatchHeader(var TempBatch: Record "PEN Contribution Batch" temporary)
    begin
        TempBatch.TestField("Message ID");
        TempBatch.TestField("Employer No.");
        TempBatch.TestField("Received Date");
        GetPeriodStartDate(TempBatch.Period);
        if TempBatch."Control Total" <= 0 then
            Error(ControlTotalNotPositiveErr, TempBatch."Message ID");
    end;

    local procedure CheckLine(var TempLine: Record "PEN Contribution Queue" temporary)
    begin
        if TempLine."Member No." = '' then
            Error(MissingValueErr, TempLine.FieldCaption("Member No."), GetLineContext(TempLine."Line No."));
        if TempLine."Employee Amount" < 0 then
            Error(NegativeAmountErr, TempLine.FieldCaption("Employee Amount"), GetLineContext(TempLine."Line No."));
        if TempLine."Employer Amount" < 0 then
            Error(NegativeAmountErr, TempLine.FieldCaption("Employer Amount"), GetLineContext(TempLine."Line No."));
    end;

    local procedure CheckMessageIDNotReceived(MessageID: Code[50])
    var
        Batch: Record "PEN Contribution Batch";
    begin
        Batch.SetRange("Message ID", MessageID);
        if Batch.FindFirst() then
            Error(DuplicateMessageErr, MessageID, Batch."No.");
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateBatch(var Batch: Record "PEN Contribution Batch")
    begin
    end;
}
