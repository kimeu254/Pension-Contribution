/// <summary>
/// Business validation for one contribution queue line. Errors on the first rule that fails, so the caller can
/// run it inside a TryFunction and store the error text on the line. Read-only: it never writes to the database.
/// </summary>
codeunit 50104 "PEN Line Validation"
{
    var
        Employer: Record "PEN Employer";
        Scheme: Record "PEN Scheme";
        MemberNotFoundErr: Label 'Member %1 does not exist.', Comment = '%1 = Member No.';
        MemberNotActiveErr: Label 'Member %1 is not active (status %2).', Comment = '%1 = Member No., %2 = status';
        WrongEmployerErr: Label 'Member %1 belongs to employer %2, not to employer %3 that sent the batch.', Comment = '%1 = Member No., %2 = member''s Employer No., %3 = batch Employer No.';
        EmployerNotFoundErr: Label 'Employer %1 does not exist.', Comment = '%1 = Employer No.';
        EmployerNotActiveErr: Label 'Employer %1 is not active (status %2).', Comment = '%1 = Employer No., %2 = status';
        SchemeNotFoundErr: Label 'Scheme %1 of employer %2 does not exist.', Comment = '%1 = Scheme Code, %2 = Employer No.';
        SchemeBlockedErr: Label 'Scheme %1 is blocked.', Comment = '%1 = Scheme Code';
        AlreadyPostedErr: Label 'A contribution for member %1 and period %2 has already been posted (batch %3, line %4).', Comment = '%1 = Member No., %2 = period, %3 = Batch No., %4 = Line No.';
        CapNotSetErr: Label 'Employer Cap % is not set on scheme %1.', Comment = '%1 = Scheme Code';
        OverCapErr: Label 'The employer amount %1 exceeds the cap of %2 (%3% of pensionable salary %4) for member %5.', Comment = '%1 = employer amount, %2 = maximum amount, %3 = cap %, %4 = pensionable salary, %5 = Member No.';

    /// <summary>
    /// Checks one queue line against the business rules. Errors with a descriptive message if a rule fails.
    /// </summary>
    procedure ValidateLine(var QueueLine: Record "PEN Contribution Queue"; Batch: Record "PEN Contribution Batch")
    var
        Member: Record "PEN Member";
        IsHandled: Boolean;
    begin
        OnBeforeValidateQueueLine(QueueLine, Batch, IsHandled);
        if IsHandled then
            exit;

        // The employer and the scheme are the same for every line in a batch, so they are read once and reused.
        CheckEmployerAndScheme(Batch."Employer No.");
        CheckMember(QueueLine, Batch, Member);
        CheckNotAlreadyPosted(QueueLine);
        CheckEmployerCap(QueueLine, Member);

        OnAfterValidateQueueLine(QueueLine, Batch);
    end;

    local procedure CheckEmployerAndScheme(EmployerNo: Code[20])
    begin
        if Employer."No." <> EmployerNo then begin
            Employer.SetLoadFields("No.", Status, "Scheme Code");
            if not Employer.Get(EmployerNo) then begin
                Clear(Employer);
                Error(EmployerNotFoundErr, EmployerNo);
            end;
        end;
        if Employer.Status <> Employer.Status::Active then
            Error(EmployerNotActiveErr, Employer."No.", Employer.Status);

        if Scheme."Code" <> Employer."Scheme Code" then
            if not Scheme.Get(Employer."Scheme Code") then begin
                Clear(Scheme);
                Error(SchemeNotFoundErr, Employer."Scheme Code", Employer."No.");
            end;
        if Scheme.Blocked then
            Error(SchemeBlockedErr, Scheme."Code");
        Scheme.CheckPostingAccounts();
    end;

    local procedure CheckMember(QueueLine: Record "PEN Contribution Queue"; Batch: Record "PEN Contribution Batch"; var Member: Record "PEN Member")
    begin
        Member.SetLoadFields("No.", Status, "Employer No.", "Pensionable Salary");
        if not Member.Get(QueueLine."Member No.") then
            Error(MemberNotFoundErr, QueueLine."Member No.");
        if Member.Status <> Member.Status::Active then
            Error(MemberNotActiveErr, Member."No.", Member.Status);
        if Member."Employer No." <> Batch."Employer No." then
            Error(WrongEmployerErr, Member."No.", Member."Employer No.", Batch."Employer No.");
    end;

    local procedure CheckNotAlreadyPosted(QueueLine: Record "PEN Contribution Queue")
    var
        PostedLine: Record "PEN Contribution Queue";
    begin
        PostedLine.SetCurrentKey("Member No.", Period, Status);
        PostedLine.SetRange("Member No.", QueueLine."Member No.");
        PostedLine.SetRange(Period, QueueLine.Period);
        PostedLine.SetRange(Status, PostedLine.Status::Posted);
        PostedLine.SetLoadFields("Batch No.", "Line No.");
        if PostedLine.FindFirst() then
            Error(AlreadyPostedErr, QueueLine."Member No.", QueueLine.Period, PostedLine."Batch No.", PostedLine."Line No.");
    end;

    local procedure CheckEmployerCap(QueueLine: Record "PEN Contribution Queue"; Member: Record "PEN Member")
    var
        MaxEmployerAmount: Decimal;
    begin
        if Scheme."Employer Cap %" = 0 then
            Error(CapNotSetErr, Scheme."Code");
        MaxEmployerAmount := Round(Member."Pensionable Salary" * Scheme."Employer Cap %" / 100);
        if QueueLine."Employer Amount" > MaxEmployerAmount then
            Error(OverCapErr, QueueLine."Employer Amount", MaxEmployerAmount, Scheme."Employer Cap %", Member."Pensionable Salary", Member."No.");
    end;

    /// <summary>
    /// Raised before a queue line is validated. Set IsHandled to replace the standard validation.
    /// Runs inside a TryFunction, so subscribers must not write to the database.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidateQueueLine(var QueueLine: Record "PEN Contribution Queue"; Batch: Record "PEN Contribution Batch"; var IsHandled: Boolean)
    begin
    end;

    /// <summary>
    /// Raised after a queue line has passed the standard validation. Raise an error to reject the line.
    /// Runs inside a TryFunction, so subscribers must not write to the database.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterValidateQueueLine(var QueueLine: Record "PEN Contribution Queue"; Batch: Record "PEN Contribution Batch")
    begin
    end;
}
