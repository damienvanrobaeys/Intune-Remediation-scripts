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
$Secret_Name_New_PWD = ""
#********************************************************************************************

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

# In this function we will install: Nuget package provider and modules Az.accounts, Az.KeyVault module
$Is_Nuget_Installed = $False	
If(!(Get-PackageProvider | where {$_.Name -eq "Nuget"}))
	{			
		Write_Log -Message_Type "INFO" -Message "The package Nuget is not installed"							
		Try
			{
				Write_Log -Message_Type "INFO" -Message "The package Nuget is being installed"						
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force -Confirm:$False | out-null								
				Write_Log -Message_Type "SUCCESS" -Message "The package Nuget has been successfully installed"	
				$Is_Nuget_Installed = $True						
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while installing package Nuget"	
				Break
			}
	}
Else
	{
		$Is_Nuget_Installed = $True	
		Write_Log -Message_Type "INFO" -Message "The package Nuget is already installed"										
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
	
Function Remove_Current_scriptdddd
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
	
If($Az_Module_Install_Mode -eq "Install")
	{
		Install_Az_Module
	}
Else
	{
		Import_from_Blob
	}

$Get_Manufacturer_Info = (gwmi win32_computersystem).Manufacturer
If($Get_Manufacturer_Info -like "*HP*")
	{
		Write_Log -Message_Type "INFO" -Message "Manufacturer: HP"	
		$IsPasswordSet = (Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSetting | Where-Object Name -eq "Setup password").IsSet
	} 
ElseIf($Get_Manufacturer_Info -like "*Lenovo*")
	{
		Write_Log -Message_Type "INFO" -Message "Manufacturer: Lenovo"		
		$IsPasswordSet = (gwmi -Class Lenovo_BiosPasswordSettings -Namespace root\wmi).PasswordState
	} 
ElseIf($Get_Manufacturer_Info -like "*Dell*")
	{
		Write_Log -Message_Type "INFO" -Message "Manufacturer: Dell"	
		$module_name = "DellBIOSProvider"
		If(Get-Module -ListAvailable -Name $module_name)
			{
				import-module $module_name -Force
				Write_Log -Message_Type "INFO" -Message "Module Dell imported"	
			} 
		Else
			{
				Write_Log -Message_Type "INFO" -Message "Module Dell not installed"					
				Install-Module -Name DellBIOSProvider -Force
				Write_Log -Message_Type "INFO" -Message "Module Dell has been installed"									
			}	
		$IsPasswordSet = (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).currentvalue 	
	} 

		# $Check_BIOS_Date = (get-itemproperty $BIOS_PWD_Update_Registry_Path).UpdatedDate
		# $Check_BIOS_Version = (get-itemproperty $BIOS_PWD_Update_Registry_Path).Version			
		# New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "New_PWD_UpdatedDate" -Value $KeyVault_New_PWD_Date -Force | out-null
		# New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "New_PWD_Version" -Value $KeyVault_New_PWD_Version -Force | out-null	

		# New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "Old_PWD_UpdatedDate" -Value $KeyVault_Old_PWD_Date -Force | out-null
		# New-ItemProperty -Path $BIOS_PWD_Update_Registry_Path -Name "Old_PWD_Version" -Value $KeyVault_Old_PWD_Version -Force | out-null	


If(($IsPasswordSet -eq 1) -or ($IsPasswordSet -eq "true") -or ($IsPasswordSet -eq $true) -or ($IsPasswordSet -eq 2))
	{
		Write_Log -Message_Type "INFO" -Message "Your BIOS is password protected"	
		Write_Log -Message_Type "INFO" -Message "Checking if BIOS password is the latest version"		
		
		$BIOS_PWD_Update_Registry_Path = "HKLM:\SOFTWARE\BIOS_Management"
		If(test-path $BIOS_PWD_Update_Registry_Path)
			{
				$Check_New_PWD_Date = (get-itemproperty $BIOS_PWD_Update_Registry_Path).New_PWD_UpdatedDate
				$Check_New_PWD_Version = (get-itemproperty $BIOS_PWD_Update_Registry_Path).New_PWD_Version		

				$Check_Old_PWD_Date = (get-itemproperty $BIOS_PWD_Update_Registry_Path).Old_PWD_UpdatedDate
				$Check_Old_PWD_Version = (get-itemproperty $BIOS_PWD_Update_Registry_Path).Old_PWD_Version						
			}
		Else
			{
				$Check_BIOS_Date = ""
				$Check_BIOS_Version = ""	
				$Check_Old_PWD_Date = ""
				$Check_Old_PWD_Version = ""					
			}		

		Write_Log -Message_Type "INFO" -Message "Connexion to Key Vault"												
		Try
			{
				Connect-AzAccount -tenantid $TenantID -ApplicationId $App_ID -CertificateThumbprint $ThumbPrint | out-null
				Write_Log -Message_Type "SUCCESS" -Message "Connexion to Key Vault"												
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Connexion to Key Vault"	
				Remove_Current_script
				Exit 0					
			}		

		Write_Log -Message_Type "INFO" -Message "Getting last BIOS password version from Key Vault"												
		Try
			{
				$Secret_New_PWD = (Get-AzKeyVaultSecret -vaultName $vaultName -name $Secret_Name_New_PWD) | select *
				$Get_New_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_New_PWD.SecretValue) 
				$Get_PWD_Date = $Secret_New_PWD.Updated
				$Get_PWD_Date = $Get_PWD_Date.ToString("mmddyyyy")
				$Get_PWD_Version = $Secret_New_PWD.Version				
				Write_Log -Message_Type "INFO" -Message "Password last change: $Get_PWD_Date"	
				Write_Log -Message_Type "INFO" -Message "Password last version: $Get_PWD_Version"																	
				Write_Log -Message_Type "INFO" -Message "Getting last BIOS password version from Key Vault"													
				
				Write_Log -Message_Type "SUCCESS" -Message "Getting last BIOS password version from Key Vault"													
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Getting last BIOS password version from Key Vault"		
				Remove_Current_script
				Exit 0					
			}						
		
		If(($Get_PWD_Date -eq $Check_BIOS_Date) -and ($Get_PWD_Version -eq $Check_BIOS_Version))
			{
				Write_Log -Message_Type "SUCCESS" -Message "The device has the latest BIOS password"
				Write-output "The device has the latest BIOS password"		
				Remove_Current_script
				Exit 0		
			}
		Else
			{
				Write_Log -Message_Type "INFO" -Message "The device has not the latest BIOS password"	
				Write_Log -Message_Type "INFO" -Message "The remediation script will be launched"	
				Write-output "The device has not the latest BIOS password"	
				Exit 1		
			}		
	}
Else
	{
		Write_Log -Message_Type "ERROR" -Message "Your BIOS is not password protected"			
		Write-output "Your BIOS is not password protected"			
		Exit 1
	}
