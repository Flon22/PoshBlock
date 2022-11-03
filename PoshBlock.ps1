Add-Type -AssemblyName System.Windows.Forms
add-type -assemblyname System.Drawing
#[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'

## DEBUG
$debug = $false # True for mouse movement
$levelSelect = $null # set to either null or number

## BOUNDARIES
$leftXBound = 50
$rightXBound = 750
$topYBound = 50
$bottomYBound = 700

## SPEEDS
$frameTime = 12
$paddleSpeed = 10
$ballSpeed = 7
$powerUpSpeed = 5

## GLOBAL LOGIC
# There's an issue with variable scope in Timers so it's easier to just use a tonne of globals 
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
    8="#67AFBE"
    9="#880C58"
    0="#d40db2"
}
$global:powers = @{
    0="#14a35e"
    1="#441ab8"
    2="#6c1ab8"
}
$global:powerUpChance = 35
$global:livesLeft = 3
$global:resetTrigger = $false
$global:nextLevel = $false
$global:currentPowerUps = @()
$global:currentBalls = @()
$global:doubleScore = $false

## LEVELS
$levelLocation = ".\Levels\"


#####  GENERATION FUNCTIONS

## GENERATE A NEW BALL
function New-Ball($xLoc = 0, $yLoc = 0, $angle = 20, $speed = $ballSpeed, $form){
    $ballButton = [System.Windows.Forms.Button]::new()
    $ballButton.text = ""
    $ballButton.FlatAppearance.BorderSize = 0
    $ballButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ballButton.AutoSize = $false
    $ballButton.width = 10
    $ballButton.height = 10
    $ballButton.location = New-Object System.Drawing.Point($xLoc,$yLoc)
    $ballButton.BackColor = "#359fb5"
    $form.controls.add($ballButton)
    $ballButton.BringToFront()

    $ball = New-Object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        angle = $angle;
        speed = $speed;
        button = $ballButton;
        destroy = $false;
        }
    return $ball

}

## GENERATE A NEW POWERUP
function New-PowerUp($xLoc = 0, $yLoc = 0, $angle = 270, $speed = $powerUpSpeed, $form){
    # Colour is based on the power which is chosen at random from the hashtable
    $power = Get-Random -Minimum 0 -Maximum $global:powers.Count
    #$power = 2
    $colour = $global:powers[$power]

    $powerButton = [System.Windows.Forms.Button]::new()
    $powerButton.text = ""
    $powerButton.FlatAppearance.BorderSize = 0
    $powerButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $powerButton.AutoSize = $false
    $powerButton.width = 7
    $powerButton.height = 5
    $powerButton.location = New-Object System.Drawing.Point($xLoc,$yLoc)
    $powerButton.BackColor = $colour
    $form.controls.add($powerButton)
    $powerButton.BringToFront()

    $powerUp = New-Object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        angle = $angle;
        speed = $speed;
        button = $powerButton;
        power = $power;
        destroy = $false;
        enabled = $false;
        guid = New-Guid;
        timer = 100;
        }
    return $powerUp

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

##### POWERUP FUNCTIONS

## UPDATE A GIVEN POWERUPS POSITION
function Update-PowerUpPosition($powerUp, $paddle, $form, $debug = $false){
    # Generate new coordinates and find center of object
    $tempYLocPUp = New-YLoc $powerUp
    $tempXLocPUp = $powerUp.button.location.x
    $powerUpXMid = [float]$powerUp.button.location.x + ([float]$powerUp.button.width / 2)
    $powerUpYMid = [float]$tempYLocPUp + ([float]$PowerUp.button.height / 2)

    # if it collides with button, then activate specific power
    if($powerUpYMid -ge $paddle.yLoc -and $powerUpYMid -le $paddle.yLocBott -and $powerUpXMid -gt $paddle.xLoc -and $powerUpXMid -lt $paddle.xLocRight){
        $powerUp.enabled = $true

    }elseif($powerUp.button.location.y -gt $bottomYBound){
        $powerUp.destroy = $true

    }
    # update Powerup location
    $powerUp.yLoc = $tempYLocPUp
    $powerUp.xLoc = $tempXLocPUp
    $powerUp.button.location = New-Object System.Drawing.Point($powerUp.xLoc,$powerUp.yLoc)
    return $powerUp
}


##### BALL FUNCTIONS

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
        # use cursor as ball position if debug is set
        $cursorXPos = [System.Windows.Forms.Cursor]::Position.x
        $cursorYPos = [system.windows.forms.cursor]::Position.Y
        $tempXLoc = $cursorXPos - $form.location.x
        $tempYLoc = $cursorYPos - $form.location.Y
    }else{
        # Generate new coordinates
        $tempXLoc = New-XLoc $ball
        $tempYLoc = New-YLoc $ball
    
    }
    
    # Check collision on new coordinates - return bounce direction
    $collision = ""
    $collision = Test-Collision $tempXLoc $tempYLoc $ball $paddle $form
    
    # if it collides, then calulate the new angle and redo coordinates
    if($collision -ne "" -and $collision -ne 6){
        # get new angle based on collision direction
        $ball = New-BallAngle $collision $ball $paddle
        Switch($collision){
            {$_ -eq 1 -or $_ -eq 3}{
                $tempXLoc = New-XLoc $ball
            }
            {$_ -eq 2 -or $_ -eq 4 -or $_ -eq 5}{
                $tempYLoc = New-YLoc $ball
            }
        }
    }elseif($collision -eq 6){
        # collision = 6 means the ball has hit the bottom border and is out of bounds
        if($global:livesLeft -gt 0){
            # Sets the ball to destroy itself
            $ball.destroy = $true
        }else{
            # if the player has no further lives then the game is ended
            $global:gameEnabled = $false
        }
        
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

        if($global:currentBlocks.Count -eq 0){
            $global:nextLevel = $true

        }

        # Roll dice and spawn in a Powerup
        $diceRoll = Get-Random -Minimum 0 -Maximum 100
        if($diceRoll -lt $global:powerUpChance){
            #Spawn Powerup
            $powerUp = New-PowerUp -xLoc -10 -yLoc -10 -form $form
            
            $spawnX = [float]$collisionBlock[0].button.location.x + ([float]$collisionBlock[0].button.width / 2) - ([float]$powerUp.width / 2)
            $spawnY = [float]$collisionBlock[0].button.location.y + ([float]$collisionBlock[0].button.height / 2) - ([float]$powerUp.height / 2)
            $powerUp.xLoc = $spawnX
            $powerUp.yLoc = $spawnY
            $powerUp.button.location = New-Object System.Drawing.Point($powerUp.xLoc,$powerUp.yLoc)
            $global:currentPowerUps += $powerUp
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

## CHECK FOR INTERSECTION USING ALGORITHM BASED FRANKLIN ANTONIO'S INTERSECTION ALGORITHM
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

    
    }while(($ball.angle -gt 360 -or $ball.angle -lt 0) -and $null -ne $ball.angle)    
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

    return $paddle
}


##### LEVEL GENERATION FUNCTIONS

## PICK UP LEVELS FROM FOLDER AND RETURN AS HASHTABLE
Function Read-Levels($location){
    $levels = Get-ChildItem -Path $location -Filter *.txt | sort-object -Property Name -Descending
    $allLevels = @{}
    $levelNum = 0
    $levels | ForEach-Object{
        $currentLevel = @()
        [System.IO.File]::ReadLines("$($_.FullName)") | ForEach-Object{
            if($_ -notmatch "^#.*"){
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
                if($xLoc){
                    $currentLevel += $blockObj
                }
            }
        }
        $allLevels.add($levelnum,$currentLevel)
        $levelNum += 1
    }
    return $allLevels
}


##### UI FUNCTIONS

## UPDATE SCOREBOARD - SET GLOBAL AND UPDATE UI
function Update-Score($score){
    if($global:doubleScore){
        $activePowerUpCount = $($global:currentPowerUps | where-object {$_.power -eq 2}).count
        $score = [float]$score * $([float]$activePowerUpCount + 1)
    }
    $global:score += $score
    $scoreDisplay.text = $global:score
}

 ## UPDATE PLAYER LIVES COUNTER = SET GLOBAL AND UPDATE UI
function Update-Lives($livesDisplay){
    $global:livesLeft--
    $livesDisplay.text = [float]$global:LivesLeft
}

## MAIN FORM
Function Open-PoshBlock($level, $debug = $false, $frameTime){
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

    # Return GroupBox as background
    function New-PlayBackground(){
        $playBackground = New-Object system.windows.forms.groupbox
        $playBackground.location = new-object System.Drawing.Point([float]$leftXBound,$([float]$topYBound - 10))
        $tempWidth = [float]$rightXBound - [float]$leftXBound
        $playBackground.width = $tempWidth + ($ball.width / 2)
        $playBackground.height = $form.height
        $form.controls.add($playBackground)
        return $playBackground
    }

    function Get-RandomAngle(){
        $angle = get-random -Minimum 35 -Maximum 145
        return [float]$angle
    }

    # Reset the UI after a life is lost
    function Reset-GameBoard($form, $paddle, $playBackground, $livesDisplay){
        # loop though current balls in play and remove from form
        $global:currentBalls | foreach-object {
            $form.controls.remove($_.button)
        }
        $form.controls.remove($paddle.button)
        $form.controls.remove($playBackground)

        # Create new ball array and populate with new ball
        $global:currentBalls = @()
        $randomAngle = Get-RandomAngle
        $ball = New-Ball -form $form -xLoc 350 -yLoc 600 -angle $randomAngle
        $global:currentBalls += $ball

        # Set variables with Scope 2 - this sets the values in the form scope (not the best way to do this I know.)
        Set-Variable -name paddle -scope 2 -value $(New-Paddle -form $form)
        Set-Variable -name playBackground -scope 2 -value $(New-PlayBackground)

        # Update the amount of lives displayed in UI
        Update-Lives $livesDisplay
    }

    # Create Main ball and Paddle 
    $paddle = New-Paddle -form $form
    $randomAngle = Get-RandomAngle
    $ball = New-Ball -form $form -xLoc 350 -yLoc 600 -angle $randomAngle
    $global:currentBalls += $ball

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
            $global:currentBalls = @()
            $global:currentPowerUps = @()
            $Timer.stop()
            $form.close()

        }
        if($global:gameEnabled){
            if($global:resetTrigger){
                Reset-GameBoard $form $paddle $playBackground $livesDisplay
                $global:resetTrigger = $false

            }
            $currentBallsCount = $global:currentBalls.Count
            for($i = 0; $i -lt $currentBallsCount; $i++){
                $global:currentBalls[$i] = Update-BallPosition $global:currentBalls[$i] $paddle $form $debug
                if($global:currentBalls[$i].destroy){
                    if($currentBallsCount -eq 1){
                        ## reset game - causes player to lose a life
                        write-host "lose life"
                        $global:resetTrigger = $true
                    }else{
                        $form.controls.remove($global:currentBalls[$i].button)
                        $global:currentBalls = @($global:currentBalls | where-object{$_ -ne $global:currentBalls[$i]})
                        $currentBallsCount = $global:currentBalls.Count
                    }
                }
            }
            # On each frame, update the ball and paddle positions
            #$ball = Update-BallPosition $ball $paddle $form $debug
            if($global:currentPowerUps.count -gt 0){
                $currentPowerUpCount = $global:currentPowerUps.Count
                
                for($i = 0; $i -lt $currentPowerUpCount; $i++){
                    if(!$global:currentPowerUps[$i].enabled){
                        $global:currentPowerUps[$i] = Update-PowerUpPosition $global:currentPowerUps[$i] $paddle $form $debug
                    }
                    if($global:currentPowerUps[$i].enabled){
                        $form.controls.remove($global:currentPowerUps[$i].button)
                        Switch($global:currentPowerUps[$i].power){
                            0{
                                # MultiBall
                                write-host "MultiBall"
                                $global:currentPowerUps[$i].enabled = $false
                                $ball = New-Ball -form $form -xLoc $global:currentBalls[0].button.location.x -yLoc $global:currentBalls[0].button.location.y -angle $([float]$global:currentBalls[0].angle + 20)
                                $global:currentBalls += $ball
                                $global:currentPowerUps[$i].destroy = $true
                            }
                            1{
                                # Extended paddle
                                if($global:currentPowerUps[$i].timer -eq 100){
                                    write-host "Extended Paddle"
                                    $paddle.button.location.x = [float]$paddle.button.location.x - 10
                                    $paddle.button.width = [float]$paddle.button.width + 20
                                    $global:currentPowerUps[$i].timer -= 0.2

                                }elseif($global:currentPowerUps[$i].timer -le 0){
                                    $paddle.button.location.x = [float]$paddle.button.location.x + 10
                                    $paddle.button.width = [float]$paddle.button.width - 20
                                    $global:currentPowerUps[$i].enabled = $false
                                    $global:currentPowerUps[$i].destroy = $true

                                }else{
                                    $global:currentPowerUps[$i].timer -= 0.2

                                }
                                
                            }
                            2{
                                # Mini paddle, double score
                                if($global:currentPowerUps[$i].timer -eq 100){
                                    write-host "Mini Paddle - Bonus Points"
                                    $paddle.button.location.x = [float]$paddle.button.location.x + 10
                                    $paddle.button.width = [float]$paddle.button.width - 20
                                    $global:currentPowerUps[$i].timer -= 0.2
                                    $global:doubleScore = $true

                                }elseif($global:currentPowerUps[$i].timer -le 0){
                                    $paddle.button.location.x = [float]$paddle.button.location.x = 10
                                    $paddle.button.width = [float]$paddle.button.width + 20
                                    $global:currentPowerUps[$i].enabled = $false
                                    $global:currentPowerUps[$i].destroy = $true
                                    $global:doubleScore = $false

                                }else{
                                    $global:currentPowerUps[$i].timer -= 0.2
                                    $global:doubleScore = $true

                                }
                            }
                        }
                        
                    }
                    if($global:currentPowerUps[$i].destroy){
                        $global:currentPowerUps = @($global:currentPowerUps | where-object {$_ -ne $global:currentPowerUps[$i]})
                        $currentPowerUpCount = $global:currentPowerUps.Count

                    }
                }

            }
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

## IF LEVELSELECT IS POPULATED, LOAD LEVEL
if($null -ne $levelSelect){
    if($global:gameEnabled){
        Open-PoshBlock $levels[$levelSelect] $debug $frameTime
    }
}else{
    ## SEND EACH LEVEL TO FORM
    foreach($key in $levels.keys){
        if($global:gameEnabled){
            Open-PoshBlock $levels[$key] $debug $frameTime
        }
    }
}
write-host "Game Over!"
write-host "Score: $global:score"
pause
