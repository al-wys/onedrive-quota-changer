Add-PSSnapin "Microsoft.SharePoint.PowerShell"

$quotaSettingSiteUrl = "http://sp/sites/site"; # The url of Quota Setting Site

$quotaSettingSite = Get-SPSite $quotaSettingSiteUrl
$quotaSettingListUrl = [Microsoft.SharePoint.Utilities.SPUrlUtility]::CombineUrl($quotaSettingSiteUrl, 'Lists/QuotaSetting') # Get the list that stores quota settings
$quotaSettingWeb = $quotaSettingSite.RootWeb
$quotaSettingList = $quotaSettingWeb.GetList($quotaSettingListUrl)

if ($quotaSettingList.ItemCount -gt 0) {
    $siteGroups = $quotaSettingWeb.SiteGroups
    $quotaGroupSet = New-Object System.Collections.Generic.HashSet[System.Object] # Initial Hashset for quota settings

    # Build the dictionary for quota settings
    foreach ($quotaSetting in $quotaSettingList.Items) {
        $groupValue = New-Object Microsoft.Sharepoint.SPFieldUserValue($quotaSettingWeb, $quotaSetting['Group'])
        $users = $siteGroups[$groupValue.LookupValue].Users
        
        if ($users.Count -gt 0) {
            $quotaSetObj = @{}
            $quotaSetObj.Users = $users
            $quotaSetObj.QuotaTemplateName = $quotaSetting['QuotaTemplateName']
            $quotaGroupSet.Add($quotaSetObj)
        }
    }

    # Do job if the dictionary has values
    if ($quotaGroupSet.Count -gt 0) {
        $serviceContext = Get-SPServiceContext -Site $quotaSettingSiteUrl
        $profileManager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($serviceContext)
        $quotaTemplates = [Microsoft.SharePoint.Administration.SPWebService]::ContentService.QuotaTemplates

        $quotaTemDic = @{} # Initial dictionary for quota template

        foreach ($quotaItem in $quotaGroupSet) { 
            $quotaTemplateName = $quotaItem.QuotaTemplateName
            foreach ($user in $quotaItem.Users) {
                try {
                    $loginName = $user.LoginName
                    Write-Host ('Working on ' + $loginName + "'s OneDrive")

                    $userSiteUrl = $profileManager.GetUserProfile($loginName).PersonalUrl.AbsoluteUri
                    $userSite = Get-SPSite($userSiteUrl)
                    $userSiteQuotaId = $userSite.Quota.QuotaID                    

                    $specificQuotaId
                    if (!$quotaTemDic.ContainsKey($quotaTemplateName)) {
                        $specificQuotaId = ($quotaTemplates | Where-Object {$_.Name -eq $quotaTemplateName}).QuotaID
                        $quotaTemDic.Add($quotaTemplateName, $specificQuotaId)
                    }
                    else {
                        $specificQuotaId = $quotaTemDic[$quotaTemplateName]
                    }

                    if ($specificQuotaId -ne $userSiteQuotaId) {
                        Set-SPSite -Identity $userSiteUrl -QuotaTemplate $quotaTemplateName
                    }
                }
                catch {
                    Write-Host -ForegroundColor Red ("Error when working on " + $loginName + "'s OneDrive")
                }
            }
        }
    }

    Write-Host 'Done'
}