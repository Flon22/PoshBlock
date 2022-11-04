# PoshBlock

## Description
This is a block breaking game written from scratch using Powershell and WinForms.
Bounce the ball around to break the blocks. Once all blocks are gone you move onto the next level. 
There are currently 6 levels. These are stored in text files which you can add to. 

There are currently 3 powerups. 
Green is Multiball
Purple is Mini paddle which multiplies your score for a duration
Blue extends the paddle for a duration


## Level Design
Levels are stored in txt files in the Levels folder using comma delimited columns.   
Each row defines a new block piece.  
Columns are currently:  
|X Location|Y Location|Colour|Score(optional)|Width (optional)|
|---|---|---|---|---|

**X and Y locations** are coordinates in Pixel values.  
**Colour** can be defined as 0-9 for set colours, or any hex value.   
**Score** is a point score value for a custom colour. This is mandatory if a hex colour value is set.  
**Width** is a pixel width optional, and defaults to 70 if not present. 

For example:  
100,150,3  
180,150,3,,50  
180,150,#FFF000,10,50

There is a template available which is a grid of 10x10. 
Comments can be added, prefix with a Hash "#"
