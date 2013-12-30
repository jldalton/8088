; INTEGER SQUARE ROOT TAKER
;     Will find the square root of an integer from 00 to 99
;     up to MAXDIGS digits.

;     INPUT:  number to take root of
;     OUTPUT:  the square root of the number

; by John L. Dalton 
; st 871122-1259
; fn 871206-1417
; v.4 working version, documented, but not speed maximized.  Output to screen

; CONSTANTS
nil     equ 255           ; null value denotes end of array
MAXDIGS equ 5000          ; maximum number of digits to calculate
EOS     equ 0             ; end of string marker


DATA    segment                 

intro   db 'INTEGER SQUARE ROOT TAKER',10,10,13
        db 'Enter integer (00-99):??',8,8,EOS
head    db 10,13,'The square root is...',10,13,EOS
b1      dw 0    ; backup for Bptr
TRY     db 9    ; nth digit to try (start with 9 then work down to 0)
NL      db 5    ; number to take root of NHNL ex. 05
NH      db 0
Carry   db 0    ; used in multiplying/adding
Borrow  db 0    ; used in subtracting
Dpoint  db '.'  ; decimal point for output

B       db MAXDIGS+1 dup (0)              ; B array = root times 2
D       db (MAXDIGS+3)*2 dup (0)          ; D array = D - T
T       db (MAXDIGS+3)*2 dup (0)          ; T array = B*TRY
D1      db (MAXDIGS+3)*2 dup (0)          ; backup for D in case TRY is wrong

;Explanation of data structure...

;                          2  2  3  6     <-  root
;                        û05.00 00 00    <- D
;                 x0(2) =  4             <- T
;                          1 00          <- D array = subtraction
;                 x4(2) =    84          <- T array = product
;      B array {             16 00       <- D
;                x44(3) =    13 29       <- T
;                             2 71 00
;               x446(6) =     2 67 96
;                                3 04 etc
DATA    ends

STACK   segment stack           ;stack segment
        dw 128 dup (?)          ;allow 256 bytes for stack
STACK   ends

CODE    segment               
program proc far                ;for proper return to DOS
        assume cs:code, ds:data, ss:stack
        push ds                 ;for far return to DOS
        mov ax,0
        push ax
        mov ax,data             ;set up DS for data segment
        mov ds,ax


; INITIALIZE STARTING VALUES
        mov [B],nil             ; B[0] = nil
        mov [B+1],0             ; B[1] = 0
        mov bp,1                ; Bptr = 1
        mov [D+1],nil           ; D[1] = nil

                ;note: throughout this program...
                ;      Bptr == BP register
                ;      Dptr == DI
                ;      Tptr == SI

        mov si,offset intro     ; output intro message
        call pmes               
        call getdig             ; Have user enter in # to take root of
        mov NH,al               ; get tens digit
        call getdig
        mov NL,al               ; get ones digit
        mov si,offset head      ; output header 
        call pmes


MAIN:   ; start of main loop; program goes here after each digit found

        mov di,0                ; reset Dptr to 0
pointD: inc di                  ; point Dptr to loc of first nil
        cmp D[di],nil         
        jne pointD

SHIFTD: mov al,D[di]            ; D[Dptr+2] = D[Dptr]
        mov D+2[di],al          ; shift D array two spaces 
        dec di
        jne SHIFTD

;Multiply D array by 100 (at start of program, set D array to root argument)

        mov al,NL               ; ones place of integer
        mov D[1],al             ; put in D array spot 1
        mov NL,0                ; after read once, clear it
        mov al,NH               ; tens place of integer
        mov D[2],al             ; put in D array spot 2
        mov NH,0                ; after read once, clear it

;prelude to TRYDIG loop: init. TRY & backup important data in case TRY is wrong

        mov [TRY],9             ; assume nth digit is 9, then work downwards
        stc                     ; set carry to save D array
        call SRD                ; backup D array
        mov b1,bp               ; backup Bptr

TRYDIG: ; assume digit is correct.  do all calculations.  if D turns out to be
        ;  greater than T, then digit was wrong.  Orse, we found correct digit.

        mov Carry,0             ; set carry to zero
        mov si,0                ; point to start of T array
        inc bp
        mov al,[TRY]
        mov B[bp],al            ; temporarily put digit in B array

MLOOP:  ; multiplication loop;  T array := B array (with TRY as last digit)
;                                          times TRY

        mov al,B[bp]            ; get ready to multiply B[Bptr] * TRY
        mov bl,[TRY]            
        call mult               ; result is T1T2 (T1=tens,T2=ones) = [dhdl]
        mov al,dl               ; get ready to add T2 + Carry
        mov bl,Carry
        call sum                ; result is S1S2 (S1=tens,S2=ones) = [chcl]

        mov T[si],cl            ; T[Tptr]=S2

        inc si                  ; Tptr = Tptr + 1
        dec bp                  ; Bptr = Bptr - 1
        mov al,dh               ; get ready to add T1 + S1
        mov bl,ch
        call sum                ; result is S1S2 = [chcl]
        mov Carry,cl            ; Carry=S2
        cmp B[bp],nil           ; repeat MLOOP until B[Bptr]=nil
        jne MLOOP

;SUBTRACT D array - T array.  result stored in D array
        mov bp,b1               ; get original Bptr back
        mov al,Carry            ; T[Tptr]=Carry
        mov T[si],al            

        mov Borrow,0            ; start Borrow equal to zero
        mov di,1                ; Dptr = 1 (note: 0th element of D not used)
        mov si,0                ; Tptr = 0

while:  cmp D[di],nil           ; while D[Dptr]<>nil do
        je wend
        mov al,D[di]            ; get ready to subtract D[Dptr]-T[Tptr]
        mov bl,T[si]
        call subtr              ; AL = difference, Borrow used & affected
        mov D[di],al            ; D[Dptr] = difference
        inc di                  ; Dptr = Dptr + 1
        inc si                  ; Tptr = Tptr + 1
        jmp while

wend:   cmp Borrow,1            ; if Borrow=0 then we got it!
        jne GOTIT               
        dec TRY                 ; digit was wrong, 'try' next smaller digit
        clc                     ; clear carry to retrieve D array
        call SRD                ; restore D array to original contents
                                ; (ie, before we assumed TRY was right)
        jmp TRYDIG              ; try next digit. note: if no digits are 
                                ; correct, zero will always work

GOTIT:  ; we found the nth digit, output it and adjust arrays.

             dec di                  ; kludge (871130-2058) to reduce execution
             mov D[di],nil           ; time. (eliminates excess zeros in arrays)
                                     ; Note: this won't work for all numbers
                                     ;  remove 'DEC DI' if error occurrs

        mov al,[TRY]            ; get ready to multiply TRY*2 --> T1T2 
        mov bl,2
        call mult               ; result is T1T2 = [dhdl]
        add B[bp],dh            ; B[Bptr] = B[Bptr] + T1
        inc bp                  ; Bptr = Bptr + 1
        mov B[bp],dl            ; B[Bptr] = T2
        mov al,TRY              ; output nth digit of square root
        call outdig
        mov al,Dpoint           ; output decimal point or null
        cmp al,0
        je noDP
        call chrout
        mov Dpoint,0            ; only print one decimal pt per root

noDP:   cmp bp,MAXDIGS          ; check if printed enough digits
        jae EXIT                ; yes, stop
        jmp MAIN                ; no, do more

EXIT:   ret                     ;return to DOS

program endp                    ;end of main program

; ###################
; ### subroutines ###
; ###################

SRD     proc near     ; Save/Retrieve D 
                      ; send CF=1 to Save, CF=0 to Retrieve
                      ; uses D1 array to save

        pushf                   ; push carry flag onto stack
        mov di,0
SRloop: inc di
        popf                    ; look at carry, then save again
        pushf
        jnc Retr                ; if CF=0, then retrieve D ELSE...
                      ; Save 
        mov al,D[di]
        mov D1[di],al
        jmp SRchek
Retr:                 ; Retrieve D
        mov al,D1[di]
        mov D[di],al
SRchek: cmp al,nil    ; check if we saved/retrieved all bytes of array
        jne SRloop
        popf          ; stabilize stack
        ret
SRD     endp
;---------------------
mult    proc near               ; multiply al*bl  
                                ; returns product = DHDL (DH=tens digit,DL=ones

        mul bl                  ; ax := al*bl
        mov bl,10               ; get ready to divide al by 10
        mov ah,0                ; set AX = 00AL
        div bl                  ; divided AX/BL (AL=quot.  AH=rmdr.)
        mov dh,al               ; set DH equal to tens digit
        mov dl,ah               ; DL = ones digit
        ret
mult    endp
;---------------------
sum     proc near               ; add al+bl 
                                ; returns sum = CHCL (CH=tens, CL=ones dig.)

        add al,bl               ; al := al+bl
        mov bl,10               ; prepare to convert AL into tens & ones digits
        mov ah,0
        div bl                  ; AX/BL --> (AL=quot, AH=remdr)
        mov ch,al               ; ex. 23/10 --> (AL=2  AH=3)
        mov cl,ah
        ret
sum     endp
;---------------------
subtr   proc near               ; subtract al-bl --> al (Borrow affected)

;flowchart     (START)
;                 |
;             <Borrow>---(=1)---<al=0>-----(yes)-->----|
;                 |                |                   |
;                 |              (no)                [Borrow := 1]
;                (=0)              |                   |
;                 |           [Borrow := 0]          [al := 9]
;                 |                |                   |
;                 |           [al := al-1]             |
;                 |                |                   |
;                 |                |                   |
;       (y)---<bl > al>---------<------------------<----
;        |        |
;  [Borrow:=1]   (n)
;        |        |
;  [al:=al+10]-->[al:=al-bl]
;                     |
;                     |
;                   (END)


        cmp Borrow,0
        je norm1
        cmp al,0
        jne norm2
        mov Borrow,1
        mov al,9
        jmp norm1
norm2:  dec al
        mov Borrow,0
norm1:  cmp al,bl               ; if al>=bl then goto norm3
        jae norm3
        mov Borrow,1
        add al,10               ; al=al+10
norm3:  sub al,bl               ; al=al-bl
        ret
subtr   endp
;---------------------
outdig  proc near               ; output a one-digit number stored in al
        add al,'0'              ; convert digit to ASCII
        call chrout             ; output ascii digit
        ret
outdig  endp
;---------------------
pmes    proc near               ; Print MESsage pointed to by ds:si
charac: lodsb                   ; get byte of string
        cmp al,EOS              ; end of string?
        je donemes              ; yes, stop 
        call chrout             ; output char
        jmp charac
donemes:ret
pmes    endp
;---------------------
chrout  proc near               ; output char in al (dl,ax affected)
        mov dl,al               ; put char in DL
        mov ah,02               ; code for output DL
        int 21h                 ; print char
        ret
chrout  endp
;---------------------
getin   proc near               ; reads char from kb, puts it in al
                                ; note: (waits for user to type one)
        mov ah,1                ; code for input into AL
        int 21h                 ; wait for and read a character
        ret
getin   endp
;-----------------------
getdig  proc near               ; puts digit(0-9) into AL (AX affected)
bad:    call getin
        cmp al,'0'
        jb bad
        cmp al,'9'
        ja bad
        sub al,'0'              ; convert ascii to 0-9 decimal
        ret
getdig  endp
;----------------------
CODE    ends                    ;end of code segment 
        end                     ;end of program

