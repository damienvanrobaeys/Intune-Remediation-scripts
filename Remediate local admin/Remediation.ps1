# Path of the log file
$Log_File = "C:\Windows\Debug\Remove_Local_admin.log" 
If(!(test-path $Log_File)){new-item $Log_File -type file -force}

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
		write-host "$MyDate - $Message_Type : $Message"	
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"			
	}
	
Write_Log -Message_Type "INFO" -Message "Local admin account remediation started"	
	
$Authorized_Accounts = @()
$Get_Local_AdminGroup = Gwmi win32_group -Filter "Domain='$env:computername' and SID='S-1-5-32-544'"
$Get_Local_AdminGroup_Name = $Get_Local_AdminGroup.Name
$Get_Administrator_Name = $Get_Local_AdminGroup_Name -replace ".$"	# Built-in admin user account: Administrateur or Administrator
$Get_Administrator_Status = (Get-LocalUser $Get_Administrator_Name).Enabled

<#
In the variable $Authorized_Accounts we add authorized accounts meaning accounts that may be in the local admin group.
It can be for instance: 
- Name of on-prem group 
- SID of Entra ID group

S-1-12-1-3058833028-1285739641-142383242-3580399105: Azure AD role: Global administrator (ID: b6521684-d479-4ca2-8a98-7c08018e68d5)
S-1-12-1-3734950830-1325773448-1584976025-3637790478: Azure AD role: Azure AD Joined Device Local Administrator (ID: de9ed3ae-b288-4f05-99d0-785e0e47d4d8)

Here is an example:
$Authorized_Accounts = @(
"SD-OnPrem-Devices-Administrators"; # Local admin group for GEN1
"S-1-12-1-3058833028-1285739641-142383242-3580399105"; # Azure AD role: Global administrator (ID: b6521684-d479-4ca2-8a98-7c08018e68d5)
"S-1-12-1-3734950830-1325773448-1584976025-3637790478"; # Azure AD role: Azure AD Joined Device Local Administrator (ID: de9ed3ae-b288-4f05-99d0-785e0e47d4d8)

To get the SID you need first to get the ID.
You can get it directly on the Intune portal.
Then you can convert the ID to SIS as below:
- Use this website: https://erikengberg.com/azure-ad-object-id-to-sid/
- Use this script: https://oliverkieselbach.com/2020/05/13/powershell-helpers-to-convert-azure-ad-object-ids-and-sids/
#>

$Authorized_Accounts = @(
"S-1-12-1-3058833028-1285739641-142383242-3580399105"; # Azure AD role: Global administrator (ID: b6521684-d479-4ca2-8a98-7c08018e68d5)
"S-1-12-1-3734950830-1325773448-1584976025-3637790478"; # Azure AD role: Azure AD Joined Device Local Administrator (ID: de9ed3ae-b288-4f05-99d0-785e0e47d4d8)
)

If($Get_Administrator_Status -eq $False)
	{
		$Authorized_Accounts += $Get_Administrator_Name	
	}
$AdminGroup = [ADSI]"WinNT://./$Get_Local_AdminGroup_Name,group"
$Get_Local_AdminGroup_Members = $AdminGroup.psbase.Invoke("Members") | % {([ADSI]$_).InvokeGet('AdsPath')}
foreach($Member in $Get_Local_AdminGroup_Members | where {$_ -notcontains $Authorized_Accounts}) 
	{
		$Account_Infos = $Member.split("/")
		$Account_Name = $Account_Infos[-1]
		$Other_Local_Admin = $Account_Name | Where {($Authorized_Accounts -notcontains $_)}
		If($Other_Local_Admin -ne $null)
			{
				Write_Log -Message_Type "INFO" -Message "Account to delete: $Other_Local_Admin"
				Try{
					$AdminGroup.Remove("$Member")
					Write_Log -Message_Type "INFO" -Message "Account $Other_Local_Admin has been removed"
				}
				Catch{
					Write_Log -Message_Type "INFO" -Message "Account $Other_Local_Admin has not been removed"			
				}
			}
	}