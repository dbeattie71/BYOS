param
(
   [string]$url,
   [string]$pool,
   [string]$token
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

Set-Content -Path status.txt -Value "Installing extension"
Add-Content -Path status.txt -Value $url
Add-Content -Path status.txt -Value $pool 

$agentDir = $PSScriptRoot
$agentExe = Join-Path -Path $agentDir -ChildPath "bin\Agent.Listener.exe"
$agentZip = Get-ChildItem -Path .\* -File -Include vsts-agent*.zip
$agentConfig = Join-Path -Path $agentDir -ChildPath "config.cmd"

#unzip the agent if it doesn't exist already
if (!(Test-Path -Path $agentExe))
{
   Add-Content -Path status.txt -Value "Unzipping Agent"
   [System.IO.Compression.ZipFile]::ExtractToDirectory($agentZip, $agentDir)
}

# create administrator account
Add-Content -Path status.txt -Value "Creating AzDevOps account"
$username = 'AzDevOps'
Set-Content -Path username.txt -Value $username
$password = (New-Guid).ToString()
Set-Content -Path password.txt -Value $password
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

if (!(Get-LocalUser -Name $username -ErrorAction Ignore))
{
  Add-Content -Path status.txt -Value "Creating AzDevOps user"
  New-LocalUser -Name $username -Password $securePassword
}
else
{
  Add-Content -Path status.txt -Value "Setting AzDevOps password"
  Set-LocalUser -Name $username -Password $securePassword 
}
if ((Get-LocalGroup -Name "Users" -ErrorAction Ignore) -and
    !(Get-LocalGroupMember -Group "Users" -Member $username -ErrorAction Ignore))
{
  Add-Content -Path status.txt -Value "Adding AzDevOps to Users"
  Add-LocalGroupMember -Group "Users" -Member $username
}
if ((Get-LocalGroup -Name "Administrators" -ErrorAction Ignore) -and
    !(Get-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction Ignore))
{
  Add-Content -Path status.txt -Value "Adding AzDevOps to Administrators"
  Add-LocalGroupMember -Group "Administrators" -Member $username
}
if ((Get-LocalGroup -Name "docker-users" -ErrorAction Ignore) -and
    !(Get-LocalGroupMember -Group "docker-users" -Member $username -ErrorAction Ignore))
{
  Add-Content -Path status.txt -Value "Adding AzDevOps to docker-users"
  Add-LocalGroupMember -Group "docker-users" -Member $username
}

# run the customer warmup script if it exists
# note that this runs as SYSTEM on windows
$warmup = "\warmup.ps1"
if (Test-Path -Path $warmup)
{
   # run as local admin elevated
   Add-Content -Path status.txt -Value "Running warmup script"
   Start-Process -FilePath PowerShell.exe -Verb RunAs -Wait -WorkingDirectory \ -ArgumentList "-ExecutionPolicy Unrestricted $warmup"
}

# configure the build agent
$configParameters = " --unattended --url $url --pool ""$pool"" --auth pat --noRestart --replace --token $token"
$config = $agentConfig + $configParameters
Add-Content -Path status.txt -Value "Configuring agent"
Start-Process -FilePath $agentConfig -ArgumentList $configParameters -NoNewWindow -Wait -WorkingDirectory $agentDir
Add-Content -Path status.txt -Value "Finished configuration."
