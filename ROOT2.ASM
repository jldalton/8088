; INTEGER SQUARE ROOT TAKER

; by John L. Dalton
; st 871122-1259-U
; fn 871206-1511
; v 6 (trying to maximize speed + output to DISK)


nil     equ 255
BuffSize equ 25              ; program stores digits in buffer 
                             ;  then outputs buffer to disk
MAXDIGS equ BuffSize*600     ; maximum number of digits to calculate (15000)
                             ;   (must be multiple of Buffsize)
EOS     equ 0   ; end of string marker

DATA    segment                 
b1      dw 0    ; backup for Bptr
TRY     db 9    ; nth digit to try 
NL      db 5    ; square root of 05
NH      db 0
Carry   db 0
Borrow  db 0
handle  dw 0            ; for disk output file purposes

B       db MAXDIGS+1 dup (0)          
D       db MAXDIGS+3 dup (0)
T       db MAXDIGS+3 dup (0)
D1      db MAXDIGS+3 dup (0)
intro   db 'INTEGER SQUARE ROOT TAKER (15000 digits)',10,10,13
        db 'Enter integer (00-99):??',8,8,EOS
head    db 10,13,'Calculating root (û = 25 digits) (Type ! to stop)...'
        db 10,13,EOS
fname   db 'S05.DIG',EOS
buffer  db BuffSize dup (0)
buffpt  dw 0
DATA    ends

STACK   segment stack           ;stack segment
        dw 128 dup (?)          ;give the stack 128 words
STACK   ends

CODE    segment               
program proc far                ;for proper return to DOS
        assume cs:code,ds:data,ss:stack

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

        mov si,offset intro
        call pmes               ; print intro message
        call getdig
        mov NH,al               ; get hibite
        call getdig
        mov NL,al               ; get lobite
        mov si,offset head
        call pmes

;*******
; disk setup : open output file

        mov al,NH
        add al,'0'
        mov fname[1],al         ; customize filename ex. S05.DIG for sqrt of 5
        mov al,NL
        add al,'0'
        mov fname[2],al

        mov dx,offset fname  ; point ds:dx to file name
        mov ah,3Ch              ; create file for int 21h
        mov cx,0
        int 21h
        mov handle,ax           ; store handle 

        mov cx,1
        mov buffer,' '           ; put space first byte on disk
        call wrbuffer
        mov buffpt,0            ; start at beginning of buffer


;*******


MAIN:   
        mov di,0                ; reset Dptr to 0
loop1:  inc di                  ; point Dptr to loc of first nil
        cmp D[di],nil         
        jne loop1

SHIFTD: mov al,D[di]            ; D[Dptr+2] = D[Dptr]
        mov D+2[di],al          ; shift D array two spaces 
        dec di
        jne SHIFTD

;get ready to bring down N
        mov al,NL               ; ones place of integer
        mov D[1],al             ; put in D array spot 1
        mov NL,0                ; after read once, clear it
        mov al,NH               ; tens place of integer
        mov D[2],al             ; put in D array spot 2
        mov NH,0                ; after read once, clear it

;prelude to loop
        mov [TRY],9             ; assume nth digit is 9, then work downwards

; save D array into D1
        mov di,0
Sloop:  inc di
        mov al,D[di]
        mov D1[di],al
        cmp al,nil
        jne Sloop

        mov b1,bp               ; backup Bptr

TRYDIG: 
        mov Carry,0             ; set carry to zero
        mov si,0                ; point to start of T array
        inc bp
        mov al,[TRY]
        mov B[bp],al            ; temporarily put digit in B array

MLOOP:  mov al,B[bp]            ; get ready to multiply B[Bptr] * TRY
        mov bl,[TRY]

;-------------
; mult    *****   multiply al*bl --> T1T2 = [dldh]
        mul bl                  ; product is in al
        mov bl,10               ; get ready to divide al by 10
        mov ah,0                ; set ax = 00al
        div bl                  ; al=quot.  ah=rmdr.
        mov dx,ax               ; set dldh = T1T2
;    result is T1T2 (T1=tens,T2=ones) = [dldh]
;-------------

        mov al,dh             ; get ready to add T2 + Carry
        mov bl,Carry

;-------------
; sum     *****      add al+bl --> S1S2  = [clch]
        add al,bl               ; sum is in al
        mov bl,10
        mov ah,0
        div bl
        mov cx,ax
;     result is S1S2 (S1=tens,S2=ones) = [clch]
;-------------


        mov T[si],ch            ; T[Tptr]=S2

        inc si                  ; Tptr = Tptr + 1
        dec bp                  ; Bptr = Bptr - 1
        mov al,dl             ; get ready to add T1 + S1
        mov bl,cl

;-------------
; sum     *****    add al+bl --> S1S2  = [clch]
        add al,bl               ; sum is in al
        mov bl,10
        mov ah,0
        div bl
        mov cx,ax
;     *****      result is S1S2 = [clch]
;-------------

        mov Carry,ch            ; Carry=S2
        cmp B[bp],nil           ; repeat MLOOP until B[Bptr]=nil
        jne MLOOP

        mov bp,b1               ; get original Bptr back
        mov al,Carry
        mov T[si],al            ; T[Tptr]=Carry

; subtract Darray - Tarray
        mov Borrow,0            ; Borrow = 0
        mov di,1                ; Dptr = 1 (note: 0th element of D not used)
        mov si,0                ; Tptr = 0

while:  cmp D[di],nil           ; while D[Dptr]<>nil do
        je wend
        mov al,D[di]            ; get ready to subtract D[Dptr]-T[Tptr]
        mov bl,T[si]
        call subtr              ; stored in al, Borrow affected
        mov D[di],al            ; D[Dptr] = difference
        inc di                  ; Dptr = Dptr + 1
        inc si                  ; Tptr = Tptr + 1
        jmp while
wend:   
        cmp Borrow,1            ; if Borrow=1 then TRY was wrong
        jne GOTIT
        dec TRY                 ; TRY = TRY - 1

;-------------
;    retrieve D array
        mov di,0
Rloop:  inc di
        mov al,D1[di]
        mov D[di],al
        cmp al,nil
        jne Rloop
;-------------
        jmp TRYDIG              ; try next digit

GOTIT:  
        dec di                  ; kludge (871130-2058) to reduce 
                                ; execution time! (eliminates excess zeros)
                                ; only works for small arguments

        mov D[di],nil
        mov al,[TRY]            ; get ready to multiply TRY*2 --> T1T2
        mov bl,2

;-------------
; mult    multiply al*bl --> T1T2 = [dldh]
        mul bl                  ; product is in al
        mov bl,10               ; get ready to divide al by 10
        mov ah,0                ; set ax = 00al
        div bl                  ; al=quot.  ah=rmdr.
        mov dx,ax               ; set dldh = T1T2
;-------------

        add B[bp],dl            ; B[Bptr] = B[Bptr] + T1
        inc bp                  ; Bptr = Bptr + 1
        mov B[bp],dh            ; B[Bptr] = T2

        mov al,[TRY]
        add al,'0'              ; convert to ascii
        mov si,buffpt
        mov buffer[si],al       ; put digit in buffer
        inc buffpt              ; increment buffer pointer
        mov cx,buffpt           ; store buffer pointer

ckbuff: cmp cx,BuffSize         ; is buffer full? 
        jne nextdig             ; no, do more
        call wrbuffer           ; write CX bytes of buffer to disk
        mov al,251              ; output sqrt symbol to denote 100 bytes
        call chrout
        mov buffpt,0            ; reset buffer pointer

; check for maxdigs
        cmp bp,MAXDIGS          ; did we find enuf digs yet?
        jae EXIT                ; yes, were done!

; check for kb=!
        mov ah,1                ; check if keybd is empty
        int 16h
        jz nextdig               ; user didnt type anything
        call getin              ; read what user typed
        cmp al,'!'              ; did user type '!'?
        je EXIT                 ; yes, we're done.

nextdig:jmp MAIN

EXIT:   
; ****** close disk file
        mov bx,handle
        mov ah,3Eh
        int 21h
;******
        ret                     ;return to DOS    (EXIT PROGRAM HERE)


program endp                    ;end of procedure declaration

; ### subroutines ###
;---------------------
subtr   proc near               ; subtract al-bl --> al (Borrow affected)
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
outdig  proc near               ; output a single digit stored in al
        add al,'0'              ; convert digit to ASCII
        call chrout
        ret
outdig  endp
;---------------------
pmes    proc near               ; print message pointed to by ds:si
charac: lodsb                   ; get byte of string
        cmp al,EOS              ; end of string?
        je donemes
        call chrout             ; output char
        jmp charac
donemes:ret
pmes    endp
;---------------------
chrout  proc near               ; output char in al (dl,ax affected)
        mov dl,al
        mov ah,02               ; code for output
        int 21h                 ; print char
        ret
chrout  endp
;---------------------
getin   proc near               ; reads char from kb, puts in al
        mov ah,1
        int 21h
        ret
getin   endp
;-----------------------
getdig  proc near               ; puts digit in al
bad:    call getin
        cmp al,'0'
        jb bad
        cmp al,'9'
        ja bad
        sub al,'0'              ; convert to 0-9 dec
        ret
getdig  endp
;--------------
wrbuffer  proc near

;***** disk write               ; send CX = # of bytes to write
        mov dx,offset buffer           ; output nth digit of square root
        mov bx,Handle
        mov ah,40h           ; write data to file
        int 21h           
        ret
;*****
wrbuffer  endp


CODE    ends                    ;end of segment code declaration
        end                     ;end of program











