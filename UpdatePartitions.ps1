Connect-AZAccount -Identity

$ApplicationId = Get-AzKeyVaultSecret -VaultName 'kvtorentlikher' -Name 'PBIClientID' -AsPlainText
$Secret = ConvertTo-SecureString (Get-AzKeyVaultSecret -VaultName 'kvtorentlikher' -Name 'PBIClientSecret' -AsPlainText) -AsPlainText -Force
$TenantId = Get-AzKeyVaultSecret -VaultName 'kvtorentlikher' -Name 'PBITenantID' -AsPlainText
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $Secret

$ServerName = "powerbi://api.powerbi.com/v1.0/myorg/Demo%20Workspace" #replace with your workspace XMLA endpoint
$DatabaseName = 'AdventureWorks Demo' #replace with your Semantic Model name


#Determine the name of the partition to add and remove 
$today = Get-Date

$PartitionToAdd = $today.ToString("yyyy-MM")
$PartitionToRemove = $today.AddYears(-1).ToString("yyyy-MM") #partition from a year ago
$PartitionToAddYear = $today.Year
$PartitionToAddMonth = $today.Month
$PartitionToAddLastDay = [DateTime]::DaysInMonth($PartitionToAddYear, $PartitionToAddMonth)


#Parameterized XMLA script
$query = @"
{   
  "sequence":    
    {   
      "operations": [  
		{
		  "delete": {
			"object": {
			  "database": "$DatabaseName",
			  "table": "Internet Sales Activity",
			  "partition": "$PartitionToRemove"
			}
		  }
		},
		{
		  "create": {
			"parentObject": {
			  "database": "$DatabaseName",
			  "table": "Internet Sales Activity"
			},
			"partition": {
			  "name": "$PartitionToAdd",
			  "mode": "import",
			  "source": {
				"type": "m",
				"expression": [
				  "let",
				  "    Source = Sql.Databases(\"synapsetorentlikher-ondemand.sql.azuresynapse.net\"),",
				  "    AdventureWorks = Source{[Name=\"AdventureWorks\"]}[Data],",
				  "    dbo_vw_FactInternetSales = AdventureWorks{[Schema=\"dbo\",Item=\"vw_FactInternetSales\"]}[Data],",
				  "    #\"Filtered Rows\" = Table.SelectRows(#\"dbo_vw_FactInternetSales\", each [Order Date] >= #datetime($PartitionToAddYear, $PartitionToAddMonth, 1, 0, 0, 0) and [Order Date] <= #datetime($PartitionToAddYear, $PartitionToAddMonth, $PartitionToAddLastDay, 0, 0, 0))",
				  "in",
				  "    #\"Filtered Rows\""
				]
			  }
			}
		  }
		}
		]
	}
}
"@

#Execute XMLA query
Invoke-ASCmd -ServicePrincipal -TenantId $TenantId -Credential $Credential -Server $ServerName -Database $DatabaseName -Query $query
