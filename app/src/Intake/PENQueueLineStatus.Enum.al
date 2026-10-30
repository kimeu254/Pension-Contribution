enum 50103 "PEN Queue Line Status"
{
    Extensible = true;

    value(0; Pending)
    {
        Caption = 'Pending';
    }
    value(1; Processing)
    {
        Caption = 'Processing';
    }
    value(2; Posted)
    {
        Caption = 'Posted';
    }
    value(3; Failed)
    {
        Caption = 'Failed';
    }
    value(4; "Dead Letter")
    {
        Caption = 'Dead Letter';
    }
}
