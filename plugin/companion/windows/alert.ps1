param(
    [string]$Title = '',
    [string]$Message = 'Please check this chat.',
    [string]$ChatUrl = '',
    [ValidateSet('show', 'on', 'off', 'toggle')]
    [string]$Sound = 'show'
)

$ErrorActionPreference = 'Stop'
$configDir = Join-Path $env:APPDATA 'ChatGPTAttentionAlert'
$soundFile = Join-Path $configDir 'sound.txt'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

if ($Sound -ne 'show') {
    $current = if (Test-Path $soundFile) { (Get-Content -Raw $soundFile).Trim() } else { 'on' }
    $next = switch ($Sound) {
        'on' { 'on' }
        'off' { 'off' }
        'toggle' { if ($current -eq 'off') { 'on' } else { 'off' } }
    }
    Set-Content -NoNewline -Encoding ascii -Path $soundFile -Value $next
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$script:soundEnabled = if (Test-Path $soundFile) { (Get-Content -Raw $soundFile).Trim() -ne 'off' } else { $true }
$chatUrlValid = $false
if (-not [string]::IsNullOrWhiteSpace($ChatUrl)) {
    $parsedChatUrl = $null
    $chatUrlValid = [System.Uri]::TryCreate($ChatUrl, [System.UriKind]::Absolute, [ref]$parsedChatUrl) -and $parsedChatUrl.Scheme -eq 'https' -and $parsedChatUrl.Host -in @('chatgpt.com', 'chat.openai.com')
}
if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = '채팅 제목을 확인할 수 없음'
    $script:soundEnabled = $false
}
if ($script:soundEnabled -and -not $chatUrlValid) {
    $script:soundEnabled = $false
}

if ($script:soundEnabled) {
    Start-Process -FilePath $ChatUrl
    1..3 | ForEach-Object {
        [System.Media.SystemSounds]::Asterisk.Play()
        Start-Sleep -Milliseconds 250
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ChatGPT Attention Alert'
$form.Size = [System.Drawing.Size]::new(540, 250)
$form.StartPosition = 'Manual'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ShowInTaskbar = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(14, 23, 36)
$form.ForeColor = [System.Drawing.Color]::White
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = [System.Drawing.Point]::new(($bounds.Right - $form.Width - 24), ($bounds.Top + 24))

$heading = New-Object System.Windows.Forms.Label
$heading.Text = 'GPT NEEDS YOU  ·  확인이 필요해요'
$heading.ForeColor = [System.Drawing.Color]::FromArgb(97, 235, 255)
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$heading.Location = [System.Drawing.Point]::new(20, 16)
$heading.Size = [System.Drawing.Size]::new(490, 24)
$form.Controls.Add($heading)

$chatTitle = New-Object System.Windows.Forms.Label
$chatTitle.Text = $Title
$chatTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$chatTitle.Location = [System.Drawing.Point]::new(20, 47)
$chatTitle.Size = [System.Drawing.Size]::new(490, 44)
$form.Controls.Add($chatTitle)

$action = New-Object System.Windows.Forms.Label
$action.Text = $Message
$action.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$action.Location = [System.Drawing.Point]::new(20, 98)
$action.Size = [System.Drawing.Size]::new(490, 66)
$form.Controls.Add($action)

$mute = New-Object System.Windows.Forms.Button
$mute.Text = if ($script:soundEnabled) { '소리 끄기' } else { '소리 켜기' }
$mute.Location = [System.Drawing.Point]::new(20, 176)
$mute.Size = [System.Drawing.Size]::new(105, 30)
$mute.Add_Click({
    $script:soundEnabled = -not $script:soundEnabled
    $mute.Text = if ($script:soundEnabled) { '소리 끄기' } else { '소리 켜기' }
    Set-Content -NoNewline -Encoding ascii -Path $soundFile -Value $(if ($script:soundEnabled) { 'on' } else { 'off' })
})
$form.Controls.Add($mute)

if ($chatUrlValid) {
    $open = New-Object System.Windows.Forms.Button
    $open.Text = '채팅 열기'
    $open.Location = [System.Drawing.Point]::new(322, 176)
    $open.Size = [System.Drawing.Size]::new(90, 30)
    $open.Add_Click({ Start-Process -FilePath $ChatUrl })
    $form.Controls.Add($open)
}

$done = New-Object System.Windows.Forms.Button
$done.Text = '확인'
$done.Location = [System.Drawing.Point]::new(424, 176)
$done.Size = [System.Drawing.Size]::new(86, 30)
$done.Add_Click({ $form.Close() })
$form.Controls.Add($done)
$form.AcceptButton = $done
[void]$form.ShowDialog()
