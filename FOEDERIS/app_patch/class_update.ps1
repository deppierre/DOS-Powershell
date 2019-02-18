cls
function pause(){
	[void][System.Console]::ReadKey($true)
}
$driveLetter = (get-location).Drive.Name
New-Item -ItemType Directory -Force -Path .\sauvegarde\new | out-null
New-Item -ItemType Directory -Force -Path .\sauvegarde\old | out-null
Remove-Item .\sauvegarde\new\*
Remove-Item .\sauvegarde\old\*
Copy-Item .\classtoupdate\* -Destination .\sauvegarde\new\ -Force

pushd
$custName = [System.IO.Path]::GetFileNameWithoutExtension($(get-childitem .\classtoupdate\*.cust).Name)

if($rPath = Get-ChildItem "$($driveLetter):\Tomcat*\webapps\*$($custName)*" | where {$_.Attributes -match'Directory'}){
	foreach($path in $rPath){
		Write-Host "INFO: Le chemin jFoederis est $($path)" -foregroundcolor DarkGray
		
		$classToUpdate = Get-ChildItem -Path .\classtoupdate\ -Filter *.class | Select Name -expandproperty Name

		foreach ($class in $classToUpdate) {
			$classFind = Get-ChildItem -Path "$($path)\WEB-INF\classes\com\foederis" -Filter $class -Recurse | Select FullName -expandproperty FullName
			$classFindName = Get-ChildItem -Path "$($path)\WEB-INF\classes\com\foederis" -Filter $class -Recurse | Select Name -expandproperty Name
			$classCount = $classFind | Measure-Object | Select Count -expandproperty Count
			
			if(($classCount -le 1) -and ($classCount -gt 0)){
				Write-Host "INFO: sauvegarde du fichier $($classFindName)" -foregroundcolor DarkGray	
				Copy-Item $classFind -Destination .\sauvegarde\old\ -Force
				
				try{
					Write-Host "INFO: mise a jour du fichier $($class)" -foregroundcolor DarkGray
					New-Item -ItemType File -Path $classFind -Force | out-null
					Copy-Item .\classtoupdate\$class -Destination $classFind -Force
				}
				catch{
					Write-Host "ERROR: Copie de $($class) KO" -foregroundcolor DarkRed
					pause
				}
			}		
			else{
				Write-Host "WARNING: Fichier $($class) non trouve" -foregroundcolor DarkRed
				$ynQuestion = Read-Host "Voulez-vous rajouter cette nouvelle classe (o/n) ?"
				$ynQuestion = $ynQuestion.ToLower()
				if($ynQuestion -eq "o"){
					try{
						$newPath = Read-Host "Dans quel dossier creer cette classe ? (chemin du type : \WEB-INF\classes\com\foederis\...)"
						$newPath = "$($path)\$($newPath)\$($class)"
						Write-Host "INFO: creation du fichier $($class)" -foregroundcolor DarkGray
						New-Item -ItemType File -Path $newPath -Force | out-null
						Copy-Item .\classtoupdate\$class -Destination $newPath -Force
					}
					catch{
						Write-Host "ERROR: Copie de $($class) KO" -foregroundcolor DarkRed
						pause
					}
				}
			}
		}
	}
	
	$date = get-date -format ddMMyyyy_HHmm
	$saveDir = "$($driveLetter):\MAJ\ARCHIVE"
	$saveFile = "$($saveDir)\patch_$($date)_$custName.7z"
	Write-Host "SUCCESS: Creation de larchive de sauvegarde $($saveFile)" -foregroundcolor DarkGreen
    
	New-Item -ItemType Directory -Path $saveDir -Force | out-null
	$cmd=".\sources\7-Zip\7z.exe a -t7z $($saveFile) .\sauvegarde\*"
	Invoke-Expression $cmd | out-null
}
else{
	Write-Host "Client introuvable" -foregroundcolor DarkRed
	pause
	exit
}