# ==============================================================================
# Script             : SyntheseMag.ps1
# Description        : à venir
# Paramètres         : Code ANABEL
# Retour             : Aucun
# Commentaires       : Aucun
# ------------------------------------------------------------------------------
# Historique :
# Date       Auteur              Description
# ---------- ------------------- -----------------------------------------------
# 24/10/2016 P.Depretz              Création du script.
#
# Récupération des arguments
[string]$CodeMagasin=$args[0]

# Infos de connexion en remote
Enable-WSManCredSSP Client –DelegateComputer * -Force
$username = 'domain\login'
$password = 'password'

# Initialisation de la variable mag pour pouvoir choisir les magasins correspondants au codeAnabel donné
$mag ="MAG$CodeMagasin"

# Récupération des config
try{
	$ConfigMagasin=[xml](Get-Content "X:\Config\CarolineMagasins.xml")
	$ConfigServer=[xml](Get-Content "X:\Config\CarolineServeurs.xml")
}
catch{
	&$error
}

$exec = {
	# Récupération des variables du magasin
	$tabmag = $ConfigMagasin | Select-XML -XPath "//Magasin[@CodeANABEL='$CodeMagasin']" | Select-Object -ExpandProperty Node
	$tabserver = $ConfigServer | Select-XML -XPath "//Instance[@Nom='$bddInstance']" | Select-Object -ExpandProperty Node | Select -Expand Adresse

	$codebatch = $tabmag.Serveurs.Batch.Cluster
	$ver = $tabmag.VersionCaroline
	$MU =$tabmag.CodeMU
	$Nom =$tabmag.Nom
	$statsFile1 = "D:\_Exploitation\CIC\Cfg\exploit_ibm\Universe_errors_stats.csv"
	$statsFile2 = "D:\_Exploitation\CIC\Cfg\exploit_ibm\Universe_analyser_stats.csv"
	$logDate = Get-Date -format yyyyMMd_HHmm
	$userID = $($(whoami) -split "\\")[1]
	$AP1CODE = "FR$CodeMagasin"+"AP1"
	$Emission ="X:\Donnees\$mag\Interfaces\Emission"
	$Reception = "X:\Donnees\$mag\Interfaces\Reception"
	$bddInstance = $tabmag.Serveurs.BaseDeDonnees.Instance
	$Server = $tabmag.Serveurs.Batch.Cluster
	$Batch = $tabmag.Serveurs.Batch.Cluster+".ho.fr.wcorp.carrefour.com"
	$MagVersion = $tabmag.VersionCaroline
	$AP1Transfert = "\\FR$CodeMagasin"+"AP1\d$\applicat\data\EchangesFO\Transferts"

	# Récupération des variables instance SQL
	$IPSQL = $ConfigServer | Select-XML -XPath "//Instance[@Nom='$bddInstance']" | Select-Object -ExpandProperty Node| Select -Expand Adresse

	# Log
	write-output "$logDate;$userID;info_magasin;$AP1CODE" >> $statsFile2
	
	# Construction du tableau
	Clear-Host
	write-host "--------------------------------------------------------------------" -foregroundcolor DarkGray
	write-host "Informations pour le magasin : `"$CodeMagasin`"" -foregroundcolor DarkGreen
	write-host "--------------------------------------------------------------------" -foregroundcolor DarkGray
	write-host "Nom du magasin ..................... : `"$Nom`"" -foregroundcolor DarkGray
	write-host "Serveur batch ...................... : `"$Batch`"" -foregroundcolor DarkGray
	write-host "Code AP1 du magasin ................ : `"$AP1CODE`"" -foregroundcolor DarkGray
	write-host "Version du magasin ................. : `"$MagVersion`"" -foregroundcolor DarkGray
	write-host "Instance SQL ....................... : `"$bddInstance`"" -foregroundcolor DarkGray
	write-host "Adresse IP de l'instance SQL........ : `"$IPSQL`"" -foregroundcolor DarkGray
	write-host ""
	write-host "--------------------------------------------------------------------" -foregroundcolor DarkGray
	write-host "Menu d'exploitation :" -foregroundcolor DarkGreen
	write-host "--------------------------------------------------------------------" -foregroundcolor DarkGray
	write-host "1 : Reprise de fichier" -foregroundcolor DarkGray
	write-host "2 : Analyse de log" -foregroundcolor DarkGray
	write-host "3 : Nouvelle recherche" -foregroundcolor DarkGray
	write-host "4 : Connexion à la BDD du magasin" -foregroundcolor DarkGray
	write-host "5 : Exit" -foregroundcolor DarkGray
	write-host "--------------------------------------------------------------------" -foregroundcolor DarkGray
	$choice = read-host "Choix (1,2,...) "
	
	if($choice -eq 4){
		&'C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio\Ssms.exe' /S $bddInstance
		&$exec
	}
	
	if($choice -eq 2){
		$logDir = "\\" + $Batch + "\E$\soft\Universe\FS-LOG\" + $codebatch + "\CSIFPR\exp"
		do
		{
			$nses = ""
			$nupr = Read-Host "Numero d'execution - Nupr (*) "
			$nupr = $nupr.trim()
			if ( $nupr -eq "") { 
				$nupr = "*" 
				$nses = Read-Host "Numero de session - Nses (*) "
				if ( $nses -eq "") { $nses = "*" }
				$nses = $nses.trim()
			}
		} while ($nupr -eq "*" -and $nses -eq "*")
		$LogName = "RecupLogDu_$($nses)-$($nupr).log"
		$LogName = $LogName -replace '[^A-Za-z0-9-_ \.\[\]]', ''
		$LogName = "D:\_Exploitation\CIC\Log\$($LogName)"
		$masque = "$($logDir)\X*$($nses)*.*$($nupr)"
		foreach($fichier in get-childItem "$masque"){
			Get-Content $fichier -ErrorAction SilentlyContinue >> $LogName
		}
		if (Test-Path $LogName) {
			$err_file = Import-CSV "D:\_Exploitation\CIC\Cfg\Universe_errors.csv" -delimiter ";"
			$check=0
			foreach ($line in $err_file)
			{
				$message = $line.err_message
				$affectation = $line.group_aff
				$action = $line.action
				if((Get-Content $LogName) -match $message){
					$check = 1
					break
				}
			}
			if($check -eq 1){
				write-host "Pilotage : Merci de copier/coller la log en commentaire du ticket SM7" -foregroundcolor DarkRed
				write-host "+ transferer a $affectation" -foregroundcolor DarkRed
				write-output "$logDate;$userID;analyse_log;$affectation" >> $statsFile1
				if(-Not ([string]::IsNullOrEmpty($action))){
					write-host "BT : $action" -foregroundcolor DarkGray
				}
				notepad $LogName
				pause
				&$exec
			}
			else{
				write-host "Pilotage : Merci de copier/coller la log en commentaire du ticket SM7" -foregroundcolor DarkRed
				write-host "+ transferer a <TEAM NAME>" -foregroundcolor DarkRed
				write-output "$logDate;$userID;analyse_log;<TEAM NAME>(erreur inconnue)" >> $statsFile1
				notepad $LogName
				pause
				&$exec
			}
		} 
        else{
			write-host "Pilotage : Merci de transférer à <TEAM NAME>" -foregroundcolor DarkRed
			write-output "$logDate;$userID;analyse_log;<TEAM NAME>(fichier log non trouvee)" >> $statsFile1
			pause
			&$exec
		}
	}
	
	if($choice -eq 1){
		do{
			$file = read-host "Indiquez quel est le fichier  du fichier que vous voulez reprendre ? "
		}while(($file -Like "*\*") -or ($file -Like "*/*"))
		
		$Interface = "X:\Donnees\$mag\Interfaces"
		if($filetoreplay = Get-ChildItem -Path $Interface -Filter "$file" -Recurse | Where-Object {!($_.Name -match "evts") -and !($_.Name -match "KO") -and !($_.Name -match "OK") -and !($_.Name -match "__")}){
			$fulldir = $filetoreplay.Fullname
			if($fulldir -match "X:\\Donnees\\$mag\\Interfaces\\Historique"){
				write-host "Le fichier $filetoreplay est dans un dossier \Historique merci de le déplacer, integration annulee ..."	-foregroundcolor DarkRed
				pause
				&$exec				
			}
			else{
				Clear-Host
				write-host "La réintégration du fichier $filetoreplay va être lancee ..." -foregroundcolor DarkGreen
				write-output "$logDate;$userID;reprise_fichier;$file;$filetoreplay :: OK" >> $statsFile1
				pause
			
				# Lancement en remote de l'intégration
				$cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))
				$session = New-PSSession -ComputerName $Server -Authentication CredSSP -Credential $cred
				$script = [scriptblock]::Create("D:\_Exploitation\CIC\RepriseFichiers.cmd $fulldir")
				invoke-command -Session $session -scriptBlock $script
				pause
				&$exec
			}
		}
		else{
			write-host "Le fichier $file est introuvable, integration annulee ..." -foregroundcolor DarkRed
			write-output "$userID;reprise_fichier;$filetoreplay :: KO" >> $statsFile1
			pause
			&$exec
		}
	}
	if($choice -eq 3){
		Clear-Host
		$CodeMagasin = Read-Host "Quel numero de magasin voulez vous analyser ? (ex:0503) "
		$mag ="MAG$CodeMagasin"
		&$exec
	}
	
	if($choice -eq 5){
		exit
	}
}
&$exec
