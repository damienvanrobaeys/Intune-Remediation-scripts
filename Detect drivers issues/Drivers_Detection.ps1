$ProgData = $env:PROGRAMDATA
$Log_File = "$ProgData\Drivers_Error_log.log"
	
Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"		
	}
	
If(!(test-path $Log_File)){new-item $Log_File -type file -force}Else{Add-Content $Log_File ""}

$Drivers_Test = Get-WmiObject Win32_PNPEntity | Where-Object {$_.ConfigManagerErrorCode -gt 0 }    
$Search_Disabled_Missing_Drivers = ($Drivers_Test | Where-Object {(($_.ConfigManagerErrorCode -eq 22) -or ($_.ConfigManagerErrorCode -eq 28))})
    
If(($Search_Disabled_Missing_Drivers).count -gt 0)	
{
	$Search_Missing_Drivers = ($Search_Disabled_Missing_Drivers | Where-Object {$_.ConfigManagerErrorCode -eq 28}).count
	$Search_Disabled_Drivers = ($Search_Disabled_Missing_Drivers | Where-Object {$_.ConfigManagerErrorCode -eq 22}).count
	
	Write_Log -Message_Type "ERROR" -Message "There is an issue with drivers. Missing drivers: $Search_Missing_Drivers - Disabled drivers: $Search_Disabled_Drivers"			
	ForEach($Driver in $Search_Disabled_Missing_Drivers)
		{
			$Driver_Name = $Driver.Caption
			$Driver_DeviceID = $Driver.DeviceID
			Write_Log -Message_Type "INFO" -Message "Driver name is: $Driver_Name"
			Write_Log -Message_Type "INFO" -Message "Driver device ID is: $Driver_DeviceID"	
			Add-Content $Log_File ""
		}
	Exit 1			
	Break
}Else	
{
	Write_Log -Message_Type "SUCCESS" -Message "There is no issue with drivers."			
	Exit 0		
}