; LOTTO DRAWING PROGRAM

; by John L. Dalton
; st 871206-1522
; fn ??????-????
; v.10 (881106)

; CONSTANTS
WHEN            equ 3           ; timer for when to change direction
SPEED           equ 1000        ; the lower the #, the faster the output
HOLE1           equ 328         ; screen index for first hole
ScrSize         equ 80*25       ; number of screen elements
EOS             equ '$'         ; end of string marker
BS              equ 8           ; ascii backspace
SPC             equ 32          ; ascii space
TAB             equ 9           ; ascii tab character
CR              equ 13          ; ascii carriage return
LF              equ 10          ; ascii for line feed
REVERSE         equ 01110000b   ; reverse screen attribute
NORMAL          equ 00000111b   ; normal screen attribute
clock           equ 1Ah         ; clock interrupt
keybd           equ 16h         ; keyboard int
video           equ 10h         ; video int
DOSfunct        equ 21h         ; DOS function int
; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

STACK   segment stack           ; stack segment
        dw 128 dup (?)          ; allow 256 bytes for stack
STACK   ends

; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
DATA    segment
N       dw ?                    ; total number of balls to choose from
PICK    dw ?                    ; number of balls to pick

SEED    DW ?

; Random directions for use in RANDDIR
rnddir  db -1,1,-1,1,0,-1,1,-1,0,1,-1,1,1,0,-1,1,-1,1,-1,1,-1,0,1,-1,1,-1,0,1
        db -1,1,-1,-1,1,-1,1,-1,1,0,-1,1,-1,1,-1,1,-1,-1,1,-1,1,-1,1,-1,1

; Pointers to above list (rdirp = Random direction Pointer)
rdirp   dw 13

tables  dw rnddir               ; for use in RANDDIR proc
rptrs   dw rdirp

holeptr dw HOLE1                ; screen ptr for hole position (next=curr+20)
BeenPr  db 0                    ; has return been pressed? 0=no, 1=yes
                                ; (used when no ball is under hole)
picked  dw 0                    ; holds number of balls picked
ballx   db 51 dup (?)           ; X coord of each ball (holds 0..39)
bally   db 51 dup (?)           ; Y coord of each ball (holds 3..24)
dirx    db 51 dup (?)           ; X-direction (-1,0,1)
diry    db 51 dup (?)           ; Y-direction (-1,0,1)
timer   db 51 dup (?)           ; timer to change direction of ball
VAL10   db 10                   ; constant for number ten
VAL25   db 25                   ; constant for number twenty-five
VAL40   db 40                   ; constant for number forty
val46   db 46

head    db 'LOTTO Simulation by J.L.D.         Press [SPACE] to draw ball'
        db CR,LF,LF,EOS
HOLE    DB 3 DUP(205),185,'  ',204,3 DUP(205),EOS
;hole    db '---|  |---',EOS
asktot  db 'L O T T O',CR,LF
        db 'Number of balls to choose from: ',EOS
askpik  db '       Number of balls to draw: ',EOS
askbeg  db CR,'Press RETURN to begin',EOS
asktry  db CR,LF,LF,'Try again (Y/N)? ',EOS

DATA    ends
; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

CODE    segment

program proc far
        assume cs:code, ds:data, ss:stack;      , es:screen
        push ds                 ; for far return to DOS
        mov ax,0
        push ax
        mov ax,data             ; set up DS for data segment
        mov ds,ax

        ASSUME ES:NOTHING               ; SET ES AS SEG TO SCREEN MEM
        MOV CX,0B800H
        MOV AH,15
        INT 10H
        CMP AL,7
        JNE USECGA
        SUB CX,800H
USECGA: MOV ES,CX

        ; allow user to customize
repik1: call CLRSCR
        mov dx,offset asktot
        call pstrng
        call getdig

        mul VAL10
        mov cl,al
        call getdig
        add al,cl

        cmp al,10               ; error check (N must = 10..50)
        jb repik1
        cmp al,51
        jae repik1

        mov ah,0
        mov N,ax                ; total number of balls

        mov dx,offset askpik
        call pstrng
repick: mov al,BS
        call chrout

        call getdig
 
        cmp al,1                ; balls to pick must be 1..8
        jb repick
        cmp al,9
        je repick

        mov ah,0
        mov PICK,ax

MAIN:   call ScrSETUP           ; set up output screen

; put balls in initial location on screen
; and initialize direction and timer to chgdir

        call InitVars           ; initialize variables
        mov di,1                ; loop thru N balls
        mov cl,36               ; first of four ball columns

loopac: mov ch,3                ; 1st row (hay 13 of them)
loopdn:

Direc:  mov al,0                ; initial direction for each ball
        mov dirx[di],al         ;  is straight down.
        mov al,1
        mov diry[di],al
        mov al,15               ; give each ball time to sink
        mov timer[di],al        ; to bottom of screen (falling effect)

        mov ballx[di],cl        ; store initial locs.
        mov bally[di],ch

        mov bx,cx               ; CL=x, CH=y
        call DetPtr             ; convert to a screen loc.
        stc
        call ScrPlot            ; plot DIth ball on screen
        inc di                  ; get ready to do next ball
        cmp di,N
        ja Prelude              ; or, exit loop if we did all balls
        inc ch                  ; move to spot under current
        cmp ch,3+13             ; did we go past col bottom?
        jne loopdn              ; no, go down more
        inc cl                  ; yes, move over and
        jmp loopac              ;  start back at top

Prelude:                ; wait for user to hit space
        call getin
        cmp al,SPC
        jne Prelude

START:                  ; start of major program loop: ball movement
        mov di,N                ; move each ball N..1


MoveIt:
        cmp bally[di],0         ; if Y=0 then ball already picked
        je nextball             ; don't move it
        dec Timer[di]           ; see if time is up to change direction
        jne RglrMove            ; no, just do a regular move
        mov Timer[di],WHEN      ; yes, reset timer
        call ChgDir             ;      change ball's direction in mid-flight
RglrMove:
        call MoveBall           ; move Nth ball

nextball:
        dec di
        jne MoveIt              ; move next ball { (n-1)th }

        mov CX,SPEED            ; delay index
        call Delay

        call DrawBall           ; draw ball if user wants to
        mov ax,picked
        cmp ax,PICK         ; were all balls drawn?
        jne START               ; no, do more
Leave:

                ; first erase all other balls not picked
        mov di,N
drop:
                                ; note: maybe instead use DOS interrupt
        mov bh,bally[di]
        mov bl,ballx[di]
        cmp bh,0
        je ispickd
        call DetPtr
        clc
        call ScrPlot
ispickd:dec di
        jne drop

        mov cl,7
        mov ch,7
        mov ah,1
        int video               ; turn on cursor

        mov dx,offset asktry    ; ask user if want to play again
        call pstrng
        call getin
        and al,1011111b         ; convert to upper case if need be
        cmp al,'N'
        je Return
        jmp MAIN                ; play again!

Return: ret                     ; return to DOS

program endp                    ;end of main program

; ###################
; ### subroutines ###
; ###################

;---------------------
ScrSETUP proc near              ; set up heading of screen
                        ; send nothing
 
        call CLRSCR             ; clear the screen

        mov ah,1
        mov ch,20h
        int video               ; turn off cursor

        mov dx,offset head      ; program title
        call pstrng
        mov cx,PICK             ; number of balls to pick

makehole:
        mov dx,offset hole      ; make a hole for each ball to enter
        call pstrng
        loop makehole
        ret
ScrSETUP endp
;---------------------
CLRSCR  proc near               ; clears the screen and homes cursor
                        ; send nothing
                        ; AX thru DX affected

        mov cx,0                ; top left
        mov dl,79               ; bot right
        mov dh,24
        mov al,0                ; clear whole screen
        mov bh,7                ; standard attribute
        mov ah,6                ; (scroll up)
        int video

; home cursor
        mov ah,15               ; prepare to read video state
        int video               ; BH = current active display page
        mov ah,2                ; prepare to set cursor pos.
        mov dx,0                ; position (0,0)
        int video               ; set cursor to row 0 col 0
        ret
CLRSCR  endp
;-----------------------
DetPtr  proc near               ; DETermine screen Pointer
                        ; send BL = X (0-39), BH = Y (0-24)
                        ; returns BX = screen pointer (0..3996)
                        ; AX affected
                        ; Formula:  ptr := 160*y + 4*x

        push cx                 ; preserve CX
        mov al,4
        mul bl
        mov cx,ax               ; CX = x*4
        mov al,160
        mul bh                  ; AX = y*160
        add ax,cx               ; AX = 160*y + 4*x
        mov bx,ax               ; set BX = screen ptr
        pop cx
        ret
DetPtr  endp
;-----------------------
ScrPlot proc near               ; plot with ball or erase
                        ; send CF=0 to clear the screen pos.
                        ;      CF=1 to put a ball at the screen pos.
                        ; send BX = screen pointer (0..3996)
                        ; send DI = which ball (1..N)
                        ; AX affected
                        ; outputs ball at correct screen position
                        ; note: ball will always take up two spots

        push dx                 ; preserve DX
        mov dl,NORMAL           ; assume ERASE wanted
        mov ax,2020h            ; AL=32,AH=32
        jnc PlotIt              ; assumption TRUE
        mov ax,di               ; ball's number (1-N)
        div VAL10               ; AL=tens digit, AH=ones digit
        mov dl,REVERSE          ; use reverse on balls
        add al,'0'              ; convert to screen code
        add ah,'0'              ; convert ones digit to screen code
        
PlotIt: mov es:[bx+1],dl        ; highlight tens digit
        mov es:[bx+3],dl        ; highlight ones digit
        mov es:[bx],al          ; tens digit comes first
        mov es:[bx+2],ah        ; put ones digit on screen after tens digit
        pop dx
        ret
ScrPlot endp
;-----------------------
MoveBall proc near              ; moves nth ball and adjusts direction if
                                ; ball hits another ball or screen borders
                        ; send DI = which ball (1..N)

        mov cl,dirx[di]         ; x-direction
        mov ch,diry[di]         ; y-direction
        add cl,ballx[di]        ; get new x position
        add ch,bally[di]        ; get new y position
Xchek:  cmp cl,-1               ; see if went off left edge of screen
        je Xoutb                ; yes, X is out of bounds
        cmp cl,40               ; see if went off right edge
        jne Ychek               ; no, X is ok--check Y
Xoutb:  neg dirx[di]            ; reverse X direction(-1 to 1, 1 to -1, 0 to 0)
        ret
Ychek:  cmp ch,(HOLE1-8)/160    ; check if reached top ej of screen
        je Youtb                ; yes, Y is out of bounds
        cmp ch,25               ; check if off bottom of screen
        jne ChekColl            ; no, therefore new X,Y is a valid screen pos.
Youtb:  neg diry[di]            ; yes, reverse Y direction
        ret

ChekColl:       ; check if ball collided with another ball.
                ; if it did, the new pos. already has a ball there

        mov bx,cx               ; put new XY in BX
        call DetPtr             ; convert to screen index ptr
        cmp byte ptr es:[bx+1],REVERSE   ; check if ball there
        jne nocoll              ; no, movement is ok
        neg dirx[di]            ; yes, reverse its direction
        neg diry[di]            ; reverse both x and y
        ret
nocoll:
        stc                     ; set CF to set new screen pos with ball
        call ScrPlot            ; (BX already points to screen pos)
        mov bl,ballx[di]        ; put old XY in BX
        mov bh,bally[di]
        mov ballx[di],cl        ; save new X position
        mov bally[di],ch        ; save new Y position
        call DetPtr             ; get screen index for old position
        clc                     ; clr CF to erase old screen pos.
        call ScrPlot            ; erase ball at old postion
        ret
MoveBall endp
;-----------------------
DrawBall proc near              ; draw ball into hole if user hits space

        mov bx,[holeptr]
        cmp BeenPr,1            ; if key has been pressed from before
        je sirch                ; and no ball found, try again
        mov ah,1                ; get keyboard status
        int keybd               ; ZF=0 --> no key
        jz no_draw              ; no key pressed-->no ball draw
        call getin              ; orse, get key read into AL
        push ax
        mov al,BS               ; output a backspace
        call chrout
        pop ax
        cmp al,SPC              ; did they type space?
        jne no_draw             ; no-->no ball draw
sirch:  add bx,160              ; drop down one line
        cmp byte ptr es:[bx+1],REVERSE   ; is there a ball there?
        je grab_it              ; yes, pull it up (draw)
        cmp bx,24*160           ; did we just check last line?
        jb sirch                ; no, search next line down
        mov BeenPr,1            ; yes, set flag for next time
no_draw:
        ret

grab_it:        ; first find out what ball we found (1..N)

        mov al,es:[bx]          ; get ascii value of tens digit
        and al,1111b            ; convert to decimal
        mul VAL10               ; multiply by 10
        mov ah,es:[bx+2]        ; get ones digit
        and ah,1111b            ; convert it to decimal
        add al,ah               ; get value into AL (1..N)
        mov ah,0                ; clear hi byte
        mov di,ax               ; put 1..N into DI
        mov bally[di],0         ; set Y=0 to denote already picked
rise:   clc                     ; erase ball at current location
        call ScrPlot
        sub bx,160              ; move up one line
        stc                     ; plot ball at this new line
        call ScrPlot
        mov cx,SPEED*3          ; delay so that ball rising is not too fast
        call DELAY
        cmp bx,holeptr          ; did ball reach hole yet?
        jne rise                ; no, rise until we do
        mov BeenPr,0            ; user has to type CR again to draw another
        inc Picked              ; increment balls picked
        add holeptr,20          ; increment hole pointer
        ret

DrawBall endp
;-----------------------
ChgDir  proc near               ; change a ball's direction

; two cases...
;                          /      |         /                | /
; if []->  then one of:  [] ->    |   if [ ]  then one of:  [ ] ->
;                          \      |

; case1:  either dX or dY = 0 -->  whichever is zero change to random dir

; case2:  dX,dY <> 0; add Random to dY. If abs(dY)=2 then dY=orig,dX=0


; send DI = which ball
                        ; AX,BX affected
                        ; DIRX[di],DIRY[di] affected

case1:  cmp dirx[di],0          ; see if dX is zero
        jne CifY                ; no, see if dY is zero
        mov ax,2                ; prepare to get random direction
        call RANDDIR            ; AL = -1, 0, or +1
        mov dirx[di],al         ; dX equals new random direction
        ret
CifY:   cmp diry[di],0          ; see if dY is zero
        jne case2               ; no, check other case
        mov ax,2                ; get rnd dir for Y
        call RANDDIR
        mov diry[di],al
        ret
case2:  mov bl,diry[di]         ; put original dY in BL
        mov ax,2
        call RANDDIR            ; put a random direction in AL
        add al,bl               ; AL = current dY + random dir
        mov diry[di],al         ; dY = dY + rnd(-1,0,1)
        and al,11b              ; check if AL = +-2
        cmp al,2
        jne exitCD              ; no, new direction is ok
        mov diry[di],bl         ; yes, dY = orig
        mov dirx[di],0          ;      dX = 0
exitCD: ret
ChgDir  endp
;----------------------
RANDDIR proc near              ; puts random direction in AL (=-1,0,or1)
                               ; send nada
                               ; AX affected

        push di
        push si
        push bx
COMMENT !
PPP: MOV AX,SEED
MOV BX,25173
MUL BX
ADD AX,13849
MOV SEED,AX
AND AL,3
JE PPP
SUB AL,2
!
        mov si,0               ; see version 6 for doc.
        mov bx,tables[si]      ; this routine is refined from the case
                               ; of three diff rand vars. It could and
                               ; should be reduced/revised (jld)
                               ; maybe not (jld)
        mov di,rptrs[si]
        mov ax,[di]
        inc word ptr [di]
        cmp ax,53
        jne nover
        mov word ptr [di],0
nover:  mov si,ax
        xlat byte ptr tables[si]
        pop bx
        pop si
        pop di
        ret
RANDDIR endp
;-------------
InitVars proc near     ; initializes  RDIRP=0;
                        ; beenpr,picked to 0 & holeptr to HOLE1
                        ; AX,BX,DX destroyed

        mov ah,0
        int 1ah
MOV SEED,DX
        and dx,31
        mov rdirp,dx
        mov holeptr,HOLE1         ; screen pointer for 1st hole
        mov BeenPr,0
        mov picked,0
        ret                     ; thats all there is to it
InitVars endp
;------------------------
ROUTINES proc near      ; miscellaneous subroutines

chrout:                 ; output char in al (dl,ax affected)
        mov dl,al               ; put char in DL
        mov ah,02               ; code for output DL
        int 21h                 ; print char
        ret
;      -----
pstrng:                 ; print string send DX point to string
        mov ah,9
        int DOSfunct
        ret
;      -----
getin:                  ; reads char from kb, puts it in al
                                ; note: (waits for user to type one)
        mov ah,1                ; code for input into AL
        int DOSfunct            ; wait for and read a character
        ret
;      -----
getdig:
        call getin
        cmp al,'0'
        jb getdig
        cmp al,'9'
        ja getdig
        sub al,'0'
        ret
;      -----
ShiftStat:              ; checks if right SHIFT pressed
                                ; returns ZF=0 no, ZF=1 yes
                                ; AL = bits of status
        mov ah,2
        int keybd
        cmp al,11111110b        ; was right shift touched
        ret
;      -----
Delay:                  ; delay loop
                                ; send CX = amount of delay
                                ; CX affected

Dloop:  loop Dloop              ; loop until CX = 0
        ret
;      -----
ROUTINES endp


CODE    ends                    ;end of code segment
        end                     ;end of program









