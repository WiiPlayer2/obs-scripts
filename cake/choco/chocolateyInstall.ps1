function Test-Any {
    [CmdletBinding()]
    param($EvaluateCondition,
        [Parameter(ValueFromPipeline = $true)] $ObjectToTest)
    begin {
        $any = $false
    }
    process {
        if (-not $any -and (& $EvaluateCondition $ObjectToTest)) {
            $any = $true
        }
    }
    end {
        $any
    }
}

$pkgDir = "$env:ChocolateyInstall/lib/obs-studio-wiiplayer2-scripts"
$scriptsArchive = Get-Item (Join-Path $pkgDir 'data/scripts.zip')
$scriptsDirectory = New-Item (Join-Path $pkgDir 'data/scripts') -ItemType Directory -ErrorAction SilentlyContinue
if($scriptsDirectory -eq $null)
{
    $scriptsDirectory = Get-Item (Join-Path $pkgDir 'data/scripts')
}
$obsAppData = Join-Path $env:APPDATA 'obs-studio/'

$scriptFiles = Get-ChildItem $scriptsDirectory.FullName -File

Get-ChocolateyUnzip -FileFullPath $scriptsArchive.FullName -Destination $scriptsDirectory.FullName

$obsDefaultCollection = Get-ChildItem -Path 'C:\Users\*\AppData\Roaming\obs-studio\basic\scenes\Default.json'
foreach($sceneFile in $obsDefaultCollection)
{
    $json = (Get-Content $sceneFile.FullName) -join "`n" | ConvertFrom-Json
    $jsonScripts = $json.modules.'scripts-tool'

    foreach($scriptFile in $scriptFiles)
    {
        $scriptPath = $scriptFile.FullName.Replace('\', '/');
        if(-not ($jsonScripts | Test-Any { $_.path -eq $scriptPath}))
        {
            $obj = @{ path = $scriptPath; settings = @{} }
            $jsonScripts += ,$obj
        }
    }

    $json.modules.'scripts-tool' = $jsonScripts

    ConvertTo-Json $json -Depth 100 | Write-File -Path $sceneFile
}
