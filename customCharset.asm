#import "../Mega65_System/System_Macros.s"

.const OFFSET = $190        //400 decimal, used in screen operations

System_BasicUpstart65(main) //builds the basic boot strapper

*=$2015
main:
    jsr setup               //setup routine will tell VIC where to find custom charset
                                //and clears the screen
    //jmp *

    jsr fillColorOnline     //fill the lines for the text with repeating color gradient
    eventLoop:
        jsr text            //write text over and over again, as later we will make this
                                //scroll 
        jsr colorCycle      //slide color gradient to the left
        jsr frameWait       //wait for rasterLine (in essense waiting for the next frame)
        jmp eventLoop

frameWait:
    lda #$ff                //loop until 255 is draw by the VIC
  !raster:
    cmp VIC.RASTER_LINE     //compare the current raster line with #$ff
    bne !raster-            //current rasterline not $ff jump to !raster
!end:
rts

// this will slide the colors on the two lines pointed to by SCREEN + OFFSET to the left 
// and inserts the first color at the back. in essence cycling the gradient around
// clobbers, A, X and Y
colorCycle:
  ldx VIC.COLOR_RAM + OFFSET
  ldy #0
!:
  lda VIC.COLOR_RAM + OFFSET + 1, y
  sta VIC.COLOR_RAM + OFFSET + 80 , y
  sta VIC.COLOR_RAM + OFFSET, y
  iny
  cpy #81
  bne !-
  sta VIC.COLOR_RAM + OFFSET + 79
  rts

// returns the next color from the gradientColor array
//clobbers X and A
getGradientColor:
  ldx gradientOffset 
  cpx #14
  beq !+
  jmp !++
!:
  ldx #$00
  stx gradientOffset
!:
  lda gradientColor, x
  inx
  stx gradientOffset
  rts


// Fills the colors of the gradientColors array over the two lines pointed to by 
    //COLOR+RAM + OFFSET, the gradient colors will
// loop when we get to the end of the gradientColors array. 
    //In essence filling the lines with multiple copies of the gradientColors pallet
// clobbers Y and A
fillColorOnline:
  ldy #80      //this is the location offset on the screen for start location
                //we're starting on far left char an going to the right.
!:
  jsr getGradientColor
  sta VIC.COLOR_RAM + OFFSET, y
  sta VIC.COLOR_RAM + OFFSET + 80, y
  dey
  cpy #$ff      //decrement y and branch back if no equal to 255
  bne !-        //this goes back to the last instance of !: (cheap way specify a loop label)
  rts

//Clear the VIC.SCREEN in 4 250 character blocks
//clobbers X and A
clearScreen:
  ldx #250
  lda #32 //blank tile in this map
!:
  dex
  sta VIC.SCREEN, x
  sta VIC.SCREEN+250, x
  sta VIC.SCREEN+500, x
  sta VIC.SCREEN+750, x
  sta VIC.SCREEN+1000, x
  sta VIC.SCREEN+1250, x
  sta VIC.SCREEN+1500, x
  sta VIC.SCREEN+1750, x

  bne !-
  rts

//Sets up the demo, where the character ram is pointed to $3000
// and the screen is cleared
// and border and background are set to black
// clobbers A, X and Y
setup:
  jsr pointToRAMCharSet
    
  lda #$00              //this is the color black
  sta VIC.BORDER_COLOR
  sta VIC.SCREEN_COLOR

  jsr clearScreen
  rts


// Draws the line of text to the screen on localation SCREEN+OFFSET
// The font we use is an "elongated font", that uses two characters, the top half and the bottom half.
// The top and bottom part of each letter are offset by 127 characters
text:
  ldx #$00
!write:   
  lda text1, x                          // load next character from the string text1
  cmp #$00                              // keep printing the text tuill we find character 00
  beq !end+                             // branch on equal, goes to next instance of end
   
  sta VIC.SCREEN + OFFSET, x            // write top half of the character
  adc #127                              // add 127 to the character to point to the bottom half of the character
  sta VIC.SCREEN + OFFSET + 80, x       // write bottom half of the character on the next line
  inx                                   // inc offset for chracter string and location on the screen
  jmp !write-
!end:
  rts

//Point to Charset in $3000, we use 3000 because later we will later set sid tune on 2000
pointToRAMCharSet:
  //Table of lower nibble and the corresponding character ram address
  //$D018 = %xxxx000x -> charmem is at $0000
  //$D018 = %xxxx001x -> charmem is at $0800
  //$D018 = %xxxx010x -> charmem is at $1000
  //$D018 = %xxxx011x -> charmem is at $1800
  //$D018 = %xxxx100x -> charmem is at $2000
  //$D018 = %xxxx101x -> charmem is at $2800
  //$D018 = %xxxx110x -> charmem is at $3000
  //$D018 = %xxxx111x -> charmem is at $3800
  lda VIC.MEMORY_SETUP  //get the current value
  and #240 //dec 240 is 11110000 bin  //And it to keep high bits
  ora #12  //dec 12 is 1100 bin       //or it with 12 to set it to $3000
  sta VIC.MEMORY_SETUP // store the value back 
  rts


text1:
  .text " are you keeping up with the commodore?!"   //make sure to alway use lower case here.
  .byte 00

gradientOffset:
  .byte 00

gradientColor:
  .byte $07, $07, $0f, $0a, $0c, $04, $0b, $06, $06, $04, $0c, $0a, $0f, $0b

*=$3000                     //load charset in $3000
#import "charset1.asm"     // load the charset_1.asm into this project, 
                            //this charset is created using https://petscii.krissz.hu/ editor. 
                            //Then exported to assembly and made to work with kickassembler