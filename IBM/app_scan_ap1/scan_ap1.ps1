# Définition des variables
$datetosave = Get-Date -Format ddMMyyyy_HHmm
$dateactivenc = Get-Date -Format yyyyMMdd
$xmltemp = "D:\exploitation\Scripts\CAROLINE_PSBO\CONF\template.xml"
$xmlscan = "D:\exploitation\Scripts\CAROLINE_PSBO\RESULT\result_decentralise.xml"
$xmlhisto = "D:\exploitation\Scripts\CAROLINE_PSBO\RESULT\HISTO\result_decentralise_$datetosave.xml"
$ConfigMagasin = [xml](Get-Content "X:\Config\CarolineMagasins.xml")
$ConfigServer = [xml](Get-Content "X:\Config\CarolineServeurs.xml")
$xmlresult = [xml](Get-Content $xmltemp)

# Récupération du codeMagasin
$tabmag = $ConfigMagasin | Select-XML -XPath "//Magasin" | Select-Object -ExpandProperty Node

# Check du serveur Web
$service = Get-Process Zwamp -ErrorAction SilentlyContinue
if($service -eq $null){
	Invoke-Item "D:\exploitation\Scripts\CAROLINE_PSBO\WAMP\zwamp.exe" 
}
else{
	Do{
		$ProcessesFound = Get-Process Zwamp -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
		If ($ProcessesFound){
			Stop-Process -processname zwamp
			Start-Sleep -Seconds 2
		}
	}Until (!$ProcessesFound)
	Invoke-Item "D:\exploitation\Scripts\CAROLINE_PSBO\WAMP\zwamp.exe" 
	Write-Host "Serveur WEB ok"
}

foreach($var in $tabmag){
	if($var.Partenaires.Balances.Etat -eq "ACTIF"){	
		# Definition des variables de chaque magasin
		$AP1num = $var.CodeANABEL
		$Batch = $var.Serveurs.Batch.Cluster
		$Emission ="X:\Donnees\MAG$AP1num\Interfaces\Emission"
		$Reception = "X:\Donnees\MAG$AP1num\Interfaces\Reception"
		$FQDN = 'FR' + $AP1num + 'host.domain.com'
		$transfert = '\\' + $FQDN + '\d$\applicat\data\EchangesFO\Transferts'
		$histo = '\\' + $FQDN + '\d$\applicat\data\EchangesFO\Histo\OK'
		$logU= '\\' + $FQDN + '\c$\soft\universe\FS-LOG\FR' + $AP1num + 'AP1\CSIFPR\exp'
		$BAL = '\\' + $FQDN + '\d$\applicat\Data\Balances\Import'
		$carobatch = '\\' + $FQDN + '\d$\Exploitation\CAROLINE\REPLAY_AP1.txt'

		# Identification des fichiers bloques en DECENTRALISE
		if((Test-Path $transfert) -eq $True){
			$scan = get-childitem $transfert | Where-Object {$_.lastWriteTime -lt ((Get-Date).AddHours(-2)) -and ($_.Name -match "$AP1num") -and !($_.Name -match ".evts") -and !($_.Name -match "evts.") -and !($_.Name -match ".launchkey") -and ($_.length -gt 1)} | Select Name -ExpandProperty Name
			if(($scan | measure | Select Count -ExpandProperty Count) -ge 1){
				# Purge de l'ancien fichier de logU
				if((Test-Path $carobatch) -eq $True){
					Remove-Item $carobatch
				}
				# Check $u
				[datetime]$Date = Get-Item $logU | Foreach {$_.LastAccessTime}
				$univerStatus = 0
				if($date -ge ((Get-Date).AddMinutes(-40)))
				{
					$univerStatus = 1
				}
				# Check Interpel
				$interpel = Get-WmiObject Win32_Process -computername $FQDN -Filter "name='ipelsock.exe'" | Select Name -ExpandProperty Name 
				$interpelStatus = 0
				if($interpel){
					$interpelStatus = 1
				}
				# Check Encaissement A ECRIRE, via recuperation activenc ?
				#$encaissement = get-childitem $histo -Name -Include "ActivEnc_$AP1num.$dateactivenc*"
				
				$AP1xml = $xmlresult.CreateElement('AP1')
				$AP1xml.SetAttribute('CodeMag',$AP1num)	
				$AP1xml.SetAttribute('UniverStatus',$univerStatus)	
				$AP1xml.SetAttribute('InterpelStatus',$interpelStatus)	
				$AP1xml.SetAttribute('EncaissementStatus','1')	
				$AP1xml.SetAttribute('BatchServ',$Batch)	
				
				# Récupération des vieux fichiers
				foreach($file in $scan){
					$FILExml = $xmlresult.CreateNode('element', 'FILE', '')
					$key = $xmlresult.CreateTextNode($file)
					$FILExml.AppendChild($key)
					$AP1xml.AppendChild($FILExml)			
				}
								
				# Tri pour ne garder que les fichiers - 24h
				# $toreplay = get-childitem $transfert | Where-Object {$_.lastWriteTime -lt ((Get-Date).AddHours(-2)) -and ($_.lastWriteTime -gt ((Get-Date).AddHours(-24))) -and ($_.Name -match "$AP1num") -and !($_.Name -match ".evts") -and !($_.Name -match "evts.") -and !($_.Name -match ".launchkey") -and !($_.Name -match "MAJART_")} | Select Name -ExpandProperty Name
				
				# Preparation du fichier qui stocker les fichiers à rejouer
				# New-Item -type file $transfertoreplay -Force
				# foreach($file in $toreplay){
				#	Add-Content $transfertoreplay "`n$file"	
				# }
				
				$svc = $xmlresult.SelectSingleNode('//DECENTRALISE')
				$svc.AppendChild($AP1xml)
			} 
		}
		##  Identification des fichiers bloques en CENTRALISE RECEPTION
		#if((Test-Path $Reception) -eq $True){
		#	$scan = get-childitem $Reception | Where-Object {$_.lastWriteTime -lt ((Get-Date).AddHours(-2)) -and ($_.Name -match "$AP1num") -and !($_.Name -match "evts.") -and !($_.Name -match ".xml")} | Select Name -ExpandProperty Name		
		#	if(($scan | measure | Select Count -ExpandProperty Count) -ge 1){
		#		$AP1xml = $xmlresult.CreateElement('CodeMag')
		#		$AP1xml.SetAttribute('name',$AP1num)		
		#		foreach($file in $scan){
		#			Write-Host $file
		#			$FILExml = $xmlresult.CreateNode('element', 'FILE', '')
		#			$key = $xmlresult.CreateTextNode($file)
		#			$FILExml.AppendChild($key)
		#			$AP1xml.AppendChild($FILExml)
		#		}
		#		$svc = $xmlresult.SelectSingleNode('//CENTRALISE/RECEPTION')
		#		$svc.AppendChild($AP1xml)
		#	} 
		#}
		##  Identification des fichiers bloques en CENTRALISE EMISSION
		#if((Test-Path $Emission) -eq $True){
		#	$scan = get-childitem $Emission | Where-Object {$_.lastWriteTime -lt ((Get-Date).AddHours(-2)) -and ($_.Name -match "$AP1num") -and !($_.Name -match "evts.") -and !($_.Name -match ".xml")} | Select Name -ExpandProperty Name
		#	if(($scan | measure | Select Count -ExpandProperty Count) -ge 1){
		#		$AP1xml = $xmlresult.CreateElement('CodeMag')
		#		$AP1xml.SetAttribute('name',$AP1num)		
		#		foreach($file in $scan){
		#			$FILExml = $xmlresult.CreateNode('element', 'FILE', '')
		#			$key = $xmlresult.CreateTextNode($file)
		#			$FILExml.AppendChild($key)
		#			$AP1xml.AppendChild($FILExml)
		#		}
		#		$svc = $xmlresult.SelectSingleNode('//CENTRALISE/EMISSION')
		#		$svc.AppendChild($AP1xml)
		#	} 
		#}
	}
}
# Historisation du fichier précédent
Move-Item $xmlscan $xmlhisto
Remove-Item D:\exploitation\Scripts\CAROLINE_PSBO\WAMP\vdrive\web\LOCK\*.lock
$xmlresult.Save($xmlscan)

