/// <summary>
/// Reads a contribution batch in JSON format into temporary records. Only parses; the checks that decide
/// whether the batch is accepted are in PEN Contribution Intake.
/// </summary>
codeunit 50101 "PEN JSON Batch Reader"
{
    var
        Intake: Codeunit "PEN Contribution Intake";
        InvalidJsonErr: Label 'The file is not valid JSON.';
        MissingElementErr: Label 'The element "%1" is missing%2.', Comment = '%1 = element name, %2 = line context';
        NotAValueErr: Label 'The element "%1" must be a single value%2.', Comment = '%1 = element name, %2 = line context';
        NotANumberErr: Label 'The element "%1" must be a number%2.', Comment = '%1 = element name, %2 = line context';
        LinesNotArrayErr: Label 'The element "lines" is missing or is not a list.';
        LineNotObjectErr: Label 'Line %1 is not a JSON object.', Comment = '%1 = line number';

    procedure ReadBatch(var JsonInStream: InStream; var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Contribution Queue" temporary)
    var
        Root: JsonObject;
    begin
        if not Root.ReadFrom(JsonInStream) then
            Error(InvalidJsonErr);
        ReadBatch(Root, TempBatch, TempLine);
    end;

    procedure ReadBatch(JsonText: Text; var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Contribution Queue" temporary)
    var
        Root: JsonObject;
    begin
        if not Root.ReadFrom(JsonText) then
            Error(InvalidJsonErr);
        ReadBatch(Root, TempBatch, TempLine);
    end;

    procedure ReadBatch(Root: JsonObject; var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Contribution Queue" temporary)
    var
        LinesToken: JsonToken;
        LineToken: JsonToken;
        LineObject: JsonObject;
        LineNo: Integer;
    begin
        TempBatch.Init();
        TempBatch."Message ID" := CopyStr(GetText(Root, 'messageId', MaxStrLen(TempBatch."Message ID"), 0), 1, MaxStrLen(TempBatch."Message ID"));
        TempBatch."Employer No." := CopyStr(GetText(Root, 'employerNo', MaxStrLen(TempBatch."Employer No."), 0), 1, MaxStrLen(TempBatch."Employer No."));
        TempBatch.Period := CopyStr(GetText(Root, 'period', MaxStrLen(TempBatch.Period), 0), 1, MaxStrLen(TempBatch.Period));
        TempBatch."Received Date" := Intake.ParseDate(GetText(Root, 'receivedDate', 10, 0), 'receivedDate', 0);
        TempBatch."Control Total" := GetDecimal(Root, 'controlTotal', 0);
        TempBatch.Insert();

        if not Root.Get('lines', LinesToken) then
            Error(LinesNotArrayErr);
        if not LinesToken.IsArray() then
            Error(LinesNotArrayErr);

        foreach LineToken in LinesToken.AsArray() do begin
            LineNo += 1;
            if not LineToken.IsObject() then
                Error(LineNotObjectErr, LineNo);
            LineObject := LineToken.AsObject();

            TempLine.Init();
            TempLine."Entry No." := LineNo;
            TempLine."Line No." := LineNo;
            TempLine."Member No." := CopyStr(GetText(LineObject, 'memberNo', MaxStrLen(TempLine."Member No."), LineNo), 1, MaxStrLen(TempLine."Member No."));
            TempLine."Employee Amount" := GetDecimal(LineObject, 'employeeAmount', LineNo);
            TempLine."Employer Amount" := GetDecimal(LineObject, 'employerAmount', LineNo);
            TempLine.Insert();
        end;
    end;

    local procedure GetText(JObject: JsonObject; ElementName: Text; MaxLength: Integer; LineNo: Integer): Text
    var
        Value: Text;
    begin
        Value := GetValue(JObject, ElementName, LineNo).AsText();
        Intake.CheckValue(Value, ElementName, MaxLength, LineNo);
        exit(Value);
    end;

    local procedure GetDecimal(JObject: JsonObject; ElementName: Text; LineNo: Integer): Decimal
    var
        Value: Decimal;
    begin
        if not TryAsDecimal(GetValue(JObject, ElementName, LineNo), Value) then
            Error(NotANumberErr, ElementName, Intake.GetLineContext(LineNo));
        exit(Value);
    end;

    local procedure GetValue(JObject: JsonObject; ElementName: Text; LineNo: Integer): JsonValue
    var
        Token: JsonToken;
    begin
        if not JObject.Get(ElementName, Token) then
            Error(MissingElementErr, ElementName, Intake.GetLineContext(LineNo));
        if not Token.IsValue() then
            Error(NotAValueErr, ElementName, Intake.GetLineContext(LineNo));
        if Token.AsValue().IsNull() then
            Error(MissingElementErr, ElementName, Intake.GetLineContext(LineNo));
        exit(Token.AsValue());
    end;

    [TryFunction]
    local procedure TryAsDecimal(JValue: JsonValue; var Value: Decimal)
    begin
        Value := JValue.AsDecimal();
    end;
}
