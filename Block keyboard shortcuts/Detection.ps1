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
$count = 0

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		write-host  "$MyDate - $Message_Type : $Message"		
	}
	
Function Check_WEKF
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
						Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID is not blocked"
						++(Get-Variable count).Value
					}
				Else
					{
						Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID is already blocked"
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
								Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID is not blocked"
								++(Get-Variable count).Value
							}
						Else
							{
								Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID is already blocked"
							}					
					}
				Else
					{
						Write_Log -Message_Type "INFO" -Message "Keyboard shortcut $Key_ID is not blocked"
						++(Get-Variable count).Value
					}					
			}
	}	

If($Keyboard_Shortcuts_to_disable.count -eq 0)
	{
		EXIT 0
	}

If(!(test-path $Log_File)){New-item $Log_File -type file -force}
	
$FeatureName = "Client-KeyboardFilter"
$Check_Keyboard_Feature = Get-WindowsOptionalFeature -online -FeatureName $FeatureName
If($Check_Keyboard_Feature.State -ne "enabled")
	{
		Write_Log -Message_Type "INFO" -Message "Feature: $FeatureName is not enabled"  
		Try
			{
				Enable-WindowsOptionalFeature -FeatureName $FeatureName -NoRestart -Online	
				Write_Log -Message_Type "SUCCESS" -Message "Feature: $FeatureName has been enabled" 
				Write_Log -Message_Type "INFO" -Message "A reboot is required" 		
				EXIT 1
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Feature: $FeatureName has not been enabled" 
				write-output "Feature: $FeatureName has not been enabled"
				EXIT 0
			}
	}
Else
	{
		Write_Log -Message_Type "INFO" -Message "Feature: $FeatureName is enabled"  		
	}

ForEach($Shortcut in $Keyboard_Shortcuts_to_disable)
	{
		Check_WEKF -Key_ID $Shortcut
	}

If($count -gt 0)
	{
		Write_Log -Message_Type "INFO" -Message "There are $count keyboard shortcuts to block"  
		EXIT 1
	}
Else
	{
		Write_Log -Message_Type "INFO" -Message "No shortcut to block"  
		Write_Log -Message_Type "INFO" -Message "All shortcuts are already blocked"  		
		EXIT 0	
	}	