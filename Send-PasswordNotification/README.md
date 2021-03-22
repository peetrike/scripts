# Send-PasswordNotification script

## Purpose

This script is meant to send e-mail notifications about expiring passwords.

The notification is sent only to users who:

1. are enabled
2. can change their password
3. has an e-mail address
4. has been logged on at least once
5. their password expires in time
6. password is not yet expired

The script uses config file, that contains information necessary to send e-mail.

Script requires ActiveDirectory module on the computer where script runs.  
Script also requires at least one DC with AD WS (or AD GMS) service running.

## Configuring script behavior

The script uses configuration file to pass user account search settings and
e-mail sending settings to script. The [sample configuration file](Send-PasswordNotification.config)
is included in this repository.

By default, the script expects that configuration file name is same as script
name and extension is _.config_.  If different name is used, then `-ConfigFile`
parameter should be used when running the script.

The configuration file contains next configuration elements

### OU

The `ou` element allows to limit search for user accounts in specific OU.
The content of this element should be OU distinguished name.
The search scope is default scope for `Get-ADUser` cmdlet (SubTree).

By default the search is performed on whole domain.

### User

The `user` element contains 2 parameters:

- `useSamAccountName` parameter specifies, that e-mail body should refer to user
  account with SamAccountName instead of User Principal Name.  By default the
  user principal name is used.
- `useManagerMail` parameter specifies, that e-mail address for sending
  notification should be taken from user's manager account.  This is useful for
  sending notifications about service account/admin user account password
  expiration to users who are responsible for changing passwords on these
  accounts.

### Server

The `server` element specifies SMTP server that is used for sending e-mails.

### Mail

The `mail` element contains settings that are required to send e-mail:

- `from` parameter specifies sender's e-mail address.  Many e-mail servers deny
  e-mails with empty sender address.
- `subject` parameter contains e-mail subject
- `body` parameter contains e-mail body.  There are 2 placeholders used there:
  - `{0}` is replaced with user account name.
  - `{1}` is replaced with number of days that are remaining.

## Running script

### Running with configuration file that has default name

```powershell
Send-PasswordNotification.ps1 -DaysBefore 5,1
```

This example sends password notifications to users, whose password will expire
in 5 or 1 days.

### Running script with explicit configuration file

```powershell
Send-PasswordNotification.ps1 13 -ConfigFile my.config
```

This example sends password notification e-mails to users whose password will
expire in 13 days.  The configuration file name is explicitly provided on
command line.
