page 50112 "PEN Pension Role Center"
{
    Caption = 'Pension Administrator';
    PageType = RoleCenter;

    layout
    {
        area(RoleCenter)
        {
            part(Activities; "PEN Pension Activities")
            {
                ApplicationArea = All;
            }
            part(JobQueue; "My Job Queue")
            {
                ApplicationArea = All;
                Caption = 'My Job Queue';
            }
        }
    }

    actions
    {
        area(Embedding)
        {
            action(Batches)
            {
                ApplicationArea = All;
                Caption = 'Contribution Batches';
                RunObject = page "PEN Contribution Batches";
                ToolTip = 'Import contribution files and follow their processing.';
            }
            action(Queue)
            {
                ApplicationArea = All;
                Caption = 'Contribution Queue';
                RunObject = page "PEN Contribution Queue";
                ToolTip = 'View the member lines of all batches, their status and errors, and reprocess failed lines.';
            }
            action(Employers)
            {
                ApplicationArea = All;
                Caption = 'Employers';
                RunObject = page "PEN Employer List";
                ToolTip = 'View and manage participating employers.';
            }
            action(Members)
            {
                ApplicationArea = All;
                Caption = 'Members';
                RunObject = page "PEN Member List";
                ToolTip = 'View and manage scheme members.';
            }
            action(Schemes)
            {
                ApplicationArea = All;
                Caption = 'Schemes';
                RunObject = page "PEN Schemes";
                ToolTip = 'View and manage pension schemes and their G/L accounts.';
            }
        }
        area(Sections)
        {
            group(MasterData)
            {
                Caption = 'Schemes & Members';

                action(SchemesList)
                {
                    ApplicationArea = All;
                    Caption = 'Schemes';
                    RunObject = page "PEN Schemes";
                    ToolTip = 'View and manage pension schemes and their G/L accounts.';
                }
                action(EmployersList)
                {
                    ApplicationArea = All;
                    Caption = 'Employers';
                    RunObject = page "PEN Employer List";
                    ToolTip = 'View and manage participating employers.';
                }
                action(MembersList)
                {
                    ApplicationArea = All;
                    Caption = 'Members';
                    RunObject = page "PEN Member List";
                    ToolTip = 'View and manage scheme members.';
                }
            }
            group(Contributions)
            {
                Caption = 'Contributions';

                action(BatchesList)
                {
                    ApplicationArea = All;
                    Caption = 'Contribution Batches';
                    RunObject = page "PEN Contribution Batches";
                    ToolTip = 'Import contribution files and follow their processing.';
                }
                action(QueueList)
                {
                    ApplicationArea = All;
                    Caption = 'Contribution Queue';
                    RunObject = page "PEN Contribution Queue";
                    ToolTip = 'View the member lines of all batches, their status and errors, and reprocess failed lines.';
                }
                action(MemberLedgerEntries)
                {
                    ApplicationArea = All;
                    Caption = 'Member Ledger Entries';
                    RunObject = page "PEN Member Ledger Entries";
                    ToolTip = 'View the posted employee and employer contributions per member.';
                }
            }
            group(Administration)
            {
                Caption = 'Setup';

                action(PensionSetup)
                {
                    ApplicationArea = All;
                    Caption = 'Pension Setup';
                    RunObject = page "PEN Pension Setup";
                    ToolTip = 'Set up number series, remittance rules, background processing and test data.';
                }
                action(JobQueueEntries)
                {
                    ApplicationArea = All;
                    Caption = 'Job Queue Entries';
                    RunObject = page "Job Queue Entries";
                    ToolTip = 'View the background jobs, including the contribution queue processor.';
                }
            }
        }
        area(Creation)
        {
            action(NewEmployer)
            {
                ApplicationArea = All;
                Caption = 'Employer';
                Image = NewCustomer;
                RunObject = page "PEN Employer Card";
                RunPageMode = Create;
                ToolTip = 'Register a new participating employer.';
            }
            action(NewMember)
            {
                ApplicationArea = All;
                Caption = 'Member';
                Image = NewResource;
                RunObject = page "PEN Member Card";
                RunPageMode = Create;
                ToolTip = 'Register a new scheme member.';
            }
        }
        area(Reporting)
        {
            action(MemberStatement)
            {
                ApplicationArea = All;
                Caption = 'Member Statement';
                Image = Report;
                RunObject = report "PEN Member Statement";
                ToolTip = 'Print member statements of contributions and balances for a date range.';
            }
        }
    }
}
