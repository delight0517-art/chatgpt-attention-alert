param(
    [string]$Title = '',
    [string]$Message = 'Please check this chat.',
    [string]$ChatUrl = '',
    [string]$AuthService = '',
    [string]$AuthAccount = '',
    [Alias('LoginUrl')]
    [string]$ActionUrl = '',
    [ValidateRange(0, 4102444800)]
    [long]$ExpiresAt = 0,
    [ValidateRange(0, 4102444800)]
    [long]$RetryAfter = 0,
    [string]$SetSoundFile = '',
    [ValidateSet('show', 'on', 'off')]
    [string]$Recommendations = 'show',
    [ValidateSet('show', 'on', 'off', 'toggle')]
    [string]$Sound = 'show'
)

$ErrorActionPreference = 'Stop'
$configDir = Join-Path $env:APPDATA 'ChatGPTAttentionAlert'
$soundPreferenceFile = Join-Path $configDir 'sound.txt'
$customSoundPreferenceFile = Join-Path $configDir 'sound-file.txt'
$pauseUntilPreferenceFile = Join-Path $configDir 'pause-until.txt'
$recommendationsPreferenceFile = Join-Path $configDir 'recommendations.txt'
$recommendationStateFile = Join-Path $configDir 'recommendation-state.txt'
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

if ($Recommendations -ne 'show') {
    Set-Content -NoNewline -Encoding ascii -LiteralPath $recommendationsPreferenceFile -Value $Recommendations
    if ($Recommendations -eq 'off') { Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $recommendationStateFile }
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
$script:recommendation = $null
$recommendationsEnabled = -not (Test-Path -LiteralPath $recommendationsPreferenceFile) -or (Get-Content -Raw $recommendationsPreferenceFile).Trim() -ne 'off'
$hasAuthContext = -not [string]::IsNullOrWhiteSpace($AuthService) -or -not [string]::IsNullOrWhiteSpace($AuthAccount) -or -not [string]::IsNullOrWhiteSpace($ActionUrl) -or $ExpiresAt -gt 0 -or $RetryAfter -gt 0
if ($recommendationsEnabled -and -not $hasAuthContext) {
    $context = "$Title`n$Message".ToLowerInvariant()
    $sensitivePattern = 'password|passkey|\botp\b|one-time code|verification code|api key|access token|secret|oauth|mfa|sign-in|login|authentication|비밀번호|인증|로그인|인증 코드|인증번호|일회용 코드|패스키|액세스 토큰'
    if ($context -notmatch $sensitivePattern) {
        $picks = @(
            @{ Topic = 'focus'; Pattern = 'pomodoro|focus|timer|study|concentration|집중|포모도로|타이머|공부'; Title = 'PomoFlow · 집중 타이머'; Url = 'https://delight0517.github.io/pomoflow/' },
            @{ Topic = 'scripture'; Pattern = 'bible|scripture|prayer|성경|말씀|기도|묵상'; Title = 'Selah · 성경 묵상 웹 앱'; Url = 'https://delight0517.github.io/selah-bible-meditation/' },
            @{ Topic = 'ai'; Pattern = 'chatgpt|artificial intelligence|\bai\b|\bllm\b|prompt|agent|인공지능|생성형 ai'; Title = 'Jev Evidence Kit · AI 답변 비교'; Url = 'https://jev-evidence-kit.rogan2534.chatgpt.site/' },
            @{ Topic = 'app-building'; Pattern = 'build an app|app development|website|web app|앱 개발|앱 만들|앱 제작|웹사이트|웹 앱'; Title = 'Launchmate · 앱 제작 서비스'; Url = 'https://launchmate-app-builders.rogan2534.chatgpt.site/' }
        )
        $pick = $picks | Where-Object { $context -match $_.Pattern } | Select-Object -First 1
        if ($pick) {
            $mutex = [System.Threading.Mutex]::new($false, 'Local\ChatGPTAttentionAlertRecommendation')
            $mutex.WaitOne()
            try {
                $now = Get-Date
                $month = $now.ToString('yyyy-MM')
                $today = $now.ToString('yyyy-MM-dd')
                $cutoff = $now.AddDays(-90).ToString('yyyy-MM-dd')
                $state = @{}
                if (Test-Path -LiteralPath $recommendationStateFile) {
                    foreach ($line in Get-Content -LiteralPath $recommendationStateFile) {
                        $parts = $line -split '=', 2
                        if ($parts.Count -eq 2) { $state[$parts[0]] = $parts[1] }
                    }
                }
                $topicDates = @{}
                foreach ($item in $picks) {
                    $key = "topic.$($item.Topic)"
                    $dates = @()
                    if ($state.ContainsKey($key) -and $state[$key]) {
                        $dates = @($state[$key].Split(',') | Where-Object { $_ -ge $cutoff })
                    }
                    if ($item.Topic -eq $pick.Topic -and $dates -notcontains $today) { $dates += $today }
                    $topicDates[$item.Topic] = $dates
                }
                $maxCount = ($picks | ForEach-Object { @($topicDates[$_.Topic]).Count } | Measure-Object -Maximum).Maximum
                $currentCount = @($topicDates[$pick.Topic]).Count
                $dominantTopic = if ($currentCount -eq $maxCount) { $pick.Topic } else { ($picks | Where-Object { @($topicDates[$_.Topic]).Count -eq $maxCount } | Select-Object -First 1).Topic }
                $selected = $picks | Where-Object { $_.Topic -eq $dominantTopic } | Select-Object -First 1
                $lines = @("month=$month")
                foreach ($item in $picks) { $lines += "topic.$($item.Topic)=$(@($topicDates[$item.Topic]) -join ',')" }
                Set-Content -Encoding utf8 -LiteralPath $recommendationStateFile -Value $lines
                if ($state['month'] -ne $month) { $script:recommendation = $selected }
            } finally {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
        }
    }
}
$chatUrlValid = $false
if (-not [string]::IsNullOrWhiteSpace($ChatUrl)) {
    $parsedChatUrl = $null
    $chatUrlValid = [System.Uri]::TryCreate($ChatUrl, [System.UriKind]::Absolute, [ref]$parsedChatUrl) -and $parsedChatUrl.Scheme -eq 'https' -and $parsedChatUrl.Host -in @('chatgpt.com', 'chat.openai.com')
}
$actionUrlValid = $false
if (-not [string]::IsNullOrWhiteSpace($ActionUrl)) {
    $parsedActionUrl = $null
    $actionUrlValid = [System.Uri]::TryCreate($ActionUrl, [System.UriKind]::Absolute, [ref]$parsedActionUrl) -and $parsedActionUrl.Scheme -eq 'https' -and -not $parsedActionUrl.UserInfo
}
$reissueAvailableAt = if ($RetryAfter -gt 0) { $RetryAfter } else { $ExpiresAt }
$hasAuthControls = -not [string]::IsNullOrWhiteSpace($ActionUrl) -or $reissueAvailableAt -gt 0
$script:authExpiresAt = $ExpiresAt
$script:authRetryAfter = $RetryAfter
$script:authReissueAvailableAt = $reissueAvailableAt
$script:loginButton = $null
$script:reissueButton = $null
$script:authStatusPinned = $false

function Update-AuthControls {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($script:loginButton) {
        $script:loginButton.Enabled = $actionUrlValid -and ($script:authExpiresAt -eq 0 -or $now -lt $script:authExpiresAt)
    }
    if ($script:reissueButton) {
        $script:reissueButton.Enabled = $now -ge $script:authReissueAvailableAt
    }
    if ($script:authStatusPinned) { return }
    if (-not [string]::IsNullOrWhiteSpace($ActionUrl) -and -not $actionUrlValid) {
        $script:authStatus.Text = '보안을 위해 HTTPS 요청 주소만 열 수 있습니다.'
    } elseif ($script:authRetryAfter -gt $now) {
        $remaining = [int]($script:authRetryAfter - $now)
        $script:authStatus.Text = "요청 제한 중 · 새 링크 요청까지 $([int]($remaining / 60))분 $($remaining % 60)초"
    } elseif ($script:authRetryAfter -gt 0 -and $now -ge $script:authRetryAfter) {
        $script:authStatus.Text = '요청 제한 해제 · 새 인증 링크를 요청할 수 있어요.'
    } elseif ($script:authExpiresAt -gt 0 -and $now -ge $script:authExpiresAt) {
        $script:authStatus.Text = '인증 링크 만료 · 새 링크 요청 가능'
    } elseif ($script:authExpiresAt -gt $now) {
        $remaining = [int]($script:authExpiresAt - $now)
        $script:authStatus.Text = "인증 링크 유효 · 만료까지 $([int]($remaining / 60))분 $($remaining % 60)초"
    } elseif ($script:authExpiresAt -gt 0) {
        $script:authStatus.Text = '인증 링크가 만료되었습니다. 새 링크를 요청하세요.'
    } else {
        $script:authStatus.Text = '요청 페이지를 열고, 이 알림은 확인 전까지 남겨 두세요.'
    }
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
$form.Size = [System.Drawing.Size]::new(540, $(if ($hasAuthControls) { 360 } elseif ($script:recommendation) { 290 } elseif ($hasAuthContext) { 280 } else { 250 }))
$form.StartPosition = 'Manual'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ShowInTaskbar = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(14, 23, 36)
$form.ForeColor = [System.Drawing.Color]::White
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$showAlertItem = $trayMenu.Items.Add('GPT 알리미 열어줘')
$showAlertItem.Add_Click({
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.TopMost = $true
    $form.Activate()
    $form.BringToFront()
})
$closeAlertItem = $trayMenu.Items.Add('확인하고 닫기')
$closeAlertItem.Add_Click({ $form.Close() })
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Text = 'GPT 알리미 · 눌러서 다시 열기'
$trayIcon.Icon = [System.Drawing.SystemIcons]::Information
$trayIcon.ContextMenuStrip = $trayMenu
$trayIcon.Visible = $true
$trayIcon.Add_DoubleClick({
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.TopMost = $true
    $form.Activate()
    $form.BringToFront()
})
$form.Add_FormClosed({ $trayIcon.Visible = $false; $trayIcon.Dispose(); $trayMenu.Dispose() })
$script:authStatus = $null
$openChat = { if ($chatUrlValid) { $form.TopMost = $false; Start-Process -FilePath $ChatUrl; if ($script:authStatus) { $script:authStatus.Text = '대화창을 열었습니다. 이 알림은 확인을 누를 때까지 유지됩니다.' } } }
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
$action.Location = [System.Drawing.Point]::new(20, $(if ($hasAuthControls) { 126 } elseif ($hasAuthContext) { 126 } else { 98 }))
$action.Size = [System.Drawing.Size]::new(490, 66)
$action.Add_Click($openChat)
$form.Controls.Add($action)

if ($hasAuthContext) {
    $service = if ([string]::IsNullOrWhiteSpace($AuthService)) { '인증 서비스 확인 필요' } else { $AuthService }
    $account = if ([string]::IsNullOrWhiteSpace($AuthAccount)) { '계정 확인 필요' } else { $AuthAccount }
    $identity = New-Object System.Windows.Forms.Label
    $identity.Text = "인증 대상  ·  $service  ·  $account"
    $identity.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $identity.ForeColor = [System.Drawing.Color]::FromArgb(166, 212, 230)
    $identity.Location = [System.Drawing.Point]::new(20, 98)
    $identity.Size = [System.Drawing.Size]::new(490, 22)
    $identity.Add_Click($openChat)
    $form.Controls.Add($identity)
}

if ($script:recommendation) {
    $recommendationLink = New-Object System.Windows.Forms.LinkLabel
    $recommendationLink.Text = "이번 달 개발자 추천: $($script:recommendation.Title) ↗"
    $recommendationLink.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $recommendationLink.LinkColor = [System.Drawing.Color]::FromArgb(140, 227, 194)
    $recommendationLink.Location = [System.Drawing.Point]::new(20, 170)
    $recommendationLink.Size = [System.Drawing.Size]::new(330, 18)
    $recommendationLink.Add_LinkClicked({ Start-Process -FilePath $script:recommendation.Url })
    $form.Controls.Add($recommendationLink)

    $recommendationNote = New-Object System.Windows.Forms.Label
    $recommendationNote.Text = '관심 주제는 기기에만 저장 · 추천 AI 토큰 0 · 대화 본문 미저장'
    $recommendationNote.Font = New-Object System.Drawing.Font('Segoe UI', 7)
    $recommendationNote.ForeColor = [System.Drawing.Color]::FromArgb(166, 184, 197)
    $recommendationNote.Location = [System.Drawing.Point]::new(20, 190)
    $recommendationNote.Size = [System.Drawing.Size]::new(490, 15)
    $form.Controls.Add($recommendationNote)
}

$bottom = if ($hasAuthControls) { 270 } elseif ($script:recommendation) { 216 } elseif ($hasAuthContext) { 206 } else { 176 }

if ($hasAuthControls) {
    $script:authStatus = New-Object System.Windows.Forms.Label
    $script:authStatus.Location = [System.Drawing.Point]::new(20, 198)
    $script:authStatus.Size = [System.Drawing.Size]::new(490, 18)
    $script:authStatus.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $script:authStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 227, 194)
    $form.Controls.Add($script:authStatus)

    if ($actionUrlValid) {
        $loginButton = New-Object System.Windows.Forms.Button
        $loginButton.Text = '요청 페이지 열기'
        $loginButton.Location = [System.Drawing.Point]::new(20, 222)
        $loginButton.Size = [System.Drawing.Size]::new(225, 30)
        $loginButton.Add_Click({
            $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            if ($script:authExpiresAt -gt 0 -and $now -ge $script:authExpiresAt) { Update-AuthControls; return }
            $form.TopMost = $false
            Start-Process -FilePath $ActionUrl
            $script:authStatus.Text = '요청 페이지를 브라우저 앞으로 열었습니다. 이 알림은 유지됩니다.'
            $script:authStatusPinned = $true
        })
        $form.Controls.Add($loginButton)
        $script:loginButton = $loginButton
    }
    if ($reissueAvailableAt -gt 0) {
        $reissueButton = New-Object System.Windows.Forms.Button
        $reissueButton.Text = '새 인증 링크 요청'
        $reissueButton.Location = [System.Drawing.Point]::new(260, 222)
        $reissueButton.Size = [System.Drawing.Size]::new(250, 30)
        $reissueButton.Add_Click({
            if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $script:authReissueAvailableAt) { return }
            $serviceName = if ($AuthService) { $AuthService } else { '인증 서비스' }
            $accountName = if ($AuthAccount) { $AuthAccount } else { '계정 확인 필요' }
            Set-Clipboard "$serviceName 계정 $accountName의 이전 인증 링크/코드가 만료되었거나 재요청 제한이 끝났습니다. 이전 값은 재사용하지 말고 새 인증 링크 또는 코드를 발급해 주세요."
            $form.TopMost = $false
            if ($chatUrlValid) { Start-Process -FilePath $ChatUrl }
            $script:authStatus.Text = '새 인증 요청 문구를 복사했습니다. 대화창에서 붙여넣어 전송하세요.'
            $script:authStatusPinned = $true
        })
        $form.Controls.Add($reissueButton)
        $script:reissueButton = $reissueButton
    }
    $authTimer = New-Object System.Windows.Forms.Timer
    $authTimer.Interval = 1000
    $authTimer.Add_Tick({ Update-AuthControls })
    $authTimer.Start()
}

$mute = New-Object System.Windows.Forms.Button
$mute.Text = if ($script:soundEnabled) { '소리 끄기' } else { '소리 켜기' }
$mute.Location = [System.Drawing.Point]::new(20, $bottom)
$mute.Size = [System.Drawing.Size]::new(105, 30)
$mute.Add_Click({
    $script:soundEnabled = -not $script:soundEnabled
    $mute.Text = if ($script:soundEnabled) { '소리 끄기' } else { '소리 켜기' }
    Set-Content -NoNewline -Encoding ascii -Path $soundPreferenceFile -Value $(if ($script:soundEnabled) { 'on' } else { 'off' })
})
$form.Controls.Add($mute)

$pause = New-Object System.Windows.Forms.Button
$pause.Text = '24시간 중지'
$pause.Location = [System.Drawing.Point]::new(145, $bottom)
$pause.Size = [System.Drawing.Size]::new(150, 30)
$pause.Add_Click({
    [DateTime]::UtcNow.AddHours(24).ToString('o') | Set-Content -Encoding utf8 -LiteralPath $pauseUntilPreferenceFile
    $form.Close()
})
$form.Controls.Add($pause)

if ($chatUrlValid) {
    $open = New-Object System.Windows.Forms.Button
    $open.Text = '채팅 열기'
    $open.Location = [System.Drawing.Point]::new(322, $bottom)
    $open.Size = [System.Drawing.Size]::new(90, 30)
    $open.Add_Click($openChat)
    $form.Controls.Add($open)
}

$done = New-Object System.Windows.Forms.Button
$done.Text = '확인'
$done.Location = [System.Drawing.Point]::new(424, $bottom)
$done.Size = [System.Drawing.Size]::new(86, 30)
$done.Add_Click({ $form.Close() })
$form.Controls.Add($done)
[void]$form.ShowDialog()
