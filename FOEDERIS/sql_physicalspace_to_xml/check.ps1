pushd
$currentDir=(pwd).Path
$dateToSave = Get-Date -Format ddMMyyyy_HHmm
$xmlSource = [xml](Get-Content template.xml)
$serverList = Get-Content("C:\Users\pde\Documents\Pro\#2_Script\disk_space\server_list.txt")

#Creation fichier resultat
New-Item $currentDir\result -ItemType Directory -Force | Out-Null
$xmlResult="$currentDir\result\xml_result_$datetosave.xml"

$login = Read-Host "Quel login voulez vous utiliser ? "
$cred = Get-Credential -Credential "domain\$login"

foreach($item in $serverList){
	$fullcomputerName="$item.domain.FR"
	Write-Host "Scan $fullcomputerName ..."
	
	try{
		$diskE = get-WmiObject win32_logicaldisk -Computername $fullcomputerName -Credential $cred -Filter "DeviceID='E:'" | Select-Object Size, FreeSpace
		$diskD = get-WmiObject win32_logicaldisk -Computername $fullcomputerName -Credential $cred -Filter "DeviceID='D:'" | Select-Object Size, FreeSpace
	}
	catch{
		Write-Host "Erreur de connexion" 
		$fullcomputerName | out-file $currentDir\result\error.txt -append
	}
		
	Function addXml($type, $value){
		$temp = $xmlSource.CreateNode('element', $type, '')
		$key = $xmlSource.CreateTextNode($value)
		$temp.AppendChild($key)
		$serverXml.AppendChild($temp)
		
		$svc = $xmlSource.SelectSingleNode('//diskstatus')
		$svc.AppendChild($serverXml)
	}
    
	if((($diskE | foreach{$_.FreeSpace}) -ne $null) -or (($diskD | foreach{$_.FreeSpace}) -ne $null)){	
		if((($diskE | foreach{$_.FreeSpace}) -ne $null)){
			$serverXml = $xmlSource.CreateElement('server')
			$serverXml.SetAttribute('name',$item)
			$serverXml.SetAttribute('drive','E:')
			
			$percent=[math]::truncate(($diskE.FreeSpace * 100) / $diskE.Size)
			$total=[math]::truncate($diskE.FreeSpace / 1GB)
			
			#pourcentage
			addXml 'percent' $percent
			#espace
			addXml 'total' $total
		}
		if((($diskD | foreach{$_.FreeSpace}) -ne $null)){
			$serverXml = $xmlSource.CreateElement('server')
			$serverXml.SetAttribute('name',$item)
			$serverXml.SetAttribute('drive','D:')
			
			$percent=[math]::truncate(($diskD.FreeSpace * 100) / $diskD.Size)
			$total=[math]::truncate($diskD.FreeSpace / 1GB)
			
			#pourcentage
			addXml 'percent' $percent
			#espace
			addXml 'total' $total
		}
	}
}
$xmlSource.Save($xmlResult)