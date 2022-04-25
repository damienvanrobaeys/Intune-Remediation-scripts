#*********************************************************************************************************
# Part to fill
$Size_Alert = "10000000000"
# 20000000000 (Bytes) is 10GB
#*********************************************************************************************************

$Recycle_Bin_Size = (Get-ChildItem -LiteralPath 'C:\$Recycle.Bin' -File -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

Function Format_Size
	{
		param(
		$size	
		)	
		
		$suffix = "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
		$index = 0
		while ($size -gt 1kb) 
		{
			$size = $size / 1kb
			$index++
		} 

		"{0:N2} {1}" -f $size, $suffix[$index]
	}
	
$RecycleBin_FormatedSize = Format_Size	$Recycle_Bin_Size

If($Recycle_Bin_Size -ge $Size_Alert)
	{
		write-output "Size: $RecycleBin_FormatedSize"			
		EXIT 1				
	}
Else
	{
		write-output "Size: $RecycleBin_FormatedSize"			
		EXIT 0			
	}	
