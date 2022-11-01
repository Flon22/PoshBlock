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
    $button.width = 13
    $button.height = 13
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
function New-Block($xLoc = 100, $yLoc = 100, $colour, $width, $form){
    if($colour -notmatch "\#"){
        $backColour = $global:blockColours[[int]$colour]
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

    $xLocRight = [int]$xLoc + 70
    $yLocBott = [int]$yLoc + 20

    $paddle = new-object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        xLocRight = $xLocRight;
        yLocBott = $yLocBott;
        button = $button;
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
    $paddle = new-object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        xLocRight = $xLocRight;
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
        $global:gameEnabled = $false
    }
    # update ball location
    $ball.yLoc = $tempYLoc
    $ball.xLoc = $tempXLoc
    $ball.button.location = New-Object System.Drawing.Point($ball.xLoc,$ball.yLoc)
        
    return $ball

}

## CHECK COLLISION FOR BALL ON A GIVEN X & Y COORDINATE
function Test-Collision($xLoc, $yLoc, $ball, $paddle, $form){
    # Direction is which wall it has bounced off of. 1 = Right wall, 2 = Top wall, 3 = Left Wall, 4 = Bottom
    $direction = ""
    $ballXMid = $xLoc + ($ball.button.width / 2)
    $ballYMid = $yLoc + ($ball.button.height / 2)

    # Returns all objects that the ball will collide with on the next frame
    $collisionBlock = $global:currentBlocks | where-object {[float]$_.xLoc -lt [float]$ballXMid -and [float]$_.xLocRight -gt [float]$ballXMid -and [float]$_.yLoc -lt [float]$ballYMid -and [float]$_.yLocBott -gt [float]$ballYMid}

    # If a collision is returned then then handle collision
    if($collisionBlock){
        # Check the collision direction to generate a direction to bounce
        $currBallXMid = $ball.button.location.x + ($ball.button.width / 2)
        $currBallYMid = $ball.button.location.y + ($ball.button.width / 2)
        $direction = Test-CollisionDirection $ballXMid $ballYMid $collisionBlock[0] $currBallXMid $currBallYMid

        # Set the block to invisible and remove it from the block arraylist
        $collisionBlock[0].button.visible = $false
        $global:currentblocks.remove($collisionBlock[0])

    }else{
        # If there isnt a block collision, then check for a collision with the boundaries
        Switch ($xLoc){
            {$_ + $ball.button.width -ge $rightXBound} {
                    $direction = 1 # Collision with right boundary
                }
            {$_ -le $leftXBound} { 
                    $direction = 3 # Collision with left boundary
                } 
        }
        Switch ($yLoc){
            {$_ -le $topYBound} {
                    $direction = 2 # Collision with top boundary
                }
            {$_ -ge $bottomYBound} {
                    $direction = 6 # a collision with the bottom boundary is a game over/lose life
                }
            {$_ -ge $paddle.button.location.y - ($paddle.button.height / 2)}{
                # if the location is below paddle distance then check for paddle collision
                if($xLoc -gt $paddle.button.location.x -and $xLoc -lt $paddle.xLocRight){
                    $direction = 5
                }
            }
        }
    }
    return $direction
}

## CHECK COLLISION DIRECTION USING LINE SEGMENT INTERSECTION ALGORITHM
function Test-CollisionDirection($ballXMid, $BallMid, $collisionBlock, $xLoc, $yLoc){
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
            2{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x;
                    yLoc = $collisionBlock.button.location.y;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x + $collisionBlock.button.width;
                    yLoc = $collisionBlock.button.location.y;
                }
            }
            1{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x + $collisionBlock.button.width;
                    yLoc = $collisionBlock.button.location.y;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x + $collisionBlock.button.width;
                    yLoc = $collisionBlock.button.location.y + $collisionBlock.button.height;
                }
            }
            3{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x;
                    yLoc = $collisionBlock.button.location.y;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x;
                    yLoc = $collisionBlock.button.location.y + $collisionBlock.button.height;
                }
            }
            4{
                $pointC = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x;
                    yLoc = $collisionBlock.button.location.y + $collisionBlock.button.height;
                }
                $pointD = new-object PsObject -Property @{
                    xLoc = $collisionBlock.button.location.x + $collisionBlock.button.width;
                    yLoc = $collisionBlock.button.location.y + $collisionBlock.button.height;
                }
            }
        }
        # test each wall against the ball vectors
        $testIntersect = Test-LineIntersect $pointA $pointB $pointC $pointD
        write-host $testIntersect
        if($testIntersect){$direction = $i}

    }
    return $direction

}

# CHECK FOR INTERSECTION USING ALGORITHM BASED ON "FASTER LINE SEGMENT INTERSECTION" BY FRANKLIN ANTONIO
function Test-LineIntersect($p1, $p2, $p3, $p4){
    $a = New-SubtractedVector $p2 $p1
    $b = New-SubtractedVector $p3 $p4
    $c = New-SubtractedVector $p1 $p3
    write-host "p1: $p1   p2: $p2   p3: $p3   p4: $p4"
    write-host "a: $a   b: $b   c: $c"

    $alphaNum = ([float]$b.yLoc * [float]$c.xLoc) - ([float]$b.xLoc * [float]$c.yLoc)
    $betaNum = ([float]$a.xLoc * [float]$c.yLoc) - ([float]$a.yLoc * [float]$c.xLoc)
    $den = ([float]$a.yLoc * [float]$b.xLoc) - ([float]$a.xLoc * [float]$b.yLoc)
    write-host "AN: $alphaNum    BN: $betaNum   DN: $den"
    $doIntersect = $true
    if($den -eq 0){
        $doIntersect = $false
    } elseif($den -gt 0){
        if($alphaNum -lt 0 -or $alphaNum -gt $den -or $betaNum -lt 0 -or $betaNum -gt $den){
            write-host "Top Check"
            $doIntersect = $false
        }

    } elseif($alphaNum -gt 0 -or $alphaNum -lt $den -or $betaNum -gt 0 -or $betaNum -lt $den){
        write-host "Bot Check"
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
            #write-host "BallX " $ballx "  PaddleX " $paddlex "  Angle " $angle
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
    $paddle.xLocRight = $paddle.button.location.x + $paddle.button.width
    # Update paddle position
    $paddle.button.location = New-Object System.Drawing.Point($padXPos, $paddle.button.location.y)

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
            $width = $_.split(",")[3]
            
            if(!$width){
                $width = 70
            }
            
            
            $blockObj =  new-object PsObject -Property @{
                xLoc = $xLoc;
                yLoc = $yLoc;
                colour = $colour;
                width = $width;
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

    ## LOAD LEVEL
    Function Initialize-Level($level, $form){
        foreach($levelItem in $level){
            $xLoc = $levelItem.xLoc
            $yLoc = $levelItem.yLoc
            $colour = $levelItem.colour
            $width = $levelItem.width
            $block = New-Block $xLoc $yLoc $colour $width $form
            [void]$global:currentBlocks.add($block)
        }
    }
    
    $ball = New-Ball -form $form -xLoc 350 -yLoc 600 -angle 140
    if(!$debug){
        # Create Main ball and Paddle
        $paddle = New-Paddle -form $form
    }

    # Load Level
    Initialize-Level $level -form $form

    # Timer acts as our main thread, each tick is a single frame
    $Timer = New-Object System.Windows.Forms.Timer
    $Timer.interval = $frameTime
    $Timer.add_tick({
        if($global:gameEnabled){
            # On each frame, update the ball and paddle positions
            $ball = Update-BallPosition $ball $paddle $form $debug
            if(!$debug){
                $paddle = Update-PaddlePosition $paddle $form
            
            }

        }else{
            write-host "Game Over!"
            $Timer.stop()
            $form.close()
        }
    })
    $timer.Start()

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
    Open-PoshBlock $levels[$key] $false

}
