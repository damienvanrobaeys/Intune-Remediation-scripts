# ********************************************************************
# ADD YOUR CODE THERE
# ********************************************************************

# MY CODE

# ********************************************************************
# ADD YOUR CODE THERE
# ********************************************************************




# ********************************************************************
# AUTOREMOVE PART
# ********************************************************************
$mypath = $MyInvocation.MyCommand.Path
$Get_Directory = (Get-Item $mypath | select *).DirectoryName

$Remove_script_Path = "$env:temp\Remove_current_remediation.ps1"
$Remove_script = @"
Do {  
	`$ProcessesFound = gwmi win32_process | where {`$_.commandline -like "*$Get_Directory*"} 
    If (`$ProcessesFound) {
        Start-Sleep 5
    }
} Until (!`$ProcessesFound)
cmd /c "rd /s /q $Get_Directory"
"@
$Remove_script | out-file $Remove_script_Path
start-process -WindowStyle hidden powershell.exe $Remove_script_Path
# ********************************************************************
# AUTOREMOVE PART
# ********************************************************************
