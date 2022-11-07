# PoshBlock

## Description
This is a block breaking game written from scratch using Powershell and WinForms.
Bounce the ball around to break the blocks. Once all blocks are gone you move onto the next level. 
There are currently 6 levels. These are stored in text files which you can add to for custom levels.

There are currently 3 powerups.   
![Colour of hex value #14a35e](https://placehold.co/15x15/14a35e/14a35e.png) Green is Multiball  
![Colour of hex value #3492eb](https://placehold.co/15x15/3492eb/3492eb.png) Blue extends the paddle for a duration  
![Colour of hex value #6c1ab8](https://placehold.co/15x15/6c1ab8/6c1ab8.png) Purple is Mini paddle which multiplies your score for a duration  




## Level Design
Levels are stored in txt files in `.\Levels\` using comma delimited columns. The game loads every level contained within this folder in alphabetical order. Each row in a txt file defines a new block piece.  
There is a template available which is a grid of 10x10.  
Comments can be added, prefix with a Hash "#"

#### Columns
|X Location|Y Location|Colour|Score (optional)|Width (optional)|
|---|---|---|---|---|
|Coordinate in Pixel values|Coordinate in Pixel values|0-9 for set colours, or any hex value|Point score value for a custom colour. This is mandatory if a hex colour value is set|Pixel width, and defaults to 70 if not present|

#### Example text
```
100,150,3  
180,150,3,,50  
180,150,#FFF000,10,50
```

#### Colours 

||Number|HexValue|Score|
|---|---|---|---|
|![Colour of hex value #E02424](https://placehold.co/15x15/E02424/E02424.png)|1|#E02424|10|
|![Colour of hex value #E06624](https://placehold.co/15x15/E06624/E06624.png)|2|#E06624|20|
|![Colour of hex value #E0C124](https://placehold.co/15x15/E0C124/E0C124.png)|3|#E0C124|30|
|![Colour of hex value #A3D620](https://placehold.co/15x15/A3D620/A3D620.png)|4|#A3D620|40|
|![Colour of hex value #249E49](https://placehold.co/15x15/249E49/249E49.png)|5|#249E49|50|
|![Colour of hex value #19BCC2](https://placehold.co/15x15/19BCC2/19BCC2.png)|6|#19BCC2|60|
|![Colour of hex value #1946C2](https://placehold.co/15x15/1946C2/1946C2.png)|7|#1946C2|70|
|![Colour of hex value #67AFBE](https://placehold.co/15x15/67AFBE/67AFBE.png)|8|#67AFBE|80|
|![Colour of hex value #880C58](https://placehold.co/15x15/880C58/880C58.png)|9|#880C58|90|
|![Colour of hex value #D40DB2](https://placehold.co/15x15/D40DB2/D40DB2.png)|0|#D40DB2|0|




https://user-images.githubusercontent.com/49537164/200406559-ea27e872-b03f-451a-a410-c4afb7759353.mp4

