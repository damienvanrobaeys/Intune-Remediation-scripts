param(
[Parameter(Mandatory=$true)][string]$Pattern,	
[switch]$GridView,		
[switch]$PST
)

# Prompt credentials
# Connect-MgGraph

# With a secret
# $tenantID = ""
# $clientId = ""
# $Secret = ""
# $myAccessToken = Get-MsalToken -ClientId $clientID -TenantId $tenantID -ClientSecret $Secret
# Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential

# With a certificate
# $Script:tenantID = ""
# $Script:clientId = ""	
# $Script:Thumbprint = ""
# Connect-MgGraph -Certificate $ClientCertificate -TenantId $TenantId -ClientId $ClientId  | out-null		

$Remediations_URL = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
$Get_Scripts = (Invoke-MgGraphRequest -Uri $Remediations_URL  -Method GET).value	
$Data_Array = @()
ForEach($Script in $Get_Scripts)
{
	$Script_Name = $Script.displayName
	$Script_Id = $Script.id

	$Script_info = "$Remediations_URL/$Script_Id"
	$Get_Script_info = (Invoke-MgGraphRequest -Uri $Script_info  -Method GET -SkipHttpErrorCheck)	

	$Detection = $Get_Script_info.detectionScriptContent	
	If($Detection -eq $null){
		$String_Found = "Empty"
		$String_in_detection = "Empty"		
	}Else{
		$Detection_Decoded = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Detection))
		$Detection_check = $Detection_Decoded | Select-String "$Pattern"
		If($Detection_check -ne $null)
		{
			$String_in_detection = "Yes"
		}Else{
			$String_in_detection = "No"
		}				
	}
	
	$Remediation = $Get_Script_info.remediationScriptContent	
	If($Remediation -eq $null){
		$String_Found = "Empty"
		$String_in_remediation = "Empty"		
	}Else{
		$Remediation_Decoded = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Remediation))
		$Remediation_Check = $Remediation_Decoded | Select-String "$Pattern"	
		If($Remediation_Check -ne $null)
		{
			$String_in_remediation = "Yes"
		}Else{
			$String_in_remediation = "No"
		}				
	}	
	
	If(($Detection_check -ne $null) -or ($Remediation_Check -ne $null))
		{
			$String_Found = "Yes"		
		}Else{
			$String_Found = "No"		
		}
			
	$Obj = [PSCustomObject]@{
		Name     				= $Script_Name
		ID     					= $Script_Id
		"With string"     		= $String_Found		
		"String in detection" 	= $String_in_detection
		"String in remediation" = $String_in_remediation		
	}
	
	$Data_Array += $Obj
}	

$Data_With_String = $Data_Array | where {$_."With string" -eq "Yes"}
If($GridView){$Data_With_String | Out-GridView}
If($PST){$Data_With_String | Export-Csv -Path "$env:temp\CVE-2025-54100_Script_Report.csv" -NoTypeInformation -Encoding UTF8;invoke-item $env:temp}


