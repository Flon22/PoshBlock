# PoshBlock

This is a clone of Arcanoid, built using Powershell and WinForms, because why not. 

Levels are stored in txt files in the Levels folder using comma delimited columns.   
Columns are currently:  
|X Location|Y Location|Colour|Width (optional)|
|---|---|---|---|

Each row defines a new block piece.  
**X and Y locations** are coordinates in Pixel values.  
**Colour** can be defined as 0-9 for set colours, or any hex value.   
**Width** is a pixel width optional, and defaults to 70 if not present. 

For example:  
100,150,3  
180,150,3,50

ToDo:
- [ ] Scoring
- [ ] Lives / Game Over
- [ ] Level Switching
- [ ] High Score
- [ ] More Levels


