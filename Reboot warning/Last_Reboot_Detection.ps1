# Set the reboot delay in the variable $Reboot_Delay
# By default it's 5 days, meaning is the device has not rebooted since 5 days or more a warning will be displayed
$Reboot_Delay = 5


	
$Last_reboot = Get-ciminstance Win32_OperatingSystem | Select -Exp LastBootUpTime	
# Check if fast boot is enabled: if enabled uptime may be wrong
$Check_FastBoot = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ea silentlycontinue).HiberbootEnabled 
# If fast boot is not enabled
If(($Check_FastBoot -eq $null) -or ($Check_FastBoot -eq 0))
	{
		$Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot'| where {$_.ID -eq 27 -and $_.message -like "*0x0*"}
		If($Boot_Event -ne $null)
			{
				$Last_boot = $Boot_Event[0].TimeCreated		
			}
	}
ElseIf($Check_FastBoot -eq 1) 	
	{
		$Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot'| where {$_.ID -eq 27 -and $_.message -like "*0x1*"}
		If($Boot_Event -ne $null)
			{
				$Last_boot = $Boot_Event[0].TimeCreated		
			}			
	}		
	
If($Last_boot -eq $null)
	{
		# If event log with ID 27 can not be found we checl last reboot time using WMI
		# It can occurs for instance if event log has been cleaned	
		$Uptime = $Last_reboot
	}
Else
	{
		If($Last_reboot -gt $Last_boot)
			{
				$Uptime = $Last_reboot
			}
		Else
			{
				$Uptime = $Last_boot
			}	
	}
	
$Current_Date = get-date
$Diff_boot_time = $Current_Date - $Uptime
$Boot_Uptime_Days = $Diff_boot_time.Days	
$Hour = $Diff_boot_time.Hours
$Minutes = $Diff_boot_time.Minutes
$Reboot_Time = "$Boot_Uptime_Days day(s)" + ": $Hour hour(s)" + " : $minutes minute(s)"						
If($Boot_Uptime_Days -ge $Reboot_Delay)
	{
		write-output "Last reboot/shutdown: $Reboot_Time"			
		EXIT 1		
	}
Else
	{
		write-output "Last reboot/shutdown: $Reboot_Time"			
		EXIT 0
	}		