#=============================================================
# Config
#=============================================================
# If using Azure application with a secret
# $tenant = ""
$tenant = ""
$authority = "https://login.windows.net/$tenant"
$clientId = ""
$clientSecret = ''
# If using Azure application with a secret

$Script_name = ""
$Export_Path = ""
#=============================================================
#=============================================================

# If using Azure application with a secret
Update-MSGraphEnvironment -AppId $clientId -Quiet
Update-MSGraphEnvironment -AuthUrl $authority -Quiet
Connect-MSGraph -ClientSecret $ClientSecret -Quiet
# If using Azure application with a secret

# Connect-MSGraph 

# connect-msgraph
$Main_Path = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
$Get_script_info = (Invoke-MSGraphRequest -Url $Main_Path -HttpMethod Get).value | Where{$_.DisplayName -like "*$Script_name*"}
$Get_Script_ID = $Get_script_info.id

$Filter_ID = "'$Get_Script_ID'"
$Full_filter = "PolicyId eq $filter_ID"
$MyScript = @"
{
	"reportName":"DeviceRunStatesByProactiveRemediation",
	"filter":"$Full_filter",
	"select":[],"format":"csv",
	"snapshotId":""
}
"@

$Export_Remediation = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs"  -HttpMethod POST -Content $MyScript -ErrorAction Stop
$Export_Remediation_ID = $Export_Remediation.ID

$RunStatesByProactiveRemediation_Value = "'$Export_Remediation_ID'"
$Get_URL = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs($RunStatesByProactiveRemediation_Value)" -HttpMethod GET -ErrorAction Stop

Do{
	$Get_URL = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs($RunStatesByProactiveRemediation_Value)" -HttpMethod GET -ErrorAction Stop
	If($Get_URL.status -eq "inProgress")
		{
			write-host "Still in progress"
			start-sleep 5
		}

} Until ($Get_URL.status -eq "completed")
$Get_URL = $Get_URL.url
Invoke-WebRequest -Uri $Get_URL -OutFile $Export_Path 
write-warning "Proactive Remediation $Script_name has been exported in $Export_Path"


