$Delay_alert = 30

$Log_File = "C:\Windows\Debug\BSOD_Detection.log"
If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"	
		write-host "$MyDate - $Message_Type : $Message"	
	}

$Minidump_Folder = "C:\Windows\Minidump"
If(test-path $Minidump_Folder)
	{
		$All_DMP = Get-Childitem $Minidump_Folder | where {$_.Extension -eq ".dmp"} | select name, LastWriteTime
		$Current_date = Get-Date
		$Last_DMP = $All_DMP[-1].LastWriteTime
		$Last_DMP_delay = $Current_date - $Last_DMP
		If($Last_DMP_delay -le $Delay_alert)
			{
				Write_Log -Message_Type "INFO" -Message "A recent BSOD has been found"
				Write_Log -Message_Type "INFO" -Message "Date: $Last_DMP"

				$Get_last_BugCheck_Event = (Get-EventLog system -Source bugcheck)[0]
				$Get_last_BugCheck_Event_Date = $Get_last_BugCheck_Event.TimeGenerated
				$Get_last_BugCheck_Event_MSG = $Get_last_BugCheck_Event.Message				
				If($Get_last_BugCheck_Event_Date -match $Last_DMP)
					{
						Write_Log -Message_Type "INFO" -Message "A corresponding entry has been found in the event log"
						Write_Log -Message_Type "INFO" -Message "Event log time: $Get_last_BugCheck_Event_Date"
						Write_Log -Message_Type "INFO" -Message "Event log message: $Get_last_BugCheck_Event_MSG"	
						
						If($Get_last_BugCheck_Event_MSG -like "*'BugCheck'*")						
							{
								$Get_Code = (($Get_last_BugCheck_Event_MSG.split(":")[1].Trim()).Split(".")[0]).split("'")[1]														
							}
						Else
							{
								$Get_Code = (($Get_last_BugCheck_Event_MSG.split(":")[1].Trim()).Split(".")[0]).split("'")						
							}							
												
						Write_Log -Message_Type "INFO" -Message "BSOD code: $Get_Code"							
						write-output "BSOD code: $Get_Code)"	
						EXIT 1
					}
				Else
					{
						write-output "Last BSOD: $Get_last_BugCheck_Event_Date"	
						EXIT 1
					}
			}
		Else
			{
				write-output "No recent BSOD found"		
				EXIT 0
			}
	}
Else
	{
		Write_Log -Message_Type "INFO" -Message "No DMP files found"	
		write-output "No DMP files found"
		EXIT 0
	}
