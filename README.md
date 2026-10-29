# Pension-Contribution

## Additional fields

Fields added beyond the specification in the brief, and why.

| Table | Field | Why |
|---|---|---|
| PEN Pension Setup | Min. Joining Age (default 18) | The brief requires members to be between 18 and 65 at joining. Keeping the limits in setup instead of hard-coding them lets the administrator change the rule (for example a scheme rule change or a different retirement age) without a code change and redeploy. |
| PEN Pension Setup | Max. Joining Age (default 65) | As above. A Min. Joining Age greater than the Max. Joining Age is rejected. |
