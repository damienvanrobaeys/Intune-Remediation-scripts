$Log_File = "C:\Windows\Debug\BSOD_Remediation.log"
$Temp_folder = "C:\Windows\Temp"
$DMP_Logs_folder = "$Temp_folder\DMP_Logs_folder"
$DMP_Logs_folder_ZIP = "$Temp_folder\BSOD_$env:computername.zip"

$ClientID = ""
$Secret = ''            
$Site_URL = ""
$Folder_Location = ""

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

Function Export_Event_Logs
	{
		param(
		$Log_To_Export,	
		$File_Name
		)	
		
		Write_Log -Message_Type "INFO" -Message "Collecting logs from: $Log_To_Export"
		Try
			{
				WEVTUtil export-log $Log_To_Export -ow:true /q:"*[System[TimeCreated[timediff(@SystemTime) <= 1296000000 ]]]" "$DMP_Logs_folder\$File_Name.evtx" | out-null
				Write_Log -Message_Type "SUCCESS" -Message "Event log $File_Name.evtx has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting event log $File_Name.evtx"
			}
	}		


Function Get_DeviceUpTime
	{
		param(
		[Switch]$Show_Days,
		[Switch]$Show_Uptime			
		)		
		
		$Last_reboot = Get-ciminstance Win32_OperatingSystem | Select -Exp LastBootUpTime
		$Check_FastBoot = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ea silentlycontinue).HiberbootEnabled 
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
				$Uptime = $Uptime = $Last_reboot
			}
		Else
			{
				If($Last_reboot -ge $Last_boot)
					{
						$Uptime = $Last_reboot
					}
				Else
					{
						$Uptime = $Last_boot
					}
			}
		
		If($Show_Days)
			{
				$Current_Date = get-date
				$Diff_boot_time = $Current_Date - $Uptime
				$Boot_Uptime_Days = $Diff_boot_time.Days	
				$Real_Uptime = $Boot_Uptime_Days
			}
		ElseIf($Show_Uptime)
			{
				$Real_Uptime = $Uptime
				
			}
		ElseIf(($Show_Days -eq $False) -and ($Show_Uptime -eq $False))
			{
				$Real_Uptime = $Uptime				
			}			
		Return "$Real_Uptime"
	}
	

$Is_Nuget_Installed = $False     
$Sharepoint_Connected = $False	
$Upload_file_status = $False	

If(!(Get-PackageProvider | where {$_.Name -eq "Nuget"}))
	{                                         
		Try
			{
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Scope currentuser -Force -Confirm:$False | out-null                                                                                                                 
				$Is_Nuget_Installed = $True 
				Write_Log -Message_Type "INFO" -Message "Package Nuget installed"				
			}
		Catch
			{
				$Is_Nuget_Installed = $False  
				Write_Log -Message_Type "ERROR" -Message "Package Nuget not installed"	
				$Reported_error = $error[0].exception.message
				write-output "KO (Nuget): $Reported_error"
				EXIT 1
			}
	}
Else
	{
		$Is_Nuget_Installed = $True      
	}

If($Is_Nuget_Installed -eq $True)
	{
		Try
			{
				$Check_Module_Ver = get-module -ListAvailable "PnP.PowerShell" | where {$_.Version -eq "1.12.0"}
				If($Check_Module_Ver.count -eq 0)
					{
						Install-Module -Name "PnP.PowerShell" -RequiredVersion 1.12.0 -Force -AllowClobber -Scope currentuser
					}
				Import-Module pnp.powershell -RequiredVersion 1.12.0 -force
				$PnP_Module_Status = $True	  
				Write_Log -Message_Type "SUCCESS" -Message "Module PnP imported"					
			}
		Catch
			{
				$PnP_Module_Status = $False	 
				Write_Log -Message_Type "ERROR" -Message "Module PnP not imported"	
				$Reported_error = $error[0].exception.message
				write-output "KO (Module): $Reported_error"
				EXIT 1
			}                                                       
	}

If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
If(test-path $DMP_Logs_folder){remove-item $DMP_Logs_folder -Force -Recurse}
new-item $DMP_Logs_folder -type Directory -force | out-null
If(test-path $DMP_Logs_folder_ZIP){Remove-Item $DMP_Logs_folder_ZIP -Force}

Write_Log -Message_Type "INFO" -Message "A recent BSOD has been found"
Write_Log -Message_Type "INFO" -Message "Date: $Last_DMP"

# Copy hotfix list
$Hotfix_CSV = "$DMP_Logs_folder\Hotfix_List.csv"
$Hotfix_list = Get-wmiobject win32_quickfixengineering | Select-Object hotfixid, Description, Caption, InstalledOn  | Sort-Object InstalledOn 
$Hotfix_list | export-CSV $Hotfix_CSV -delimiter ";" -notypeinformation	

# Copy services list
$Services_CSV = "$DMP_Logs_folder\Services_List.csv"
$services_List = Get-wmiobject win32_service | Select-Object Name, Caption, State, Startmode
$services_List | export-CSV $Services_CSV -delimiter ";" -notypeinformation	

# copy drivers list
$Drivers_CSV = "$DMP_Logs_folder\Drivers_List.csv"
$Drivers_List = gwmi Win32_PnPSignedDriver | Select-Object devicename, manufacturer, driverversion, infname, @{Label="DriverDate";Expression={$_.ConvertToDateTime($_.DriverDate).ToString("MM-dd-yyyy")}}, Description, IsSigned, ClassGuid, HardWareID, DeviceID | where-object {$_.devicename -ne $null -and $_.infname -ne $null} | sort-object devicename -Unique
$Drivers_List | export-CSV $Drivers_CSV -delimiter ";" -notypeinformation

# copy process list	
$Process_CSV = "$DMP_Logs_folder\Process_List.csv"
$Process_List = gwmi win32_process | select ProcessName, caption, CommandLine, path, CreationDate, Description, ExecutablePath, Name, ProcessID, SessionID
$Process_List | export-CSV $Process_CSV -delimiter ";" -notypeinformation

# export pending updates
$Pending_Updates_CSV = "$DMP_Logs_folder\Pending_Updates.csv"
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateupdateSearcher()
$Updates = @($UpdateSearcher.Search("IsHidden=0 and IsInstalled=0 and Type='Software'").Updates)
$Pending_Updates = $Updates  | Select-Object Title, Description, LastdeploymentChangeTime, SupportUrl, Type, RebootRequired 
$Pending_Updates | export-CSV $Pending_Updates_CSV -delimiter ";" -notypeinformation

# Export last reboot date
Get_DeviceUpTime | out-file "$DMP_Logs_folder\Last_reboot_date.txt"

# Export EVTX from last 15 days
Export_Event_Logs -Log_To_Export System -File_Name "System"
Export_Event_Logs -Log_To_Export Application -File_Name "Applications"
Export_Event_Logs -Log_To_Export Security -File_Name "Security"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Power/Thermal-Operational" -File_Name "KernelPower"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Driver Watchdog" -File_Name "KernelPnP_Watchdog"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Configuration" -File_Name "KernelPnp_Conf"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-LiveDump/Operational" -File_Name "KernelLiveDump"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-ShimEngine/Operational" -File_Name "KernelShimEngine"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Boot/Operational" -File_Name "KernelBoot"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-IO/Operational" -File_Name "KernelIO"		

# Copy Dump files
$Minidump_Folder = "C:\Windows\Minidump"
If(test-path $Minidump_Folder){copy-item $Minidump_Folder $DMP_Logs_folder -Recurse -Force}

# $Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)[0]
$Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)
If($Get_BugCheck_Event -ne $null)
	{
		$Get_last_BugCheck_Event = $Get_BugCheck_Event[0]
		$Get_last_BugCheck_Event_Date = $Get_last_BugCheck_Event.TimeGenerated
		$Get_last_BugCheck_Event_MSG = $Get_last_BugCheck_Event.Message	
		$Get_last_BugCheck_Event_MSG | out-file "$DMP_Logs_folder\LastEvent_Message.txt"		
	}

# ZIP DMP folder
Try
	{
		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::CreateFromDirectory($DMP_Logs_folder, $DMP_Logs_folder_ZIP) 
		Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been successfully created"	
		Write_Log -Message_Type "INFO" -Message "The ZIP is located in :$Logs_Collect_Folder_ZIP"				
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while creating the ZIP file"		
		$Reported_error = $error[0].exception.message
		write-output "KO (ZIP): $Reported_error"
		EXIT 1			
	}	

Try
	{
		Connect-PnPOnline -Url $Site_URL -ClientId $ClientID -ClientSecret $Secret -WarningAction Ignore									
		Write_Log -Message_Type "SUCCESS" -Message "Connecting to SharePoint"				
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Connecting to SharePoint"		
		$Reported_error = $error[0].exception.message
		write-output "KO (SP connexion): $Reported_error"
		EXIT 1
	}	
	
Try
	{
		Add-PnPFile -Path $DMP_Logs_folder_ZIP -Folder $Folder_Location | out-null				
		Write_Log -Message_Type "SUCCESS" -Message "Uploading file to SharePoint"	
		Disconnect-pnponline	
		$Upload_file_status = $True
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Uploading file to SharePoint"	
		write-output "Failed step: Uploading file to SharePoint"
		Disconnect-pnponline	
		$Upload_file_status = $False					
	}																						

Remove-Item $DMP_Logs_folder -Force -Recurse
Remove-Item $DMP_Logs_folder_ZIP -Force 

If($Upload_file_status -eq $True)
	{
		write-output "File uploaded"	
		EXIT 0			
	}
Else
	{
		$Reported_error = $error[0].exception.message			
		write-output "KO (Add file): $Reported_error"	
		EXIT 1		
	}