# PoshBlock

This is a clone of Arcanoid, built using Powershell and WinForms, because why not. 

Levels are stored in txt files in the Levels folder using comma delimited columns.   
Columns are currently:  
|X Location|Y Location|Colour|Score(optional)|Width (optional)|
|---|---|---|---|---|

Each row defines a new block piece.  
**X and Y locations** are coordinates in Pixel values.  
**Colour** can be defined as 0-9 for set colours, or any hex value.   
**Score** is a point score value for a custom colour. This is mandatory if a hex colour value is set.  
**Width** is a pixel width optional, and defaults to 70 if not present. 

For example:  
100,150,3  
180,150,3,,50  
180,150,#FFF000,10,50

ToDo:
- [x] Scoring
- [x] Lives / Game Over
- [x] Level Switching
- [ ] Powerups
- [ ] High Score
- [ ] More Levels


