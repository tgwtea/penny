# Runbooks

One file per operational procedure. Every alert links to the runbook that handles it.

| Runbook | Use it when |
| --- | --- |
| [Restore the database from backup](restore-database.md) | Data is lost or damaged, and monthly as a drill |
| [Set up Firebase Authentication](firebase-auth-setup.md) | Creating an environment, or moving sign-in off the local emulator |
| [Answer a personal data request](data-requests.md) | Someone asks to see, correct or delete what Penny holds about them (PDPA) |
| [Respond to a data breach](breach-response.md) | Personal data may have reached someone who should not have it |

Planned: rotate secrets, recover from a failed migration, drain a job queue backlog.
