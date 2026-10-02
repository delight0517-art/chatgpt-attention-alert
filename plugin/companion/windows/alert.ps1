param(
    [string]$Title = '',
    [string]$Message = 'Please check this chat.',
    [string]$ChatUrl = '',
    [string]$SetSoundFile = '',
    [ValidateSet('show', 'on', 'off', 'toggle')]
    [string]$Sound = 'show'
)

$ErrorActionPreference = 'Stop'
$configDir = Join-Path $env:APPDATA 'ChatGPTAttentionAlert'
$soundPreferenceFile = Join-Path $configDir 'sound.txt'
$customSoundPreferenceFile = Join-Path $configDir 'sound-file.txt'
$pauseUntilPreferenceFile = Join-Path $configDir 'pause-until.txt'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

if (-not [string]::IsNullOrWhiteSpace($SetSoundFile)) {
    if ($SetSoundFile -eq 'default') {
        Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $customSoundPreferenceFile
    } elseif ([IO.Path]::GetExtension($SetSoundFile) -ieq '.wav' -and (Test-Path -LiteralPath $SetSoundFile -PathType Leaf)) {
        Set-Content -NoNewline -Encoding utf8 -LiteralPath $customSoundPreferenceFile -Value (Get-Item -LiteralPath $SetSoundFile).FullName
    } else {
        throw 'Choose an existing .wav file, or use -SetSoundFile default to restore the system sound.'
    }
    exit 0
}

if ($Sound -ne 'show') {
    $current = if (Test-Path $soundPreferenceFile) { (Get-Content -Raw $soundPreferenceFile).Trim() } else { 'on' }
    $next = switch ($Sound) {
        'on' { 'on' }
        'off' { 'off' }
        'toggle' { if ($current -eq 'off') { 'on' } else { 'off' } }
    }
    Set-Content -NoNewline -Encoding ascii -Path $soundPreferenceFile -Value $next
    exit 0
}

if (Test-Path -LiteralPath $pauseUntilPreferenceFile) {
    try {
        $pauseUntil = [DateTime]::Parse((Get-Content -Raw -LiteralPath $pauseUntilPreferenceFile)).ToUniversalTime()
        if ([DateTime]::UtcNow -lt $pauseUntil) { exit 0 }
    } catch { }
    Remove-Item -Force -LiteralPath $pauseUntilPreferenceFile
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$script:soundEnabled = if (Test-Path $soundPreferenceFile) { (Get-Content -Raw $soundPreferenceFile).Trim() -ne 'off' } else { $true }
$script:customSoundPath = if (Test-Path -LiteralPath $customSoundPreferenceFile) { (Get-Content -Raw $customSoundPreferenceFile).Trim() } else { '' }
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
$openChat = { if ($chatUrlValid) { Start-Process -FilePath $ChatUrl; $form.Close() } }
$form.Add_Click($openChat)
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$stackFile = Join-Path $configDir 'stack-index.txt'
$stackMutex = [System.Threading.Mutex]::new($false, 'Local\ChatGPTAttentionAlertStack')
$stackMutex.WaitOne()
try {
    $stackIndex = if (Test-Path -LiteralPath $stackFile) { [int](Get-Content -Raw -LiteralPath $stackFile) } else { 0 }
    Set-Content -NoNewline -Encoding ascii -LiteralPath $stackFile -Value ($stackIndex + 1)
} finally {
    $stackMutex.ReleaseMutex()
    $stackMutex.Dispose()
}
$stackSlots = [Math]::Max(1, [int]([Math]::Min(($bounds.Width - $form.Width), ($bounds.Height - $form.Height)) / 28) + 1)
$offset = ($stackIndex % $stackSlots) * 28
$form.Location = [System.Drawing.Point]::new(($bounds.Right - $form.Width - 24 - $offset), ($bounds.Top + 24 + $offset))
$form.Add_Shown({
    if ($script:soundEnabled) {
        if ($script:customSoundPath -and (Test-Path -LiteralPath $script:customSoundPath -PathType Leaf)) {
            $script:soundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $script:customSoundPath
            $script:soundPlayer.Play()
        } else {
            [System.Media.SystemSounds]::Asterisk.Play()
        }
    }
})

$heading = New-Object System.Windows.Forms.Label
$heading.Text = 'GPT NEEDS YOU  ·  확인이 필요해요'
$heading.ForeColor = [System.Drawing.Color]::FromArgb(97, 235, 255)
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$heading.Location = [System.Drawing.Point]::new(20, 16)
$heading.Size = [System.Drawing.Size]::new(490, 24)
$heading.Add_Click($openChat)
$form.Controls.Add($heading)

$chatTitle = New-Object System.Windows.Forms.Label
$chatTitle.Text = $Title
$chatTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$chatTitle.Location = [System.Drawing.Point]::new(20, 47)
$chatTitle.Size = [System.Drawing.Size]::new(490, 44)
$chatTitle.Add_Click($openChat)
$form.Controls.Add($chatTitle)

$action = New-Object System.Windows.Forms.Label
$action.Text = $Message
$action.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$action.Location = [System.Drawing.Point]::new(20, 98)
$action.Size = [System.Drawing.Size]::new(490, 66)
$action.Add_Click($openChat)
$form.Controls.Add($action)

$mute = New-Object System.Windows.Forms.Button
$mute.Text = if ($script:soundEnabled) { '소리 끄기' } else { '소리 켜기' }
$mute.Location = [System.Drawing.Point]::new(20, 176)
$mute.Size = [System.Drawing.Size]::new(105, 30)
$mute.Add_Click({
    $script:soundEnabled = -not $script:soundEnabled
    $mute.Text = if ($script:soundEnabled) { '소리 끄기' } else { '소리 켜기' }
    Set-Content -NoNewline -Encoding ascii -Path $soundPreferenceFile -Value $(if ($script:soundEnabled) { 'on' } else { 'off' })
})
$form.Controls.Add($mute)

$pause = New-Object System.Windows.Forms.Button
$pause.Text = '24시간 중지'
$pause.Location = [System.Drawing.Point]::new(145, 176)
$pause.Size = [System.Drawing.Size]::new(150, 30)
$pause.Add_Click({
    [DateTime]::UtcNow.AddHours(24).ToString('o') | Set-Content -Encoding utf8 -LiteralPath $pauseUntilPreferenceFile
    $form.Close()
})
$form.Controls.Add($pause)

if ($chatUrlValid) {
    $open = New-Object System.Windows.Forms.Button
    $open.Text = '채팅 열기'
    $open.Location = [System.Drawing.Point]::new(322, 176)
    $open.Size = [System.Drawing.Size]::new(90, 30)
    $open.Add_Click($openChat)
    $form.Controls.Add($open)
}

$done = New-Object System.Windows.Forms.Button
$done.Text = '확인'
$done.Location = [System.Drawing.Point]::new(424, 176)
$done.Size = [System.Drawing.Size]::new(86, 30)
$done.Add_Click({ $form.Close() })
$form.Controls.Add($done)
[void]$form.ShowDialog()
