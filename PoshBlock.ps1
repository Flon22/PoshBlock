Add-Type -AssemblyName System.Windows.Forms
add-type -assemblyname System.Drawing
Add-Type -AssemblyName PresentationCore,PresentationFramework
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
    1="#3492eb"
    2="#6c1ab8"
}
$global:ballGradientDefaultColour = @{
    0="#101085"
    1="#303090"
    2="#404095"
    3="#50509b"
    4="#6060a0"
    5="#7070a5"
    6="#8080ab"
    7="#9090b0"
    8="#a0a0b5"
    9="#b0b0bb"
}
$global:ballGradientDarkColour = @{
    0="#3394a8"
    1="#318a9c"
    2="#2f7f90"
    3="#2e7483"
    4="#2a5f6a"
    5="#264a51"
    6="#253f45"
    7="#233438"
    8="#212a2b"
}

$global:powerUpChance = 35
$global:livesLeft = 3
$global:resetTrigger = $false
$global:nextLevel = $false
$global:currentPowerUps = @()
$global:currentBalls = @()
$global:doubleScore = $false
$global:startTimer = 50
$global:defaultColour = $true
$global:directMouseMovement = $true
$global:ballTrails = $true
$global:ballTrailCount = 3

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
    if(!$global:defaultColour){
        $ballButton.BackColor = "#359fb5"
    }else{
        $ballButton.BackColor = "#000080"
    }
    $trails = @()
    $ballHistory = @()

    # Adds ball trails if enabled
    if($global:ballTrails){
        if($global:defaultColour){
            $ballTrailColourCount = $global:ballGradientDefaultColour.count - 1
        }else{
            $ballTrailColourCount = $global:ballGradientDarkColour.count - 1
        }
        # Generate colour based on percentage of trail objects vs the amount of colours available
        for($i = 0;$i -lt $global:ballTrailCount;$i++){
            $colour = $ballTrailColourCount - [math]::round(($i / $global:ballTrailCount) * $ballTrailColourCount)
            $trails += New-BallTrail $colour
        }
    }
    $form.controls.add($ballButton)
    $ballButton.BringToFront()

    $ball = New-Object PsObject -Property @{
        xLoc = $xLoc;
        yLoc = $yLoc;
        angle = $angle;
        speed = $speed;
        button = $ballButton;
        destroy = $false;
        trails = $trails;
        history = $ballHistory;
        }
    return $ball

}

## GENERATE A NEW TRAIL OBJECT
function New-BallTrail($colour = 0){
    $ballTrailButton = [System.Windows.Forms.Button]::new()
    $ballTrailButton.text = ""
    $ballTrailButton.FlatAppearance.BorderSize = 0
    $ballTrailButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ballTrailButton.AutoSize = $false
    $ballTrailButton.width = 10
    $ballTrailButton.height = 10
    $ballTrailButton.location = New-Object System.Drawing.Point(-10,-10)
    if($global:defaultColour){
        $backColour = $global:ballGradientDefaultColour[[int]$colour]
    }else{
        $backColour = $global:ballGradientDarkColour[[int]$colour]
        
    }
    $ballTrailButton.BackColor = $backColour
    $form.controls.add($ballTrailButton)
    $ballTrailButton.BringToFront()
    $ballTrail = New-Object PsObject -Property @{
        button = $ballTrailButton;
    }
    return $ballTrail
}

## GENERATE A NEW POWERUP
function New-PowerUp($xLoc = 0, $yLoc = 0, $angle = 270, $speed = $powerUpSpeed, $form){
    # Colour is based on the power which is chosen at random from the hashtable
    $power = Get-Random -Minimum 0 -Maximum $global:powers.Count
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
    if(!$global:defaultColour){
        $button.BackColor = "#890D58"
    }
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
        # Generate new coordinates for next frame
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
        if($global:livesLeft -gt 1){
            # Sets the ball to destroy itself
            $ball.destroy = $true
        }else{
            # if the player has no further lives then the game is ended
            $global:gameEnabled = $false
        }
        
    }

    if($global:ballTrails){
        # Update ball history with current position before moving ball
        $ball.history += New-Object System.Drawing.Point($ball.xLoc,$ball.yLoc)
        
        # Remove any older history
        if($ball.history.count -gt $global:ballTrailCount){
            $ball.history = $ball.history | Select-object -last $global:ballTrailCount
        }
        
        # Update trail positions with current history
        for($i = 0; $i -lt $ball.history.count; $i++){
            $ball.trails[$i].button.location = $ball.history[$i]
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
    # Direction is which wall of either boundary or block it has bounced off of. 1 = Bounce Left, 2 = Bounce Down, 3 = Bounce Right, 4 = Bounce Up, 5 = Bounce Up from paddle, 6 = Collision with bottom boundary
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

        # If no further blocks remain, set the next level trigger
        if($global:currentBlocks.Count -eq 0){
            $global:nextLevel = $true

        }

        # Roll dice and spawn in a Powerup
        $diceRoll = Get-Random -Minimum 0 -Maximum 100
        if($diceRoll -lt $global:powerUpChance){
            #Spawn Powerup out of bounds
            $powerUp = New-PowerUp -xLoc -10 -yLoc -10 -form $form
            
            # Move powerup to blocks location. This is done as an additional step so we can use the powerup width
            $spawnX = [float]$collisionBlock[0].button.location.x + ([float]$collisionBlock[0].button.width / 2) - ([float]$powerUp.width / 2)
            $spawnY = [float]$collisionBlock[0].button.location.y + ([float]$collisionBlock[0].button.height / 2) - ([float]$powerUp.height / 2)
            $powerUp.xLoc = $spawnX
            $powerUp.yLoc = $spawnY
            $powerUp.button.location = New-Object System.Drawing.Point($powerUp.xLoc,$powerUp.yLoc)

            # Add to active powerup array
            $global:currentPowerUps += $powerUp
        }

    }else{
        # If there isnt a block collision, then check for a collision with the boundaries
        Switch ($ballXMid){
            {$_-ge $rightXBound} {
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
                # Collision with paddle
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
    # Subtract vectors to generate new vecs
    $a = New-SubtractedVector $p2 $p1
    $b = New-SubtractedVector $p3 $p4
    $c = New-SubtractedVector $p1 $p3

    # Multiply vectors together. We only need the A and B numerators and the first denominator to find if an intersection exists so we dont do the full calculation.
    $alphaNum = ([float]$b.yLoc * [float]$c.xLoc) - ([float]$b.xLoc * [float]$c.yLoc)
    $betaNum = ([float]$a.xLoc * [float]$c.yLoc) - ([float]$a.yLoc * [float]$c.xLoc)
    $den = ([float]$a.yLoc * [float]$b.xLoc) - ([float]$a.xLoc * [float]$b.yLoc)
    
    # Rules for intersection. Intersection is true if none of the following IF statements apply
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
    # Given a direction, work out the new angle by mirroring current angle. 
    Switch($direction){
        {$_ -eq 1 -or $_ -eq 3}{
            $ball.angle = 180 - $ball.angle
        }
        {$_ -eq 2 -or $_ -eq 4}{
            $ball.angle = (360 - $ball.angle)
        }
        5{
            # If there is a paddle collision, the ball angle is based on where the ball hits the paddle.
            $paddleX = $paddle.button.location.x
            $ballX = $ball.button.location.x + ($ball.button.width / 2)
            $paddleWidth = $paddle.button.width
            $tempX = $ballX - $paddleX
            $percent = $tempX / $paddleWidth
            $angle = 180 - ([math]::round((160 * $percent) + 10))
            $ball.angle = $angle

        }

    }
    # If mirroring the angle has caused it to go over or below 0-360 then normalise it back to within 0-360
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
    $padXPos = $cursorXPos

    if($global:directMouseMovement){
        # if direct mouse movement is enabled then use the mouse position as the paddle position.
        if($cursorXPos + $paddle.button.width -ge $rightXBound -or $cursorXPos -le $leftXBound){
            $padXPos = $paddle.button.location.x
        }else{
            $padXPos = $cursorXPos
        }
    }else{
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
            # Pick up lines if not blank and not comments. Comments are started with '#'
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
    # if there is an active mini-paddle powerup, then multiply the score by the number of active powerups before adding to the global
    if($global:doubleScore){
        $activePowerUpCount = $($global:currentPowerUps | where-object {$_.power -eq 2}).count
        $score = [float]$score * $([float]$activePowerUpCount + 2)
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
    $form = New-Object system.Windows.Forms.Form
    $form.ClientSize = "800,700"
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedSingle' 
    $form.controlbox = $true
    $form.StartPosition = "CenterScreen"
    if(!$global:defaultColour){
        $form.backcolor = "#1f1f1f"
    }else{
        $form.backcolor = "#C0C0C0"
    }
    $form.ShowInTaskbar = $false
    $form.Add_Shown({
        $form.Activate()
    })

    # load level
    Function Initialize-Level($level, $form){
        # Iterates through the level items, generates a new block in place and adds it to the global array
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
        $tempHeight = [float]$bottomYBound - [float]$topYBound
        $playBackground.width = $tempWidth + ($ball.width / 2)
        $playBackground.height = $tempHeight
        $form.controls.add($playBackground)
        return $playBackground
    }

    # Generates a random angle to start the first ball
    function Get-RandomAngle(){
        $angle = get-random -Minimum 35 -Maximum 145
        return [float]$angle
    }

    # Reset the UI after a life is lost
    function Reset-GameBoard($form, $paddle, $playBackground, $livesDisplay){
        # loop though current balls in play and remove from form
        $global:currentBalls | foreach-object {
            if($global:ballTrails){
                $_.trails | foreach-object {
                    $form.controls.remove($_.button)
                }
            }
            $form.controls.remove($_.button)
        }
        $form.controls.remove($paddle.button)
        $form.controls.remove($playBackground)

        # Create new ball array and populate with new ball
        $global:currentBalls = @()
        $randomAngle = Get-RandomAngle
        $ball = New-Ball -form $form -xLoc 350 -yLoc 600 -angle $randomAngle
        $global:currentBalls += $ball

        # Set variables with Scope 2 - this sets the values in the form scope (not the best way to do this I know, but timers bugger the scope up)
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
    if($global:defaultColour){
        $textColour = "#000000"
    }else{
        $textColour = "#ffffff"
    }
    $scoreLabel = New-Label "SCORE -" 570 20 $textColour 100 "MiddleRight"
    $scoreDisplay = New-Label $global:score 670 20 $textColour 80 "MiddleRight"
    $livesLabel = New-Label "- LIVES" 80 20 $textColour 100 "MiddleLeft"
    $livesDisplay = New-Label $global:livesLeft 50 20 $textColour 80 "MiddleLeft"
    $form.controls.addRange(@($scoreLabel,$scoreDisplay,$livesLabel,$livesDisplay))

    # Draw game area
    $playBackground = New-PlayBackground
    

    # Timer acts as the main update thread, each tick is a single frame
    $Timer = New-Object System.Windows.Forms.Timer
    $Timer.interval = $frameTime
    $Timer.add_tick({
        $frameTimer = Measure-Command{
            # if the nextlevel trigger is enabled after breaking all blocks, load unload the current level
            if($global:nextLevel){
                write-host "Level End"
                $global:nextLevel = $false
                $global:currentBalls = @()
                $global:currentPowerUps = @()
                $global:startTimer = 50
                $Timer.stop()
                $form.close()
            }
            # If the gameEnabled variable is true, run the standard update, false means a gameover condition
            if($global:gameEnabled){
                # if the resetTrigger is True, the ball needs to be reset after losing a life before the next frame
                if($global:resetTrigger){
                    Reset-GameBoard $form $paddle $playBackground $livesDisplay
                    $global:resetTrigger = $false
                    $global:startTimer = 50

                }
                if($global:startTimer -eq 0){
                    # Count current balls in play then update the position of each one. 
                    $currentBallsCount = $global:currentBalls.Count
                    for($i = 0; $i -lt $currentBallsCount; $i++){
                        # Update position of ball
                        $global:currentBalls[$i] = Update-BallPosition $global:currentBalls[$i] $paddle $form $debug
                        # Destroy the ball if it has collided with the bottom of the play area
                        if($global:currentBalls[$i].destroy){
                            # If the ball is the last one in the array, lose a life and reset on the next frame
                            if($currentBallsCount -eq 1){
                                write-host "lose life"
                                $global:resetTrigger = $true
                            }else{
                                # If there are more balls in play, remove the current ball and update the ballcount
                                if($global:ballTrails){
                                    $global:currentBalls[$i].trails | foreach-object {
                                        $form.controls.remove($_.button)
                                    }
                                }
                                $form.controls.remove($global:currentBalls[$i].button)
                                $global:currentBalls = @($global:currentBalls | where-object{$_ -ne $global:currentBalls[$i]})
                                $currentBallsCount = $global:currentBalls.Count
                            }
                        }
                    }

                    # If there are powerups in play, update their positions and perform their actions
                    if($global:currentPowerUps.count -gt 0){

                        $currentPowerUpCount = $global:currentPowerUps.Count
                        # For each powerup in play, update their movement if they are not currentlyenabled
                        for($i = 0; $i -lt $currentPowerUpCount; $i++){
                            if(!$global:currentPowerUps[$i].enabled){
                                $global:currentPowerUps[$i] = Update-PowerUpPosition $global:currentPowerUps[$i] $paddle $form $debug
                            }
                            # If they are enabled then perform the powerup action
                            if($global:currentPowerUps[$i].enabled){
                                # Remove the form item if it is present
                                $form.controls.remove($global:currentPowerUps[$i].button)
                                Switch($global:currentPowerUps[$i].power){
                                    0{
                                        # MultiBall - Add a new ball at the current first ball position with a slightly different angle - powerup is destroyed when used once
                                        write-host "MultiBall"
                                        $global:currentPowerUps[$i].enabled = $false
                                        $ball = New-Ball -form $form -xLoc $global:currentBalls[0].button.location.x -yLoc $global:currentBalls[0].button.location.y -angle $([float]$global:currentBalls[0].angle + 15)
                                        $global:currentBalls += $ball
                                        $global:currentPowerUps[$i].destroy = $true
                                    }
                                    1{
                                        # Extended paddle - Extend the length of the paddle until the timer runs out - destroyed when timer is below zero
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
                                        # Mini paddle - Shorten the paddle until the timer runs out. This also multiplies the score for each powerup enabled - destroyed when timer is below zero
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
                            # If a powerup is set to destroy itself, remove the item from the array and update the count
                            if($global:currentPowerUps[$i].destroy){
                                $global:currentPowerUps = @($global:currentPowerUps | where-object {$_ -ne $global:currentPowerUps[$i]})
                                $currentPowerUpCount = $global:currentPowerUps.Count

                            }
                        }

                    }
                    # If debug is disabled then update the paddle location
                    if(!$debug){
                        $paddle = Update-PaddlePosition $paddle $form
                    }
                }else{
                    $global:startTimer--

                }
            }else{
                $Timer.stop()
                $form.close()

            }
        }
        # write-host "Frametimer:$($frameTime.Milliseconds)"

    })
    $timer.Start()

    # Hide cursor if the mouse is in the gamewindow
    $playBackground.Add_MouseEnter({if($global:gameEnabled){[System.Windows.Forms.Cursor]::Hide()}})
    $form.Add_MouseEnter({if($global:gameEnabled){[System.Windows.Forms.Cursor]::Hide()}})
    $form.Add_MouseLeave({[System.Windows.Forms.Cursor]::Show()})

    # Hide console window
    #$consolePtr = [Console.Window]::GetConsoleWindow()
    #[Console.Window]::ShowWindow($consolePtr, 0) | out-null

    $form.add_Closing({
        if ([System.Diagnostics.StackTrace]::new().GetFrames().GetMethod().Name -ccontains 'Close') {
            # If closed with .Close()
          } else {
            # If closed with x in title bar
            $Timer.stop()
            $form.close()
            $global:gameEnabled = $false
          }
    })

    [void][System.Windows.Forms.Application]::Run($form)
    
}

## LOAD LEVELS
$levels = Read-Levels $levelLocation

## IF LEVELSELECT IS POPULATED, LOAD SPECIFIC LEVEL
if($null -ne $levelSelect){
    if($global:gameEnabled){
        Open-PoshBlock $levels[$levelSelect] $debug $frameTime
    }
}else{
    # Send each level to the form in turn
    foreach($key in $levels.keys){
        if($global:gameEnabled){
            Open-PoshBlock $levels[$key] $debug $frameTime
        }
    }
}
[System.Windows.Forms.Cursor]::Show()
write-host "Game Over!"
write-host "Score: $global:score"
[void][System.Windows.MessageBox]::Show("Game Over!`nScore: $global:score","PoshBlock","OK","None")