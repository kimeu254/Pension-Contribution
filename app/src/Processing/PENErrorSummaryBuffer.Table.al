/// <summary>
/// In-memory list of the most common errors on failed and dead-letter queue lines, for the Queue Monitor.
/// Errors are grouped by pattern: digits are replaced by '#', so "Member MEM00007 is not active" and
/// "Member MEM00012 is not active" count as the same error.
/// </summary>
table 50109 "PEN Error Summary Buffer"
{
    Caption = 'Error Summary Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Error Pattern"; Text[250])
        {
            Caption = 'Error';
        }
        field(3; "Line Count"; Integer)
        {
            Caption = 'Lines';
        }
        field(4; "Failed Lines"; Integer)
        {
            Caption = 'Failed';
        }
        field(5; "Dead Letter Lines"; Integer)
        {
            Caption = 'Dead Letter';
        }
        field(6; "Example Error"; Text[2048])
        {
            Caption = 'Example';
        }
        field(7; "Last Seen At"; DateTime)
        {
            Caption = 'Last Seen At';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Count; "Line Count")
        {
        }
    }
}
