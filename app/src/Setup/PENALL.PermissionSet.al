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
        tabledata "PEN Pension Cue" = RIMD,
        table "PEN Pension Setup" = X,
        table "PEN Scheme" = X,
        table "PEN Employer" = X,
        table "PEN Member" = X,
        table "PEN Member Ledger Entry" = X,
        table "PEN Contribution Batch" = X,
        table "PEN Contribution Queue" = X,
        table "PEN Pension Cue" = X,
        page "PEN Pension Setup" = X,
        page "PEN Schemes" = X,
        page "PEN Employer List" = X,
        page "PEN Employer Card" = X,
        page "PEN Member List" = X,
        page "PEN Member Card" = X,
        page "PEN Member Ledger Entries" = X,
        page "PEN Contribution Batches" = X,
        page "PEN Contribution Queue" = X,
        page "PEN Generate Test Data" = X,
        page "PEN Pension Role Center" = X,
        page "PEN Pension Activities" = X,
        codeunit "PEN Install" = X,
        codeunit "PEN Contribution Intake" = X,
        codeunit "PEN JSON Batch Reader" = X,
        codeunit "PEN CSV Batch Reader" = X,
        codeunit "PEN Queue Processor" = X,
        codeunit "PEN Line Validation" = X,
        codeunit "PEN Contribution Posting" = X,
        codeunit "PEN Test Data Generator" = X,
        report "PEN Member Statement" = X;
}
