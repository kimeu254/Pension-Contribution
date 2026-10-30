permissionset 50100 "PEN ALL"
{
    Assignable = true;
    Caption = 'Pension - All';

    Permissions =
        tabledata "PEN Pension Setup" = RIMD,
        tabledata "PEN Scheme" = RIMD,
        tabledata "PEN Employer" = RIMD,
        tabledata "PEN Member" = RIMD,
        tabledata "PEN Member Ledger Entry" = RIMD,
        tabledata "PEN Contribution Batch" = RIMD,
        tabledata "PEN Contribution Queue" = RIMD,
        table "PEN Pension Setup" = X,
        table "PEN Scheme" = X,
        table "PEN Employer" = X,
        table "PEN Member" = X,
        table "PEN Member Ledger Entry" = X,
        table "PEN Contribution Batch" = X,
        table "PEN Contribution Queue" = X,
        page "PEN Pension Setup" = X,
        page "PEN Schemes" = X,
        page "PEN Employer List" = X,
        page "PEN Employer Card" = X,
        page "PEN Member List" = X,
        page "PEN Member Card" = X,
        page "PEN Member Ledger Entries" = X,
        page "PEN Contribution Batches" = X,
        page "PEN Contribution Queue" = X,
        codeunit "PEN Install" = X,
        codeunit "PEN Contribution Intake" = X,
        codeunit "PEN JSON Batch Reader" = X,
        codeunit "PEN CSV Batch Reader" = X,
        codeunit "PEN Queue Processor" = X,
        codeunit "PEN Line Validation" = X,
        codeunit "PEN Contribution Posting" = X;
}
