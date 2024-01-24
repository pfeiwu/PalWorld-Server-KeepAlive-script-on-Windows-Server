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

switch ($restartPolicyInput) {
    "1" {
        $restartPolicy = "定时重启"
       	# 提示用户选择重启策略
        Write-Host "请选择定时重启策略:"
        Write-Host "1: 定时重启（间隔时间）"
        Write-Host "2: 每天固定时间重启"
        $restartPolicyChoice = Read-Host "选择一个选项（输入数字1或2）"
        # 根据用户选择设置重启策略
        if ($restartPolicyChoice -eq "1") {
            # 用户选择了定时重启（间隔时间）
            $restartInterval = Read-Host "请输入重启间隔时间（分钟）"
            $nextRestartTime = (Get-Date).AddMinutes($restartInterval)
        } elseif ($restartPolicyChoice -eq "2") {
            # 用户选择了每天固定时间重启
            $restartTimeInput = Read-Host "请输入每天希望重启的时间（24小时制，格式为 'HH:mm', 例如 '03:00'）"
            $restartTime = [DateTime]::ParseExact($restartTimeInput, 'HH:mm', $null)
            $currentDate = Get-Date
            $nextRestartTime = $currentDate.Date.AddHours($restartTime.Hour).AddMinutes($restartTime.Minute)
            if ($nextRestartTime -lt $currentDate) {
                $nextRestartTime = $nextRestartTime.AddDays(1)
            }
        } else {
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
if (-not $steamCmdPath.EndsWith("\")) {
    $steamCmdPath += "\"
}

$executablePath = "${steamCmdPath}steamapps\common\PalServer\Pal\Binaries\Win64\PalServer-Win64-Test-Cmd.exe"
# 开始主循环
while ($true) { 
    Clear-Host
    Write-Host "服务器路径: $executablePath"
    # 显示当前策略
    Write-Host "当前重启策略: $restartPolicy"
    
    # 如果是定时重启，显示下一次重启时间
    if ($restartPolicy -eq "定时重启") {
        Write-Host "下一次重启时间: $nextRestartTime"
    }

    # 获取 PalServer-Win64-Test-Cmd.exe 进程
    $process = Get-Process PalServer-Win64-Test-Cmd -ErrorAction SilentlyContinue

    # 检查进程是否在运行
    if ($process -eq $null) {
        Write-Host "PalServer未启动"
        # 启动进程并更新上次启动时间
        Start-Process $executablePath
        $lastStartTime = Get-Date
        if ($restartPolicy -eq "定时重启" -and $restartPolicyChoice -eq "1") {
            $nextRestartTime = $lastStartTime.AddMinutes($restartInterval)
        }
    } else {
        Write-Host "PalServer正在运行中"
    }

    # 显示上次启动时间
    if ($lastStartTime -ne $null) {
        Write-Host "服务器上次启动时间: $lastStartTime"
    }

    # 检查是否到达预定的重启时间
    if ($restartPolicy -eq "定时重启" -and (Get-Date) -ge $nextRestartTime) {
        Write-Host "到达预定的重启时间，正在重启服务..."
        Stop-Process -Name PalServer-Win64-Test-Cmd -Force
        Start-Sleep -Seconds 5 # 等待进程完全停止
        Start-Process $executablePath
        $lastStartTime = Get-Date

        $nextRestartTime = $lastStartTime.AddMinutes($restartInterval)
        if ($restartPolicyChoice -eq "1") {
            # 用户选择了定时重启（间隔时间）
            $nextRestartTime = (Get-Date).AddMinutes($restartInterval)
        } elseif ($restartPolicyChoice -eq "2") {
            # 用户选择了每天固定时间重启
            $currentDate = Get-Date
            $nextRestartTime = $currentDate.Date.AddHours($restartTime.Hour).AddMinutes($restartTime.Minute)
            if ($nextRestartTime -lt $currentDate) {
                $nextRestartTime = $nextRestartTime.AddDays(1)
            }
        }
        Write-Host "服务已重启。"
    }

    # 获取并显示当前系统内存占用情况
    $memUsage = Get-Counter '\Memory\% Committed Bytes In Use'
    $memUsageValue = [math]::Round($memUsage.CounterSamples.CookedValue, 2)
    Write-Host "当前内存使用占比: $memUsageValue %"

    # 定位文件夹0中最近更新的子文件夹
    $baseSaveGamePath = Join-Path -Path $steamCmdPath -ChildPath "steamapps\common\PalServer\Pal\Saved\SaveGames\0"
    $latestFolder = Get-ChildItem -Path $baseSaveGamePath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    # 如果找到了最新的文件夹，则构建完整的Players路径
    if ($latestFolder -ne $null) {
        $saveGamePath = Join-Path -Path $latestFolder.FullName -ChildPath "Players"
        # 检索 .sav 文件并统计修改时间在2分钟内的文件数量
        $allSavFiles = Get-ChildItem -Path $saveGamePath -Filter *.sav
        $recentSavFiles = $allSavFiles | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-2) }
    } else {
        Write-Host "未找到游戏保存文件夹"
    }


    # 显示在线玩家数量
    $onlinePlayers = $recentSavFiles.Count
    $totalPlayers = $allSavFiles.Count
    Write-Host "在线玩家数: $onlinePlayers / $totalPlayers"

    # 等待一段时间
    Start-Sleep -Seconds 30

}
