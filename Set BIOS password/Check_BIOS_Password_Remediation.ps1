#********************************************************************************************
# Part to fill
#
# Azure application info (for getting secret from Key Vault)
$TenantID = ""
$App_ID = ""
$ThumbPrint = ""
#
# Mode to install Az modules, 
# Choose Install if you want to install directly modules from PSGallery
# Choose Download if you want to download modules a blob storage and import them
$Az_Module_Install_Mode = "Install" # Install or Download
# Modules path on the web, like blob storage
$Az_Accounts_URL = ""
$Az_KeyVault_URL = ""
#
$vaultName = ""
$Secret_Name_Old_PWD = ""
$Secret_Name_New_PWD = ""
#********************************************************************************************

Function Create_Registry_Content
	{
		param(
		$KeyVault_New_PWD_Date,
		$KeyVault_New_PWD_Version,
		$Key_Vault_Old_PWD_Date,
		$Key_Vault_Old_PWD_Version		
		)       	
	
		$BIOS_PWD_Update_Registry_Path = "HKLM:\SOFTWARE\BIOS_Management"
		If(!(test-path $BIOS_PWD_Update_Registry_Path))
			{
				New-Item $BIOS_PWD_Update_Registry_Path -Force
			}

		New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "New_PWD_UpdatedDate" -Value $KeyVault_New_PWD_Date -Force | out-null
		New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "New_PWD_Version" -Value $KeyVault_New_PWD_Version -Force | out-null	

		New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "Old_PWD_UpdatedDate" -Value $Key_Vault_Old_PWD_Date -Force | out-null
		New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "Old_PWD_Version" -Value $Key_Vault_Old_PWD_Version -Force | out-null			
	}
	
Function Remove_Current_scriptsss
	{
		$Global:Current_Folder = split-path $MyInvocation.MyCommand.Path
		$Content_to_remove = "'$Current_Folder\*'"
		
$ScriptRemove = @"
remove-item $Content_to_remove -Recurse -Force
"@
		$Exported_Script_path = "C:\Windows\Temp\ScriptRemove.ps1"
		$ScriptRemove | out-file $Exported_Script_path -Force
		start-process -WindowStyle hidden powershell.exe $Exported_Script_path 			
	}	
	
Function Import_from_Blob
	{
		$Modules_Path = "$env:temp\Modules"		
		$Az_Accounts_ZIP_Path = "$Modules_Path\Az_Accounts.zip"
		$Az_KeyVault_ZIP_Path = "$Modules_Path\Az_KeyVault.zip"
		$AzAccounts_Module = "$Modules_Path\Az.Accounts"
		$AzKeyVault_Module = "$Modules_Path\Az.KeyVault"

		Write_Log -Message_Type "INFO" -Message "Downloading AZ modules"	
		Try
			{
				Invoke-WebRequest -Uri $Az_Accounts_URL -OutFile $Az_Accounts_ZIP_Path
				Invoke-WebRequest -Uri $Az_KeyVault_URL -OutFile $Az_KeyVault_ZIP_Path
				Write_Log -Message_Type "SUCCESS" -Message "Downloading AZ modules"		
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Downloading AZ modules"		
				Remove_Current_script
				EXIT 1
			}	
		
		Write_Log -Message_Type "INFO" -Message "Extracting AZ modules"	
		Try
			{
				Expand-Archive -Path $Az_Accounts_ZIP_Path -DestinationPath $AzAccounts_Module -Force	
				Expand-Archive -Path $Az_KeyVault_ZIP_Path -DestinationPath $AzKeyVault_Module -Force	
				Write_Log -Message_Type "SUCCESS" -Message "Extracting AZ modules"		
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Extracting AZ modules"
				Remove_Current_script
				EXIT 1
			}	

		Write_Log -Message_Type "INFO" -Message "Importing AZ modules"	
		Try
			{
				import-module $AzAccounts_Module 
				import-module $AzKeyVault_Module 	
				Write_Log -Message_Type "SUCCESS" -Message "Importing AZ modules"		
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Importing AZ modules"		
				Remove_Current_script
				EXIT 1
			}	
	}

Function Install_Az_Module
	{ 	
		If($Is_Nuget_Installed -eq $True)
			{
				$Modules = @("Az.accounts","Az.KeyVault")
				ForEach($Module_Name in $Modules)
					{
						If (!(Get-InstalledModule $Module_Name)) 
							{ 
								Write_Log -Message_Type "INFO" -Message "The module $Module_Name has not been found"	
								Try
									{
										Write_Log -Message_Type "INFO" -Message "The module $Module_Name is being installed"								
										Install-Module $Module_Name -Force -Confirm:$False -AllowClobber -ErrorAction SilentlyContinue | out-null	
										Write_Log -Message_Type "SUCCESS" -Message "The module $Module_Name has been installed"	
										Write_Log -Message_Type "INFO" -Message "AZ.Accounts version $Module_Version"	
									}
								Catch
									{
										Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been installed"			
										write-output "The module $Module_Name has not been installed"			
										Remove_Current_script
										EXIT 1							
									}															
							} 
						Else
							{
								Try
									{
										Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been found"												
										Import-Module $Module_Name -Force -ErrorAction SilentlyContinue 
										Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been imported"	
									}
								Catch
									{
										Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been imported"	
										write-output "The module $Module_Name has not been imported"	
										Remove_Current_script
										EXIT 1							
									}				
							} 				
					}
					
					If ((Get-Module "Az.accounts" -listavailable) -and (Get-Module "Az.KeyVault" -listavailable)) 
						{
							Write_Log -Message_Type "INFO" -Message "Both modules are there"																			
						}
			}
	}


$Log_File = "$env:SystemDrive\Windows\Debug\Set_BIOS_password.log"
If(!(test-path $Log_File)){new-item $Log_File -type file -force}
Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"		
		write-host  "$MyDate - $Message_Type : $Message"		
	}	
	
	
Function Check_Old_Password_version
	{
		param(
		$Key_Vault_Old_PWD_Date,
		$Key_Vault_Old_PWD_Version	
		)       		
		$BIOS_PWD_Update_Registry_Path = "HKLM:\SOFTWARE\BIOS_Management"
		If(test-path $BIOS_PWD_Update_Registry_Path)
			{
				$Check_Old_PWD_Date = (get-itemproperty $BIOS_PWD_Update_Registry_Path).Old_PWD_UpdatedDate
				$Check_Old_PWD_Version = (get-itemproperty $BIOS_PWD_Update_Registry_Path).Old_PWD_Version	
				
				If(($Key_Vault_Old_PWD_Date -ne $Check_Old_PWD_Date) -and ($Key_Vault_Old_PWD_Version -ne $Check_Old_PWD_Version))
					{
						Write_Log -Message_Type "INFO" -Message "The current device password on the device is not the same than this one on the Key Vault"						
						Write_Log -Message_Type "INFO" -Message "Current device BIOS password Key Vault secret version: $Check_Old_PWD_Version"	
						# Write_Log -Message_Type "INFO" -Message "Current Key Vault BIOS password version: $Key_Vault_Old_PWD_Version"						
						Write_Log -Message_Type "INFO" -Message "Current device BIOS password date: $Check_Old_PWD_Date"	
						# Write_Log -Message_Type "INFO" -Message "Current Key Vault BIOS password date: $Key_Vault_Old_PWD_Date"												
					}
			}
	}
	

# We will install the Az.accounts module
$Is_Nuget_Installed = $False	
If (!(Get-PackageProvider NuGet -listavailable)) 
	{
		Try
			{
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force | out-null							
				Write_Log -Message_Type "SUCCESS" -Message "The package $Module_Name has been successfully installed"	
				$Is_Nuget_Installed = $True						
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while installing package $Module_Name"	
				Break
			}
	}
Else
	{
		$Is_Nuget_Installed = $True	
	}
	
If($Is_Nuget_Installed -eq $True)
	{
		If($Az_Module_Install_Mode -eq "Install")
			{
				Install_Az_Module
			}
		Else
			{
				Import_from_Blob
			}	
	}


If(($TenantID -eq "") -and ($App_ID -eq "") -and ($ThumbPrint -eq ""))
	{
		Write_Log -Message_Type "ERROR" -Message "Info is missing, please fill: TenantID, appid and thumbprint"		
		write-output "Info is missing, please fill: TenantID, appid and thumbprint"
		Remove_Current_script
		EXIT 1					
	}Else
	{
		$Appli_Infos_Filled = $True
	}
	
If($Appli_Infos_Filled -eq $True)
	{			
		Try
			{
				Write_Log -Message_Type "INFO" -Message "Connecting to your Azure application"														
				Connect-AzAccount -tenantid $TenantID -ApplicationId $App_ID -CertificateThumbprint $ThumbPrint | Out-null
				Write_Log -Message_Type "SUCCESS" -Message "Connection OK to your Azure application"			
				$Azure_App_Connnected = $True
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Connection KO to your Azure application"	
				write-output "Connection KO to your Azure application"	
				Remove_Current_script
				EXIT 1							
			}

		If($Azure_App_Connnected -eq $True)
			{
				# Getting the old password
				$Secret_Old_PWD = (Get-AzKeyVaultSecret -vaultName $vaultName -name $Secret_Name_Old_PWD) | select *
				$Get_Old_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_Old_PWD.SecretValue) 
				$Old_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_Old_PWD) 
				# $Get_Old_PWD_Date = $Secret_Old_PWD.Updated
				# $Get_Old_PWD_Date = $Get_Old_PWD_Date.ToString("mmddyyyy")
				# $Get_Old_PWD_Version = $Secret_Old_PWD.Version		

				
				# Getting the new password
				$Secret_New_PWD = (Get-AzKeyVaultSecret -vaultName $vaultName -name $Secret_Name_New_PWD) | select *
				$Get_New_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_New_PWD.SecretValue) 
				$New_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_New_PWD) 			
				$Get_New_PWD_Date = $Secret_New_PWD.Updated
				$Get_New_PWD_Date = $Get_New_PWD_Date.ToString("mmddyyyy")
				$Get_New_PWD_Version = $Secret_New_PWD.Version		

				$Getting_KeyVault_PWD = $True
				
				Write_Log -Message_Type "INFO" -Message "Current password is: $Old_PWD"																				
				Write_Log -Message_Type "INFO" -Message "New password is: $New_PWD"		
			}

		If($Getting_KeyVault_PWD -eq $True)
			{
				$Get_Manufacturer_Info = (gwmi win32_computersystem).Manufacturer
				Write_Log -Message_Type "INFO" -Message "Manufacturer is: $Get_Manufacturer_Info"											

				If(($Get_Manufacturer_Info -notlike "*HP*") -and ($Get_Manufacturer_Info -notlike "*Lenovo*") -and ($Get_Manufacturer_Info -notlike "*Dell*"))
					{
						Write_Log -Message_Type "ERROR" -Message "Device manufacturer not supported"											
						Break
						write-output "Device manufacturer not supported"		
						Remove_Current_script
						EXIT 1									
					}

				If($Get_Manufacturer_Info -like "*Lenovo*")
					{
						$IsPasswordSet = (gwmi -Class Lenovo_BiosPasswordSettings -Namespace root\wmi).PasswordState
					}
				ElseIf($Get_Manufacturer_Info -like "*HP*")
					{
						$IsPasswordSet = (Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSetting | Where-Object Name -eq "Setup password").IsSet							
					} 
				ElseIf($Get_Manufacturer_Info -like "*Dell*")
					{
						$module_name = "DellBIOSProvider"
						If (Get-InstalledModule -Name DellBIOSProvider){import-module DellBIOSProvider -Force} 
						Else{Install-Module -Name DellBIOSProvider -Force}	
						$IsPasswordSet = (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).currentvalue 	
					} 

				If(($IsPasswordSet -eq 1) -or ($IsPasswordSet -eq "true") -or ($IsPasswordSet -eq 2))
					{
						$Is_BIOS_Password_Protected = $True	
						Write_Log -Message_Type "INFO" -Message "There is a current BIOS password"																				
					}
				Else
					{
						$Is_BIOS_Password_Protected = $False
						Write_Log -Message_Type "INFO" -Message "There is no current BIOS password"													
					}

				If($Is_BIOS_Password_Protected -eq $True)
					{
						If($Get_Manufacturer_Info -like "*HP*")
							{
								Write_Log -Message_Type "INFO" -Message "Changing BIOS password for HP"											
								Try
								{
									$bios = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSettingInterface
									$bios.SetBIOSSetting("Setup Password","<utf-16/>" + "NewPassword","<utf-16/>" + "OldPassword")				
									Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"	
									write-output "Change password: Success"		
									Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
									Remove_Current_script
									EXIT 0
								}
								Catch
								{
									Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"	
									write-output "Change password: Failed"		
									Check_Old_Password_version -Key_Vault_Old_PWD_Date $Get_Old_PWD_Date -Key_Vault_Old_PWD_Version	$Get_Old_PWD_Version									
									Remove_Current_script
									EXIT 1	
								}		
							} 
						ElseIf($Get_Manufacturer_Info -like "*Lenovo*")
							{
								Write_Log -Message_Type "INFO" -Message "Changing BIOS password for Lenovo"											
								Try
								{
									$PasswordSet = Get-WmiObject -Namespace root\wmi -Class Lenovo_SetBiosPassword
									$PasswordSet.SetBiosPassword("pap,$Old_PWD,$New_PWD,ascii,us") | out-null				
									Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"	
									write-output "Change password: Success"				
									Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
									Remove_Current_script
									EXIT 0					
								}
								Catch
								{
									Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"		
									write-output "Change password: Failed"			
									Check_Old_Password_version -Key_Vault_Old_PWD_Date $Get_Old_PWD_Date -Key_Vault_Old_PWD_Version	$Get_Old_PWD_Version									
									Remove_Current_script
									EXIT 1						
								}						
							} 
						ElseIf($Get_Manufacturer_Info -like "*Dell*")
							{
								Write_Log -Message_Type "INFO" -Message "Changing BIOS password for Dell"	
								$New_PWD_Length = $New_PWD.Length
								If(($New_PWD_Length -lt 4) -or ($New_PWD_Length -gt 32))
									{
										Write_Log -Message_Type "ERROR" -Message "New password length is not correct"	
										Write_Log -Message_Type "ERROR" -Message "Password must contain minimum 4, and maximum 32 characters"			
										Write_Log -Message_Type "INFO" -Message "Password length: $New_PWD_Length"												
										write-output "Password must contain minimum 4, and maximum 32 characters"	
										Remove_Current_script
										EXIT 1												
									}
								Else
									{
										Write_Log -Message_Type "INFO" -Message "Password length: $New_PWD_Length"																							
										Try
											{
												Set-Item -Path DellSmbios:\Security\AdminPassword $New_PWD -Password $Old_PWD -ErrorAction stop											
												Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"			
												write-output "Change password: Success"		
												Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
												# Remove_Current_script
												EXIT 0					
											}
											Catch
											{
												$Exception_Error = $error[0]
												Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"
												Write_Log -Message_Type "ERROR" -Message "Error: $Exception_Error"																										
												write-output "Change password: Failed"				
												# Remove_Current_script
												Check_Old_Password_version -Key_Vault_Old_PWD_Date $Get_Old_PWD_Date -Key_Vault_Old_PWD_Version	$Get_Old_PWD_Version									
												EXIT 1					
											}											
									}			
							} 																		
					}
				Else
					{
						If($Get_Manufacturer_Info -like "*HP*")
							{
								Write_Log -Message_Type "INFO" -Message "Changing BIOS password for HP"											
								Try
								{
									$bios = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSettingInterface
									$bios.SetBIOSSetting("Setup Password","<utf-16/>" + "NewPassword","<utf-16/>")			
									Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"		
									write-output "Change password: Success"		
									Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
									Remove_Current_script
									EXIT 0					
								}
								Catch
								{
									Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"														
									write-output "Change password: Failed"	
									Remove_Current_script
									EXIT 1					
								}				
							} 
						ElseIf($Get_Manufacturer_Info -like "*Lenovo*")
							{
								write-output "The is no current password. An initial password should be configured first"	
								Write_Log -Message_Type "INFO" -Message "There is no current BIOS password"	
								Remove_Current_script
								EXIT 1
							} 
						ElseIf($Get_Manufacturer_Info -like "*Dell*")
							{				
								Write_Log -Message_Type "INFO" -Message "Changing BIOS password for HP"											
								Try
								{
									Set-Item -Path DellSmbios:\Security\AdminPassword "$AdminPwd"
									Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"		
									write-output "Change password: Success"			
									Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
									Remove_Current_script
									EXIT 0											
								}
								Catch
								{
									Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"														
									write-output "Change password: Failed"				
									Remove_Current_script
									EXIT 1					
								}					
							} 
					}
			}					
	}