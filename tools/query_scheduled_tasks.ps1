#Requires -Version 5.1
<#
.SYNOPSIS
    Query and manage scheduled tasks - beginner-friendly script with explanations
.DESCRIPTION
    This script helps you find and inspect scheduled tasks, especially for whkd.
    Each section is commented to explain what the PowerShell commands do.

    FOR BASH USERS:
    ----------------
    PowerShell is similar to bash in many ways:
    - Piping | works the same way: command1 | command2
    - Variables use $ instead of nothing: $name vs name
    - -eq instead of ==, -like instead of *, -match instead of grep
    - Get-Help <command> is like man <command>
#>

#==============================================================================
# PART 1: BASIC QUERY - Find all tasks related to whkd
#==============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PART 1: Searching for whkd tasks..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Get-ScheduledTask gets ALL tasks on your system (like `crontab -l` but system-wide)
# Where-Object filters the list (like `grep` in bash)
# -like is PowerShell's wildcard matching (*whkd* matches anything with "whkd" in it)
# Select-Object picks which columns to show (like `awk '{print $1}'`)
# Format-Table makes it look pretty (like `column -t`)

$whkdTasks = Get-ScheduledTask | Where-Object { 
    $_.TaskName -like "*whkd*"   # Task name contains "whkd"
}

if ($whkdTasks) {
    $whkdTasks | Select-Object TaskName, TaskPath, State, Author | Format-Table -AutoSize
} else {
    Write-Host "No whkd tasks found!" -ForegroundColor Yellow
}


#==============================================================================
# PART 2: DETAILED VIEW - See what a specific task actually does
#==============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PART 2: Detailed task information..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Let's check if the whkd task exists and show details
$taskName = "Restart WHKD"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

# -ErrorAction SilentlyContinue means: if it doesn't exist, don't show scary red errors
# This is like `2>/dev/null` in bash

if ($task) {
    Write-Host "`nFound task: $taskName" -ForegroundColor Green
    Write-Host "----------------------------------------"
    
    # Basic properties (using dot notation like objects in other languages)
    Write-Host "Task Name:    $($task.TaskName)"
    Write-Host "State:        $($task.State)"      # Ready, Running, Disabled
    Write-Host "Author:       $($task.Author)"     # Who created it
    
    # The Actions property tells us WHAT the task does (what program it runs)
    Write-Host "`nWhat does this task do?" -ForegroundColor Yellow
    foreach ($action in $task.Actions) {
        Write-Host "  Program:    $($action.Execute)"
        Write-Host "  Arguments:  $($action.Arguments)"
        Write-Host "  Working Dir:$($action.WorkingDirectory)"
    }
    
    # The Triggers property tells us WHEN the task runs
    Write-Host "`nWhen does this task run?" -ForegroundColor Yellow
    foreach ($trigger in $task.Triggers) {
        if ($trigger.TriggerType -eq "Logon") {
            Write-Host "  Trigger:    At log on (when you sign in to Windows)"
        } elseif ($trigger.TriggerType -eq "Boot") {
            Write-Host "  Trigger:    At system startup"
        } elseif ($trigger.TriggerType -eq "Daily") {
            Write-Host "  Trigger:    Daily at $($trigger.StartBoundary)"
        } else {
            Write-Host "  Trigger:    $($trigger.TriggerType)"
        }
    }
    
} else {
    Write-Host "Task '$taskName' not found." -ForegroundColor Yellow
}


#==============================================================================
# PART 3: LIST ALL YOUR TASKS - See everything you've created
#==============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PART 3: All tasks created by you..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# $env:USERNAME is an environment variable (like $USER or $USERNAME in bash)
# -like "*$env:USERNAME*" matches your username anywhere in the Author field

$myTasks = Get-ScheduledTask | Where-Object { 
    $_.Author -like "*$env:USERNAME*" -or 
    $_.Author -like "*$env:COMPUTERNAME*\$env:USERNAME*"
} | Sort-Object TaskName

Write-Host "`nFound $($myTasks.Count) tasks created by you:`n" -ForegroundColor Green
$myTasks | Select-Object TaskName, State, @{Name="Created"; Expression={$_.Date}} | Format-Table -AutoSize


#==============================================================================
# PART 4: INTERACTIVE MODE - Let you choose what to do
#==============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PART 4: Interactive options..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Show-TaskMenu {
    Write-Host "`nWhat would you like to do?" -ForegroundColor Yellow
    Write-Host "  1. Show full command of the whkd task"
    Write-Host "  2. Check if whkd is currently running"
    Write-Host "  3. Test run the whkd command manually"
    Write-Host "  4. Export task to XML (backup)"
    Write-Host "  5. Exit"
    
    $choice = Read-Host "`nEnter your choice (1-5)"
    
    switch ($choice) {
        "1" {
            # Show the exact command that runs
            $task = Get-ScheduledTask -TaskName "Restart WHKD" -ErrorAction SilentlyContinue
            if ($task) {
                Write-Host "`nFull command that runs at startup:" -ForegroundColor Green
                $cmd = $task.Actions.Execute
                $args = $task.Actions.Arguments
                Write-Host "$cmd $args" -ForegroundColor Cyan
            }
        }
        "2" {
            # Check if process is running (like `ps aux | grep whkd` in bash)
            Write-Host "`nChecking if whkd.exe is running..." -ForegroundColor Yellow
            $process = Get-Process -Name "whkd" -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "✓ whkd is RUNNING (PID: $($process.Id))" -ForegroundColor Green
                Write-Host "  Started: $($process.StartTime)"
                Write-Host "  Running for: $($process.StartTime - (Get-Date))"
            } else {
                Write-Host "✗ whkd is NOT running" -ForegroundColor Red
            }
        }
        "3" {
            # Run the command manually
            Write-Host "`nRunning: taskkill /f /im whkd.exe; Start-Process whkd -WindowStyle Hidden" -ForegroundColor Yellow
            taskkill /f /im whkd.exe 2>$null
            Start-Process whkd -WindowStyle Hidden
            Write-Host "Done! Check if whkd is running (option 2)." -ForegroundColor Green
        }
        "4" {
            # Export to XML
            $backupPath = "$env:USERPROFILE\Documents\whkd_task_backup.xml"
            Export-ScheduledTask -TaskName "Restart WHKD" | Out-File $backupPath
            Write-Host "`n✓ Task exported to: $backupPath" -ForegroundColor Green
        }
        "5" {
            Write-Host "`nGoodbye!" -ForegroundColor Green
            return
        }
        default {
            Write-Host "`nInvalid choice. Please enter 1-5." -ForegroundColor Red
        }
    }
    
    # Pause and show menu again
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Show-TaskMenu
}

# Ask if user wants interactive mode
Write-Host "`nWould you like to enter interactive mode? (y/n)" -ForegroundColor Yellow
$interactive = Read-Host
if ($interactive -eq "y" -or $interactive -eq "Y") {
    Show-TaskMenu
}

Write-Host "`nScript complete!`n" -ForegroundColor Green
