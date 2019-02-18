# Définition des variables
$datetosave = Get-Date -Format ddMMyyyy_HHmm
$dateactivenc = Get-Date -Format yyyyMMdd
$xmltemp = "D:\exploitation\Scripts\CAROLINE_PSBO\CONF\template.xml"
$xmlscan = "D:\exploitation\Scripts\CAROLINE_PSBO\RESULT\result.xml"
$xmlhisto = "D:\exploitation\Scripts\CAROLINE_PSBO\RESULT\HISTO\result_$datetosave.xml"
$ConfigMagasin=[xml](Get-Content "X:\Config\CarolineMagasins.xml")
$xmlresult=[xml](Get-Content $xmltemp)

# Historisation du fichier précédent
Move-Item $xmlscan $xmlhisto

# Récupération du codeMagasin
$xml_mag = $ConfigMagasin.SelectNodes('//Magasins/Magasin') | Select CodeANABEL

foreach($var in $xml_mag){
	# Definition des variables de chaque magasin
	$AP1num = $var.CodeANABEL
	$Emission ="X:\Donnees\MAG$AP1num\Interfaces\Emission"
	$Reception = "X:\Donnees\MAG$AP1num\Interfaces\Reception"
	$FQDN = 'FR' + $AP1num + 'host.domain.com'
	$transfert = '\\' + $FQDN + '\d$\applicat\data\EchangesFO\Transferts'
	$histo = '\\' + $FQDN + '\d$\applicat\data\EchangesFO\Histo\OK'
	$logU= '\\' + $FQDN + '\c$\soft\universe\FS-LOG\FR' + $AP1num + 'AP1\CSIFPR\exp'
	
	# Identification des fichiers bloques en DECENTRALISE
	if((Test-Path $transfert) -eq $True){
		$scan = get-childitem $transfert -Name -Include "*$AP1num*" -Exclude "evts.*" | Where-Object {$_.lastWriteTime -le (Get-Date).AddHours(-2)}
		if($scan.Count -ge 1){
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
			
			foreach($file in $scan){
				$FILExml = $xmlresult.CreateNode('element', 'FILE', '')
				$key = $xmlresult.CreateTextNode($file)
				$FILExml.AppendChild($key)
				$AP1xml.AppendChild($FILExml)
			}
			$svc = $xmlresult.SelectSingleNode('//DECENTRALISE')
			$svc.AppendChild($AP1xml)
		} 
	}
	#  Identification des fichiers bloques en CENTRALISE RECEPTION
	if((Test-Path $Reception) -eq $True){
		$scan = get-childitem $Reception -Name -Include "*$AP1num*" -Exclude "evts.*","*.xml" | Where-Object {$_.lastWriteTime -le (Get-Date).AddHours(-1)}
		if($scan.Count -ge 1){
			$AP1xml = $xmlresult.CreateElement('CodeMag')
			$AP1xml.SetAttribute('name',$AP1num)		
			foreach($file in $scan){
				$FILExml = $xmlresult.CreateNode('element', 'FILE', '')
				$key = $xmlresult.CreateTextNode($file)
				$FILExml.AppendChild($key)
				$AP1xml.AppendChild($FILExml)
			}
			$svc = $xmlresult.SelectSingleNode('//CENTRALISE/RECEPTION')
			$svc.AppendChild($AP1xml)
		} 
	}
	#  Identification des fichiers bloques en CENTRALISE EMISSION
	if((Test-Path $Emission) -eq $True){
		$scan = get-childitem $Emission -Name -Include "*$AP1num*" -Exclude "evts.*","*.xml" | Where-Object {$_.lastWriteTime -le (Get-Date).AddHours(-1)}
		if($scan.Count -ge 1){
			$AP1xml = $xmlresult.CreateElement('CodeMag')
			$AP1xml.SetAttribute('name',$AP1num)		
			foreach($file in $scan){
				$FILExml = $xmlresult.CreateNode('element', 'FILE', '')
				$key = $xmlresult.CreateTextNode($file)
				$FILExml.AppendChild($key)
				$AP1xml.AppendChild($FILExml)
			}
			$svc = $xmlresult.SelectSingleNode('//CENTRALISE/EMISSION')
			$svc.AppendChild($AP1xml)
		} 
	}
}
$xmlresult.Save($xmlscan)


