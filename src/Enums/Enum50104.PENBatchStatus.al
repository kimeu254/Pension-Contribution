enum 50104 "PEN Batch Status"
{
    Extensible = true;

    value(0; Received)
    {
        Caption = 'Received';
    }
    value(1; "In Progress")
    {
        Caption = 'In Progress';
    }
    value(2; Completed)
    {
        Caption = 'Completed';
    }
    value(3; "Completed with Errors")
    {
        Caption = 'Completed with Errors';
    }
}
