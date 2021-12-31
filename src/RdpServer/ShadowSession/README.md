# Establishing shadow session in RDP farm

The scripts in this folder help with connecting to shadow session on RDP farm
server.

The PowerShell module and Server Manager GUI depends on having admin permissions
on both RD Connection Broker and RD Session Host servers.  These scripts try to
work around the admin requirements.

## Obtaining script(s)

The scripts are available on [Telia Internal PowerShell Repository](https://itwiki.atlassian.teliacompany.net/display/MSC/Powershelli+koodihoidla):

```powershell
Save-Script Connect-ShadowSession -Repository TeliaInt -Path c:\temp
```

Both scripts are downloaded using command above.  After saving scripts on local
workstation, these can be copied to customer Remote Desktop farm.

## Preparation

1. Create AD group for people who need shadow session permission
2. On one of the RD Session Host servers use script [Add-ShadowPermission](Add-ShadowPermission.ps1)
   to grant newly created group permissions to establish shadow sessions.  The
   user running script must have admin permissions on all RD Session Host
   servers.

The following must be configured if there is more than 1 RD Session Host servers
in the farm or when RD Connection Broker role is installed on separate server.

1. In *Connection Broker* server, add created group to local group
   **Distributed Com Users**

   Alternatively you can delegate **Remote Activation** right to the newly created
   group in *Component Services* | *My Computer* | *Properties* |
   *COM Security* | *Launch and Activation Permissions*

2. In *Connection Broker* server add created group to local group
   **Remote Management Users**.
3. In *Connection Broker* server, grant group *Remote Management Users* with
   **Remote Enable** right in *Computer Management* |
   *Services and Applications* | *WMI Control* | *Properties*.  The permission
   is required at least in namespaces *root/CIMv2* and *root/cimv2/RDMS*, but it
   can be granted on root and configured to be applied also to subnamespaces.

## Usage

Put script [Connect-ShadowSession](Connect-ShadowSession.ps1) to somewhere where
it is reachable on all RD Session Host servers.  Be aware that if the location
is on network share, the PowerShell must be configured to use *Unrestricted*
execution policy for running that script.  The shortcut in desktop or Start Menu
should be enough.

When script is runned without command-line parameters (shortcut), then user gets
list of all existing sessions in the farm.  Only one must be selected to
establish shadow session.

When script is started with command line parameters, user session can be
filtered:

```powershell
Connect-ShadowSession.ps1 -UserName user
```
