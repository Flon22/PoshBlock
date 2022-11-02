Add-Type -AssemblyName System.Windows.Forms
add-type -assemblyname System.Drawing
#[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'

## BOUNDARIES
$leftXBound = 50
$rightXBound = 750
$topYBound = 50
$bottomYBound = 700

## SPEEDS
$frameTime = 12
$paddleSpeed = 10
$ballSpeed = 7

## LOGIC
$global:gameEnabled = $true
$global:currentBlocks = New-Object System.Collections.ArrayList
$global:score = 0
$global:blockColours = @{
    1="#e02424" 
    2="#e06624" 
    3="#e0c124" 
    4="#a3d620"
    5="#249e49"
    6="#19bcc2"
    7="#1946c2"
    8="#1946c2"
    9="#9219c2"
    0="#d40db2"
}
$global:powerUpChance = 10
$global:livesLeft = 3
$global:resetTrigger = $false
$global:nextLevel = $false

## LEVELS
$levelLocation = ".\Levels\"


#####  GENERATION FUNCTIONS

## GENERATE A NEW BALL
function New-Ball($xLoc = 0, $yLoc = 0, $angle = 20, $speed = $ballSpeed, $form){
    $button = [System.Windows.Forms.Button]::new()
    $button.text = ""
    $button.FlatAppearance.BorderSize = 0
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.AutoSize = $false
    $button.width = 10
    $button.height = 10
    $button.location = New-Object System.Drawing.Point($xLoc,$yLoc)
    $button.BackColor = "#359fb5"
    $form.controls.add($button)

    $ball = New-Object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        angle = $angle;
        speed = $speed;
        button = $button;
        }
    return $ball

}


## GENERATE A NEW BLOCK
function New-Block($xLoc = 100, $yLoc = 100, $colour, $width, $form, $score = 10){
    if($colour -notmatch "\#"){
        $backColour = $global:blockColours[[int]$colour]
        $score = [float]$colour * 10
    }else{
        $backColour = $colour
    }
    $button = [System.Windows.Forms.Button]::new()
    $button.text = ""
    $button.AutoSize = $false
    $button.width = $width
    $button.height = 20
    $button.location = New-Object System.Drawing.Point($xLoc,$yLoc)
    $button.BackColor = $backColour
    $form.controls.add($button)

    $xLocRight = [int]$xLoc + $width
    $yLocBott = [int]$yLoc + 20

    $paddle = new-object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        xLocRight = $xLocRight;
        yLocBott = $yLocBott;
        button = $button;
        score = $score;
    }
    return $paddle

}


## GENERATE A NEW PADDLE
function New-Paddle($xLoc = 350, $yLoc = 650, $speed = $paddleSpeed, $form){
    $button = [System.Windows.Forms.Button]::new()
    $button.text = ""
    $button.AutoSize = $false
    $button.width = 100
    $button.height = 20
    $button.location = New-Object System.Drawing.Point($xLoc,$yLoc)
    $button.BackColor = "#890D58"
    $form.controls.add($button)

    $xLocRight = $xLoc + $button.width
    $yLocBott = [int]$yLoc + 20

    $paddle = new-object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        xLocRight = $xLocRight;
        yLocBott = $yLocBott;
        speed = $speed;
        button = $button;
    }
    return $paddle
}


##### BALL MOVEMENT FUNCTIONS

## CONVERT BETWEEN DEGREES AND RADIANS
function ConvertTo-Degrees($angle){
    return $angle * (180 / [math]::pi)
}

function ConvertTo-Radians($angle){
    return $angle * ([math]::pi / 180)
}

## UPDATE A GIVEN BALLS POSITION
function Update-BallPosition($ball, $paddle, $form, $debug = $false){
    # Debug
    if($debug){
        # Get current cursor position and normalise it to the center of the current form location
        $cursorXPos = [System.Windows.Forms.Cursor]::Position.x
        $cursorYPos = [system.windows.forms.cursor]::Position.Y
        $tempXLoc = $cursorXPos - $form.location.x
        $tempYLoc = $cursorYPos - $form.location.Y
    }else{
        # Generate new coordinates
        $tempXLoc = New-XLoc $ball
        $tempYLoc = New-YLoc $ball
    
    }
    $collision = ""
    # Check collision on new coordinates
    $collision = Test-Collision $tempXLoc $tempYLoc $ball $paddle $form
    
    # if it collides, then calulate the new angle and redo coordinates
    if($collision -ne "" -and $collision -ne 6){
        $ball = New-BallAngle $collision $ball $paddle
        Switch($direction){
            {$_ -eq 1 -or $_ -eq 3}{
                $tempXLoc = New-XLoc $ball
            }
            {$_ -eq 2 -or $_ -eq 4 -or $_ -eq 5}{
                $tempYLoc = New-YLoc $ball
            }
        }
    }elseif($collision -eq 6){
        if($global:livesLeft -gt 0){
            ## reset game
            $global:resetTrigger = $true
        }else{
            $global:gameEnabled = $false
        }
        
    }
    # update ball location
    $ball.yLoc = $tempYLoc
    $ball.xLoc = $tempXLoc
    $ball.button.location = New-Object System.Drawing.Point($ball.xLoc,$ball.yLoc)
    return $ball

}

## UPDATE SCOREBOARD
function Update-Score($score){
    $global:score += $score
    $scoreDisplay.text = $global:score
}

## CHECK COLLISION FOR BALL ON A GIVEN X & Y COORDINATE
function Test-Collision($xLoc, $yLoc, $ball, $paddle, $form){
    # Direction is which wall it has bounced off of. 1 = Right wall, 2 = Top wall, 3 = Left Wall, 4 = Bottom
    $direction = ""
    $ballXMid = [float]$xLoc + ([float]$ball.button.width / 2)
    $ballYMid = [float]$yLoc + ([float]$ball.button.height / 2)
    $currBallXMid = [float]$ball.button.location.x + ([float]$ball.button.width / 2)
    $currBallYMid = [float]$ball.button.location.y + ([float]$ball.button.height / 2)

    # Returns all objects that the ball will collide with on the next frame
    $collisionBlock = $global:currentBlocks | where-object {[float]$_.xLoc -lt [float]$ballXMid -and [float]$_.xLocRight -gt [float]$ballXMid -and [float]$_.yLoc -lt [float]$ballYMid -and [float]$_.yLocBott -gt [float]$ballYMid}

    # If a collision is returned then then handle collision
    if($collisionBlock){
        # Check the collision direction to generate a direction to bounce
        $direction = Test-CollisionDirection $ballXMid $ballYMid $collisionBlock[0] $currBallXMid $currBallYMid

        # Set the block to invisible and remove it from the block arraylist
        $collisionBlock[0].button.visible = $false
        $global:currentblocks.remove($collisionBlock[0])
        
        # Update score variable and UI
        Update-Score $collisionBlock[0].score

        if($global:currentBlocks.length -eq 0){
            $global:nextLevel = $true

        }

        # Roll dice and spawn in a Powerup
        $diceRoll = Get-Random -Minimum 0 -Maximum 100
        if($diceRoll -lt $global:powerUpChance){
            #Spawn Powerup

        }

    }else{
        # If there isnt a block collision, then check for a collision with the boundaries
        Switch ($ballXMid){
            {$_ + $ball.button.width -ge $rightXBound} {
                    $direction = 1 # Collision with right boundary
                }
            {$_ -le $leftXBound} { 
                    $direction = 3 # Collision with left boundary
                } 
        }
        Switch ($ballYMid){
            {$_ -le $topYBound} {
                    $direction = 2 # Collision with top boundary
                }
            {$_ -ge $bottomYBound} {
                    $direction = 6 # a collision with the bottom boundary is a game over/lose life
                    break
                }
            {$_ -ge $paddle.yLoc -and $_ -le $paddle.yLocBott -and $ballXMid -gt $paddle.xLoc -and $ballXMid -lt $paddle.xLocRight}{
                $direction = Test-CollisionDirection $ballXMid $ballYMid $paddle $currBallXMid $currBallYMid
                if($direction -eq 4){$direction = 5}
                #write-host "COLLISION - $direction"
                
            }
        }
    }
    return $direction
}

## CHECK COLLISION DIRECTION USING LINE SEGMENT INTERSECTION ALGORITHM
function Test-CollisionDirection($ballXMid, $BallMid, $collisionObject, $xLoc, $yLoc){
    # Generate vectors of the ball position across current and future frame
    $pointA = new-object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
    }
    $pointB = new-object PsObject -Property @{
        xLoc = $ballXMid;
        yLoc = $BallYMid;
    }
    
    $direction = 0
    
    # Generate vectors and test each of the collided block wall segments in turn
    For($i=1;$i -lt 5;$i++){
        Switch($i){
            3{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x + $collisionObject.button.width;
                    yLoc = $collisionObject.button.location.y;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x + $collisionObject.button.width;
                    yLoc = $collisionObject.button.location.y + $collisionObject.button.height;
                }
            }
            4{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x;
                    yLoc = $collisionObject.button.location.y;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x + $collisionObject.button.width;
                    yLoc = $collisionObject.button.location.y;
                }
            }
            1{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x;
                    yLoc = $collisionObject.button.location.y;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x;
                    yLoc = $collisionObject.button.location.y + $collisionObject.button.height;
                }
            }
            2{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x;
                    yLoc = $collisionObject.button.location.y + $collisionObject.button.height;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionObject.button.location.x + $collisionObject.button.width;
                    yLoc = $collisionObject.button.location.y + $collisionObject.button.height;
                }
            }
        }
        # test each wall against the ball vectors
        $testIntersect = Test-LineIntersect $pointA $pointB $pointC $pointD
        if($testIntersect){
            $direction = $i
        }
        
    }
    return $direction

}

## CHECK FOR INTERSECTION USING ALGORITHM BASED ON "FASTER LINE SEGMENT INTERSECTION" BY FRANKLIN ANTONIO
function Test-LineIntersect($p1, $p2, $p3, $p4){
    $a = New-SubtractedVector $p2 $p1
    $b = New-SubtractedVector $p3 $p4
    $c = New-SubtractedVector $p1 $p3

    $alphaNum = ([float]$b.yLoc * [float]$c.xLoc) - ([float]$b.xLoc * [float]$c.yLoc)
    $betaNum = ([float]$a.xLoc * [float]$c.yLoc) - ([float]$a.yLoc * [float]$c.xLoc)
    $den = ([float]$a.yLoc * [float]$b.xLoc) - ([float]$a.xLoc * [float]$b.yLoc)
    $doIntersect = $true
    if($den -eq 0){
        $doIntersect = $false
    } elseif($den -gt 0){
        if($alphaNum -lt 0 -or $alphaNum -gt $den -or $betaNum -lt 0 -or $betaNum -gt $den){
            $doIntersect = $false
        }
    } elseif($alphaNum -gt 0 -or $alphaNum -lt $den -or $betaNum -gt 0 -or $betaNum -lt $den){
        $doIntersect = $false
    }

    return $doIntersect

}

## SUBTRACT VECTORS TO CREATE NEW VECTOR
function New-SubtractedVector($v1, $v2){
    $val1 = [float]$v1.xLoc - [float]$v2.xLoc
    $val2 = [float]$v1.yLoc - [float]$v2.yLoc
    $v3 = new-object PsObject -Property @{
        xLoc = $val1;
        yLoc = $val2;
    }
    return $v3

}

## CALCULATE AND NORMALISE NEW BOUNCE ANGLE
function New-BallAngle($direction, $ball, $paddle){
    # given a direction, work out the new angle by mirroring current angle. 
    Switch($direction){
        {$_ -eq 1 -or $_ -eq 3}{
            $ball.angle = 180 - $ball.angle
        }
        {$_ -eq 2 -or $_ -eq 4}{
            $ball.angle = (360 - $ball.angle)
        }
        5{
            $paddleX = $paddle.button.location.x
            $ballX = $ball.button.location.x + ($ball.button.width / 2)
            $paddleWidth = $paddle.button.width
            $tempX = $ballX - $paddleX
            $percent = $tempX / $paddleWidth
            $angle = 180 - ([math]::round((160 * $percent) + 10))
            $ball.angle = $angle

        }

    }
    # If mirroring the angle has caused it to go over or below 0-360 then normalise it
    do{
        if($ball.angle -gt 360){
            $ball.angle -= 360
        }else{
            $ball.angle += 360
        }

    
    }while($ball.angle -gt 360 -or $ball.angle -lt 0)    
    return $ball
}


## GENERATE A NEW COORDINATES GIVEN THE ANGLE AND SPEED
function New-XLoc($ball){
    # Use trig to work out the x coord based on the having the hyp length and angle
    $xDist = [math]::Cos($(ConvertTo-Radians $ball.angle))
    $tempXLoc = $ball.xloc + ($xDist * $ball.speed)
    return $tempXLoc
}

function New-YLoc($Ball){
    # Use trig to work out the y coord based on the having the hyp length and angle
    $yDist = [math]::Sin($(ConvertTo-Radians $ball.angle))
    $tempYLoc = $ball.yLoc - ($yDist * $ball.speed) 
    return $tempYLoc
}

##### PADDLE MOVEMENT FUNCTIONS

## UPDATE PADDLE POSITION
function Update-PaddlePosition($paddle, $form){
    # Get current cursor position and normalise it to the center of the current form location
    $cursorXPos = [System.Windows.Forms.Cursor]::Position.x
    $cursorXPos = $cursorXPos - $form.location.x

    # Get current Paddle position and normalise to center of paddle (0,0 is top left)
    $padActualPos = $paddle.button.location.x + ($paddle.button.width / 2)

    # If paddle is left of cursor, move right and visa versa. if within 5px then do nothing. 
    if($cursorXPos -lt $padActualPos + 5 -and $cursorXPos -gt $padActualPos - 5){
        $padXPos = $paddle.button.location.x
    }elseif($cursorXPos -ge $padActualPos + 5){
        if($paddle.button.location.x + $paddle.button.width -ge $rightXBound){
            $padXPos = $paddle.button.location.x
        }else{
            $padXPos = $paddle.button.location.x + $paddle.speed
        }
    }else{
        if($paddle.button.location.x -le $leftXBound){
            $padXPos = $paddle.button.location.x
        }else{
            $padXPos = $paddle.button.location.x - $paddle.speed
        }

    }
    $paddle.xLoc = $padXPos
    $paddle.xLocRight = $paddle.button.location.x + $paddle.button.width
    # Update paddle position
    $paddle.button.location = New-Object System.Drawing.Point($padXPos, $paddle.button.location.y)
    #write-host "Paddle x: $($paddle.xloc)   y: $($paddle.yloc)   x2: $($paddle.xLocRight)   y2: $($paddle.yLocBott)"

    return $paddle
}


##### LEVEL GENERATION FUNCTIONS

## PICK UP LEVELS FROM FOLDER AND RETURN AS HASHTABLE
Function Read-Levels($location){
    $levels = Get-ChildItem -Path $location -Filter *.txt
    $allLevels = @{}
    $levelNum = 0
    $levels | ForEach-Object{
        $currentLevel = @()
        [System.IO.File]::ReadLines("$($_.FullName)") | ForEach-Object{
            $xLoc = $_.split(",")[0]
            $yLoc = $_.split(",")[1]
            $colour = $_.split(",")[2]
            $score = $_.split(",")[3]
            $width = $_.split(",")[4]
            
            if(!$width){
                $width = 70
            }
            if(!$score){
                $score = $null
            }
            
            $blockObj =  new-object PsObject -Property @{
                xLoc = $xLoc;
                yLoc = $yLoc;
                colour = $colour;
                width = $width;
                score = $score
            }
            $currentLevel += $blockObj
        }
        $allLevels.add($levelnum,$currentLevel)
        $levelNum += 1
    }
    return $allLevels
}

##### MAIN FORM FUNCTIONS

## MAIN FORM
Function Open-PoshBlock($level, $debug = $false){
    $form                                  = New-Object system.Windows.Forms.Form
    $form.ClientSize                       = "800,700"
    $form.TopMost                          = $true
    $form.FormBorderStyle                  = 'FixedSingle' 
    $form.controlbox                       = $true
    $form.StartPosition                    = "CenterScreen"
    $form.backcolor                        = "#1f1f1f"
    $form.ShowInTaskbar                    = $false
    $form.Add_Shown({
        $form.Activate()
    })

    ## load level
    Function Initialize-Level($level, $form){
        foreach($levelItem in $level){
            $xLoc = $levelItem.xLoc
            $yLoc = $levelItem.yLoc
            $colour = $levelItem.colour
            $width = $levelItem.width
            if($levelItem.score){$score = $levelItem.score}
            $block = New-Block $xLoc $yLoc $colour -score $score -width $width -form $form
            [void]$global:currentBlocks.add($block)
        }
    }
    
    # Create Main ball and Paddle if not in debug mode
    $paddle = New-Paddle -form $form
    $ball = New-Ball -form $form -xLoc 350 -yLoc 600 -angle 130

    # Return fully drawn label object
    function New-Label($text, $x, $y, $foreColour, $width, $align){
        $labelFont = [System.Drawing.Font]::new("Lucida Console", 16)
        $label = New-Object system.windows.forms.label
        $label.location = new-object system.drawing.point($x,$y)
        $label.ForeColor = $foreColour
        $label.text = $text
        $label.textalign = $align
        $label.width = $width
        $label.font = $labelFont
        Return $label
    }

    function New-PlayBackground(){
        $playBackground = New-Object system.windows.forms.groupbox
        $playBackground.location = new-object System.Drawing.Point([float]$leftXBound,$([float]$topYBound - 10))
        $tempWidth = [float]$rightXBound - [float]$leftXBound
        $playBackground.width = $tempWidth + ($ball.width / 2)
        $playBackground.height = $form.height
        $form.controls.add($playBackground)
        return $playBackground
    }

    function Reset-GameBoard($form, $paddle, $playBackground, $ball, $livesDisplay){
        $form.controls.remove($paddle.button)
        $form.controls.remove($ball.button)
        $form.controls.remove($playBackground)
        Set-Variable -name ball -scope 2 -value $(New-Ball -form $form -xLoc 350 -yLoc 600 -angle 140)
        Set-Variable -name paddle -scope 2 -value $(New-Paddle -form $form)
        Set-Variable -name playBackground -scope 2 -value $(New-PlayBackground)

        Update-Lives $livesDisplay
    }

    function Update-Lives($livesDisplay){
        $global:livesLeft--
        $livesDisplay.text = [float]$global:LivesLeft
    }

    # Load Level
    Initialize-Level $level -form $form

    # Draw UI
    $labelFont = [System.Drawing.Font]::new("Lucida Console", 16)
    $scoreLabel = New-Label "SCORE -" 570 20 "#FFFFFF" 100 "MiddleRight"
    $scoreDisplay = New-Label $global:score 670 20 "#FFFFFF" 80 "MiddleRight"
    $livesLabel = New-Label "- LIVES" 80 20 "#FFFFFF" 100 "MiddleLeft"
    $livesDisplay = New-Label $global:livesLeft 50 20 "#FFFFFF" 80 "MiddleLeft"
    $form.controls.addRange(@($scoreLabel,$scoreDisplay,$livesLabel,$livesDisplay))

    # Draw game area
    $playBackground = New-PlayBackground
    

    # Timer acts as our main thread, each tick is a single frame
    $Timer = New-Object System.Windows.Forms.Timer
    $Timer.interval = $frameTime
    $Timer.add_tick({
        if($global:nextLevel){
            write-host "Next Level"
            $global:nextLevel = $false
            $Timer.stop()
            $form.close()

        }
        if($global:gameEnabled){
            if($global:resetTrigger){
                Reset-GameBoard $form $paddle $playBackground $ball $livesDisplay
                $global:resetTrigger = $false

            }
            # On each frame, update the ball and paddle positions
            $ball = Update-BallPosition $ball $paddle $form $debug
            if(!$debug){
                $paddle = Update-PaddlePosition $paddle $form
            }

        }else{
            $Timer.stop()
            $form.close()

        }
    })
    $timer.Start()

    # Hide cursor if the mouse is in the gamewindow
    $playBackground.Add_MouseEnter({[System.Windows.Forms.Cursor]::Hide()})
    $form.Add_MouseEnter({[System.Windows.Forms.Cursor]::Hide()})
    $form.Add_MouseLeave({[System.Windows.Forms.Cursor]::Show()})

    # Hide console window
    #$consolePtr = [Console.Window]::GetConsoleWindow()
    #[Console.Window]::ShowWindow($consolePtr, 0) | out-null

    [void][System.Windows.Forms.Application]::Run($form)
}

## LOAD LEVELS
$levels = Read-Levels $levelLocation

## SEND EACH LEVEL TO USER
foreach($key in $levels.keys){
    if($global:gameEnabled){
        Open-PoshBlock $levels[$key] $false
    }
}

write-host "Game Over!"
write-host "Score: $global:score"
pause
