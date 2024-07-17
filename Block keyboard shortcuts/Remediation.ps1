<#
Type shortcuts to block in the variable Keyboard_Shortcuts_to_disable.

See below an overview:
$Keyboard_Shortcuts_to_disable = @("Ctrl+Alt+Del",
"Win+R",
"Windows+V"
)
#>

$Keyboard_Shortcuts_to_disable = @()

$Log_File = "c:\windows\temp\Block_Keyboard_Shortcuts.log"

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		write-host  "$MyDate - $Message_Type : $Message"		
	}

Function Set_WEKF
	{
		param (
			[String]$Key_ID
		)

		$Get_Keys = Get-WMIObject -class WEKF_PredefinedKey -namespace "root\standardcimv2\embedded" | where {$_.Id -eq "$Key_ID"};
		If($Get_Keys -ne $null)
			{
				$Key_Status = $Get_Keys.Enabled
				If($Key_Status -eq $False)
					{						
						
						$Get_Keys = Get-WMIObject -Class WEKF_PredefinedKey -Namespace "root\standardcimv2\embedded" | Where {$_.Id -eq "$Key_ID"}
						$Get_Keys.Enabled = $True
						$Get_Keys.Put()											
						Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID has been blocked"						
					}								
			}	
		Else
			{
				$Get_Keys = Get-WMIObject -class WEKF_CustomKey -namespace "root\standardcimv2\embedded" | where {$_.Id -eq "$Key_ID"};
				If($Get_Keys -ne $null)
					{
						$Key_Status = $Get_Keys.Enabled	
						If($Key_Status -eq $False)
							{
								Set-WMIInstance -class WEKF_CustomKey -argument @{Id="$Key_ID";Enabled=$True} -namespace "root\standardcimv2\embedded" | out-null
								Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID has been blocked"						
							}					
					}
				Else
					{
						Set-WMIInstance -class WEKF_CustomKey -argument @{Id="$Key_ID";Enabled=$True} -namespace "root\standardcimv2\embedded" | out-null
						Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID has been blocked"	
					}					
			}
	}	

ForEach($Shortcut in $Keyboard_Shortcuts_to_disable)
	{
		Set_WEKF -Key_ID $Shortcut
	}