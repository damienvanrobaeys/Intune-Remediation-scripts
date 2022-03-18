##################################################################################################
# 									Variables to fill
##################################################################################################
<#
Set there when to display the alert, 
If the free space perdent on the disk is below alue in variable $Percent_Alert the notification will be displayed
$Percent_Alert = 20
#>
##################################################################################################
# 									Variables to fill
##################################################################################################

$Win32_LogicalDisk = Get-ciminstance Win32_LogicalDisk | where {$_.DeviceID -eq "C:"}
$Disk_Full_Size = $Win32_LogicalDisk.size
$Disk_Free_Space = $Win32_LogicalDisk.Freespace
$Total_size_NoFormat = [Math]::Round(($Disk_Full_Size))
[int]$Free_Space_percent = '{0:N0}' -f (($Disk_Free_Space / $Total_size_NoFormat * 100),1)

If($Free_Space_percent -le $Percent_Alert)
	{
		write-output "Free space percent: $Free_Space_percent"	
		EXIT 1		
	}
Else
	{
		write-output "Free space percent: $Free_Space_percent"	
		EXIT 0
	}