Write-Host "Lancement de la requete ..."
$smtp="host.domain.fr"
$port="25"
$OUT="E:\script\result_supbdd\result.txt"
$htmlFile="E:\script\result_supbdd\index.html"

sqlcmd -S WEBSRV\BDD01 -d INTRANET -U USER -P PASSWORD -Q "SET NOCOUNT ON select distinct(ba.nomBase)as bddname,ba.acteurCreation as owner,ba.dateAjout as date from dbo.Tb_BaseInstallee ba INNER JOIN dbo.Tb_BaseLocalisation bl on ba.idLocalisation=bl.id INNER JOIN dbo.form_support fs on fs.idBaseInstallee=ba.id where ba.supprimee=0 AND ba.id NOT IN(SELECT fs.idBaseInstallee FROM dbo.form_support fs WHERE fs.id_etat <> '99' and ba.id=fs.idBaseInstallee) AND bl.id in (17,18) order by ba.acteurCreation;" -o $OUT -h-1 -s ";" -W

$a = "<style>"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#E6E6E6}"
$a = $a + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:white}"
$a = $a + "</style>"
$a = $a + "<body>Bonjour,<br><br>Merci a chacun de faire le menage parmis ces bases <u>qui ne sont plus rattachees a une anomalie :<u><br><br></body>"

Import-csv $OUT -delimiter ";" -Header "Base de donnees","Proprietaire","Date creation" | ConvertTo-HTML -head $a -PostContent "<i>ps : ceci est un message automatique genere chaque vendredi a 14h00</i>" | Out-File E:\script\result_supbdd\index.html

Write-Host "Envoi du mail ..."
blat -f support@domain.fr -to Pole_Support@domain.com -s "[ALERTE] - SUPBDD01/02" -bodyF $htmlFile -server host.domain.fr -port 25

Remove-item $OUT -Force
Remove-item $htmlFile -Force
