$path = Read-Host -Prompt 'Input the path to your Thronefall installation (default: C:\Program Files (x86)\Steam\steamapps\common\Thronefall)'
$mod_name = Read-Host -Prompt 'Input the name of your mod'

if ($path -eq "") {
    $path = "C:\Program Files (x86)\Steam\steamapps\common\Thronefall"
}

$dlls = (
    "Assembly-CSharp",
    "AstarPathfindingProject",
    "MoreMountains.Feedbacks",
    "MPUIKit",
    "Rewired_Core",
    "Unity.TextMeshPro",
    "UnityEngine.UI"
)

Write-Host "Setting up lib directory"
if (Test-Path (Join-Path $path Thronefall.exe) -PathType Leaf) {
    $library_path = Join-Path $path Thronefall_Data\Managed
    if (!(Test-Path -Path .\lib)) {
        New-Item -ItemType Directory -Path .\ -Name lib
    }

    $dlls | ForEach-Object {
        Copy-Item (Join-Path $library_path "$_.dll") ".\lib\$_.dll"
    }

    $cfg = "InstallPath = $([RegEx]::Escape($(Join-Path $path BepInEx\plugins\$mod_name)))"
    Out-File -InputObject $cfg -FilePath .\install.cfg
}
else {
    Write-Host "Thronefall.exe not found, terminating."
}

dotnet new install BepInEx.Templates --nuget-source https://nuget.bepinex.dev/v3/index.json
Write-Host "Creating csproj"
dotnet new bep6plugin_unitymono -n $mod_name -T net472 -U 2022.3.0
Write-Host "Creating sln"
dotnet new sln --name $mod_name
dotnet sln "$mod_name.sln" add $mod_name/$mod_name.csproj

Move-Item -Path .\$mod_name\NuGet.Config -Destination .\NuGet.Config

Write-Host "Adding references"
$project = Get-Content $mod_name/$mod_name.csproj

(Get-Content $mod_name/$mod_name.csproj) | Foreach-Object {
    if ($_ -match "</Project>") 
    {
        "  <ItemGroup>"
        $dlls | ForEach-Object {
            Write-Host "Reference to lib/$_ added to $mod_name/$mod_name.csproj"
            "    <Reference Include=`"$_`">"
            "      <HintPath>..\lib\$_.dll</HintPath>"
            "    </Reference>"
        }
        Write-Host "Add PostBuild command to $mod_name/$mod_name.csproj"
        "  </ItemGroup>"
        '  <Target Name="PostBuild" AfterTargets="PostBuildEvent">'
        '    <Exec Command="powershell.exe -NonInteractive -executionpolicy Unrestricted -file $(SolutionDir)\install.ps1 $(SolutionDir) $(OutDir)" />'
        '  </Target>'
    }
    $_
} | Set-Content $mod_name/$mod_name.csproj

Write-Host "Updating install.ps1"
(Get-Content install.ps1) | Foreach-Object {
    $_
    if ($_ -eq '$dlls = (') 
    {
        "    '$mod_name.dll'"
    }
} | Set-Content install.ps1
