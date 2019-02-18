# =======$=======================================================================
# Script             : start_backup.ps1
# Description        : sécurisation et simplification de la generation des backups
# Paramètres         : parameters.ini
# Retour             : Aucun
# Commentaires       : Aucun
# ------------------------------------------------------------------------------
# Historique :
# Date       Auteur              Description
# ---------- ------------------- -----------------------------------------------
# 27/11/2018 Easyteam            Création du script.
#
# Commande de restauration :
# mongorestore <chemin du dump> --drop --username <user> --password <pass> --authenticationDatabase=admin /gzip

# Initialisation des parametres
$dateOfTheDay = Get-Date -Format yyyyMMdd_HHmm
$paramFile = "parameters.ini"

If(Test-Path $paramFile){
	Get-Content $paramFile | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
}
Else{
	Write-Host "KO: parameter file is missing" -foregroundcolor DarkRed
	exit
}

# Lecture du fichier de configuration
If(($hostname = $h.Get_Item("hostname")) -and ($port = $h.Get_Item("port")) -and ($bin = $h.Get_Item("bin_folder")) -and ($db = $h.Get_Item("db")) -and ($user = $h.Get_Item("user")) -and ($password = $h.Get_Item("password")) -and ($dumpOut = $h.Get_Item("dump_out")) -and ($dumpRetention = $h.Get_Item("dump_retention"))){
	# Suppression des espaces
	$hostname = $hostname.Trim()
	$port = $port.Trim()
	$bin = $bin.TrimEnd()
	$db = $db.Trim()
	$user = $user.Trim()
	$password = $password.Trim()
	$dumpOut = $dumpOut.TrimEnd()
	$dumpRetention = $dumpRetention.Trim()
		
	If(($hostname -ne "NULL") -and ($port -ne "NULL") -and ($bin -ne "NULL") -and ($user -ne "NULL") -and ($password -ne "NULL") -and ($dumpOut -ne "NULL")){
		
		# Démarrage de la log
		$logFile = $dumpOut + "\backup_log_" + $db + "_" + $dateOfTheDay + ".log"
		Start-Transcript -path $logFile -append | Out-null
		Write-Host "INFO: database :" $db -foregroundcolor DarkGray
		Write-Host "INFO: user :" $user -foregroundcolor DarkGray
		
		If($db.ToUpper() -ne "NULL" -AND $db.ToUpper() -ne "ALL"){
		
			# Création du dossier de backup
			$dumpOutUnique = $dumpOut + "\backup_" + $db + "_" + $dateOfTheDay
			New-Item -ItemType Directory -Force -Path $dumpOutUnique | out-null
						
			# Préparation de la commande pour 1 DB
			$cmdBackup = '.\mongodump.exe /host:$hostname /port:$port /out:$dumpOutUnique /db:$db /username:$user /password:$password --authenticationDatabase admin /v /gzip'
		}
		Else{
		
			# Création du dossier de backup
			$dumpOutUnique = $dumpOut + "\backup_all_" + $dateOfTheDay
			New-Item -ItemType Directory -Force -Path $dumpOutUnique | out-null
			Write-Host "INFO: backup output :" $dumpOutUnique -foregroundcolor DarkGray
			
			# Préparation de la commande pour toutes les DB
			$cmdBackup = '.\mongodump.exe /host:$hostname /port:$port /out:$dumpOutUnique /username:$user /password:$password --authenticationDatabase admin /v /gzip'
		}
		Write-Host "INFO: lancement du backup ...."  -foregroundcolor DarkGray
		Write-Host "##############################################################################"
		
		# Execution de la commande de backup
		Set-Location -Path $bin
		Invoke-Expression $cmdBackup -ErrorAction Stop
		Write-Host "##############################################################################"
		
		# Vérficiation du code retour du backup
		# Cas 1 : si backup KO, alors on sort du script, aucun backup ne sera supprimé
		If($LASTEXITCODE -ne 0){
			Write-Host "KO: backup failed" -foregroundcolor DarkRed
			Remove-Item -ItemType Directory -Force -Path $dumpOutUnique | out-null
			exit
		}
		Else{
			# Cas 2 : si backup OK, on purge les anciens
			Write-Host "OK: backup success" -foregroundcolor DarkGreen
			Write-Host "INFO: start cleaning old backup" -foregroundcolor DarkGray
			Write-Host "INFO: retention_date :" $dumpRetention -foregroundcolor DarkGray
			$listFolders = Get-ChildItem -Path $($dumpOut + "\backup_*") -Directory
			$endDate = $((Get-date).AddDays(-$dumpRetention)).ToString("yyyyMMdd")
			
			foreach($folder in $listFolders){
				$folderNameSplit = $($folder -split "_")[2]
				if($folderNameSplit -le $endDate){
					Write-Host "OK: backup will be deleted" $folder -foregroundcolor DarkGreen
					Remove-Item $folder -Force -Recurse
				}
			}
		}
	}
	# Fin de la log
	Stop-Transcript | Out-null
	Move-Item $logFile $dumpOutUnique
}
Else {
	# Un ou plusieurs parametres n'ont pas été définis
	Write-Host "KO: one or more parameters are missing" -foregroundcolor DarkRed
}