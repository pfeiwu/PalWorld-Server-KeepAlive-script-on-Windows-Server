# 初始化变量以记录上次启动时间
$lastStartTime = $null
$nextRestartTime = $null
# 获取用户输入的策略和时间间隔
Write-Host "请选择重启策略："
Write-Host "输入 '1' - 定时重启"
Write-Host "输入 '2' - 自动重启，当服务进程不存在时启动服务"
$restartPolicyInput = Read-Host "请输入您选择的策略编号"
$restartInterval = 0
$restartPolicy = ""
$restartTimeInput = $null
$nowDate = Get-Date

function Read-HostAsInt
{
    param(
        [string]$Prompt
    )

    do
    {
        $input = Read-Host $Prompt
        $intInput = $null
        $isInt = [int]::TryParse($input, [ref]$intInput)
        if (-not$isInt)
        {
            Write-Host "输入的不是有效的数字，请重新输入。"
        }
    } while (-not$isInt)

    return $intInput
}

# 设置下一次重启时间
function Set-NextRestartTime
{
    param(
        [DateTime]$nowDate, # 当前时间
        [DateTime]$LastStartTime, # 上次启动时间
        [int]$Interval, # 重启间隔时间（分钟）
        [DateTime]$FixedTime # 每天固定时间重启的时间
    )

    switch ($restartPolicyChoice)
    {
        "1" {
            # 定时重启（间隔时间）
            return $LastStartTime.AddMinutes($Interval)
        }
        "2" {
            # 每天固定时间重启
            $currentDate = $nowDate
            $nextTime = $currentDate.Date.AddHours($FixedTime.Hour).AddMinutes($FixedTime.Minute)
            if ($nextTime -lt $currentDate)
            {
                $nextTime = $nextTime.AddDays(1)
            }
            return $nextTime
        }
        default {
            throw "无效的重启策略选择。"
        }
    }
}

switch ($restartPolicyInput)
{
    "1" {
        $restartPolicy = "定时重启"
        # 提示用户选择重启策略
        Write-Host "请选择定时重启策略:"
        Write-Host "1: 定时重启（间隔时间）"
        Write-Host "2: 每天固定时间重启"
        $restartPolicyChoice = Read-Host "选择一个选项（输入数字1或2）"
        # 根据用户选择设置重启策略
        if ($restartPolicyChoice -eq "1")
        {
            # 用户选择了定时重启（间隔时间）
            $restartInterval = Read-HostAsInt "请输入重启间隔时间（分钟）"
            $nextRestartTime = $nowDate.AddMinutes($restartInterval)
        }
        elseif ($restartPolicyChoice -eq "2")
        {
            # 用户选择了每天固定时间重启
            $restartTimeInput = Read-Host "请输入每天希望重启的时间（24小时制，格式为 'HH:mm', 例如 '03:00'）"
            $restartTime = [DateTime]::ParseExact($restartTimeInput, 'HH:mm', $null)
            $currentDate = $nowDate
            $nextRestartTime = $currentDate.Date.AddHours($restartTime.Hour).AddMinutes($restartTime.Minute)
            if ($nextRestartTime -lt $currentDate)
            {
                $nextRestartTime = $nextRestartTime.AddDays(1)
            }
        }
        else
        {
            Write-Host "无效的选项，请重新运行脚本并选择有效的重启策略。"
            exit
        }
    }
    "2" {
        $restartPolicy = "自动重启"
    }
    default {
        Write-Host "输入的策略编号不正确。"
        exit
    }
}

# 用户输入SteamCMD路径
$steamCmdPath = Read-Host "请输入steamcmd.exe所在文件夹的路径，例如C:\steamcmd\"


# 确保路径以反斜杠结束
if (-not $steamCmdPath.EndsWith("\"))
{
    $steamCmdPath += "\"
}

$executablePath = "${steamCmdPath}steamapps\common\PalServer\Pal\Binaries\Win64\PalServer-Win64-Test-Cmd.exe"
$savedPath = "${steamCmdPath}steamapps\common\PalServer\Pal\Saved"
$savedBackUpPath = "${steamCmdPath}steamapps\common\PalServer\Pal\SavedBackUp"
$savedBackUpSizeThresholdInMB = 300

Write-Host "是否需要定时备份Saved文件夹？"
Write-Host "输入 '1' - 是，‘2’ - 否"
$backupSavedFolderInput = Read-Host "请输入您的选择"
$backupSavedFolder = $false
if ($backupSavedFolderInput -eq "1")
{
    $backupSavedFolder = $true
    $backupInterval = Read-HostAsInt "请输入备份间隔时间（分钟)"
    $nextBackupTime = $nowDate.AddMinutes($backupInterval)
    $savedBackUpSizeThresholdInMB = Read-HostAsInt "请输入备份文件夹大小阈值（MB）, 如果超过这个阈值，将会删除最早的备份文件"
    $lastBackupTime = $null
}


# 开始主循环
while ($true)
{
    Clear-Host
    $nowDate = Get-Date
    Write-Host "服务器路径: $executablePath"
    # 显示当前策略
    Write-Host "当前重启策略: $restartPolicy"

    # 如果是定时重启，显示下一次重启时间
    if ($restartPolicy -eq "定时重启")
    {
        Write-Host "下一次重启时间: $nextRestartTime"
    }

    # 获取 PalServer-Win64-Test-Cmd.exe 进程
    $process = Get-Process PalServer-Win64-Test-Cmd -ErrorAction SilentlyContinue

    # 检查进程是否在运行
    if ($process -eq $null)
    {
        Write-Host "PalServer未启动"
        # 启动进程并更新上次启动时间
        Start-Process $executablePath
        $lastStartTime = $nowDate
        if ($restartPolicy -eq "定时重启" -and $restartPolicyChoice -eq "1")
        {
            $nextRestartTime = $lastStartTime.AddMinutes($restartInterval)
        }
    }
    else
    {
        Write-Host "PalServer正在运行中"
    }

    # 显示上次启动时间
    if ($lastStartTime -ne $null)
    {
        Write-Host "服务器上次启动时间: $lastStartTime"
    }

    # 检查是否到达预定的重启时间
    if ($restartPolicy -eq "定时重启" -and $nowDate -ge $nextRestartTime)
    {
        Write-Host "到达预定的重启时间，正在重启服务..."
        Stop-Process -Name PalServer-Win64-Test-Cmd -Force # 强制停止进程
        Start-Sleep -Seconds 5 # 等待进程完全停止
        Start-Process $executablePath # 启动进程
        $lastStartTime = $nowDate # 更新上次启动时间
        $nextRestartTime = Set-NextRestartTime -nowDate $nowDate -LastStartTime $lastStartTime -Interval $restartInterval -FixedTime $restartTime # 更新下一次重启时间
        Write-Host "服务已重启。"
    }

    # 检查是否到达预定的备份时间
    if ($backupSavedFolder -and $nowDate -ge $nextBackupTime)
    {
        Write-Host "到达预定的备份时间，正在备份Saved文件夹..."
        # 生成带时间戳的备份文件夹名称
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $currentBackupPath = "$savedBackUpPath\$timestamp"

        # 检查备份文件夹是否存在
        if (-not(Test-Path $currentBackupPath))
        {
            # 如果不存在，创建文件夹
            New-Item -ItemType Directory -Path $currentBackupPath | Out-Null
        }

        # 复制Saved文件夹到新的带时间戳的备份文件夹
        Copy-Item $savedPath $currentBackupPath -Recurse -Force

        # 检查备份文件夹大小是否超过阈值
        $savedBackUpSizeInMB = (Get-ChildItem $savedBackUpPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
        while ($savedBackUpSizeInMB -gt $savedBackUpSizeThresholdInMB) {
            # 找到最旧的备份文件夹
            $oldestDir = Get-ChildItem $savedBackUpPath -Directory | Sort-Object CreationTime | Select-Object -First 1
            if ($oldestDir) {
                # 如果存在旧的备份文件夹，则删除它
                Remove-Item $oldestDir.FullName -Recurse -Force
                # 重新计算备份文件夹大小
                $savedBackUpSizeInMB = (Get-ChildItem $savedBackUpPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
            } else {
                # 如果没有找到任何备份文件夹，则退出循环
                Write-Host "没有更多的备份文件夹可以删除。"
                break
            }
        }

        # 更新下一次备份时间
        $nextBackupTime = $nowDate.AddMinutes($backupInterval)

        # 更新上次备份时间
        $lastBackupTime = $nowDate

        Write-Host "Saved文件夹已备份到 $currentBackupPath。"
    }

    if ($backupSavedFolder)
    {
        Write-Host "上次备份时间: $lastBackupTime"
        Write-Host "下一次备份时间: $nextBackupTime"
    }


    # 获取并显示当前系统内存占用情况
    # 获取物理内存使用情况
    $os = Get-CimInstance Win32_OperatingSystem
    $totalPhysicalMemory = $os.TotalVisibleMemorySize
    $freePhysicalMemory = $os.FreePhysicalMemory

    # 计算已用内存和使用百分比
    $usedPhysicalMemory = $totalPhysicalMemory - $freePhysicalMemory
    $memUsageValue = [math]::Round(($usedPhysicalMemory / $totalPhysicalMemory) * 100, 2)

    Write-Host "当前内存使用占比: $memUsageValue %"
    # 如果内存使用率超过阈值，发送服务器内警报
    if ($memUsageValue -ge 98)
    {
        arrcon -H 127.0.0.1 -P 25575 -p kuroameserver "Broadcast alert_mem_committed_percent:$memUsageValue%"
    }
    if ($memUsageValue -ge 99)
    {
        arrcon -H 127.0.0.1 -P 25575 -p kuroameserver "Broadcast this_server_will_reboot_soon_due_to_memory_leakage"
    }
    $arrconShowPlayersResp = arrcon -H 127.0.0.1 -P 25575 -p kuroameserver showPlayers

    # 将输出按行分割为数组
    $playerLines = $arrconShowPlayersResp -split "`r`n"

    # 创建一个数组来存储玩家对象
    $playerList = @()

    foreach ($line in $playerLines)
    {
        # 忽略空行、非数据行和表头行
        if (-not [string]::IsNullOrWhiteSpace($line) -and $line -notmatch "playeruid|name|steamid")
        {
            # 分割玩家信息
            $playerFields = $line -split "," | ForEach-Object { $_.Trim() }

            # 检查是否有三个字段（姓名，UID，SteamID）
            if ($playerFields.Count -eq 3)
            {
                # 创建一个自定义对象并添加到数组
                $playerObj = New-Object PSObject -Property @{
                    姓名 = $playerFields[0]
                    UID = $playerFields[1]
                    SteamID = $playerFields[2]
                }

                $playerList += $playerObj
            }
        }
    }
    # 输出表格
    Write-Host "在线玩家:"
    $playerList | Format-Table -AutoSize
    # 等待一段时间
    Start-Sleep -Seconds 30
}