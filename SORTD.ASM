; Screen sorting package by john dalton 881101+

; note: updated 1/25/90 to slow down the faster sorts

              ; CONSTANTS


off             equ 0
on              equ 1
EOS             equ '$'         ; end of string marker
space           equ ' '         ; space
beep            equ 7           ; beep character
lf              equ 10          ; line feed
cr              equ 13          ; carriage return
keybd           equ 16h         ; keyboard interrupt
video           equ 10h         ; video interrupt
DOSfunct        equ 21h         ; DOS function interrupt
printer         equ 17h         ; printer I/O interrupt
clock           equ 1Ah         ; clock interrupt

clrscr macro
        call clear_scr
        endm
;----
wait_key macro
        local weight
weight: call keypressed
        jz weight
        endm
;------

Print MACRO string
        lea dx,string
        mov ah,9
        int Dosfunct
        ENDM
;------
Set_Cursor MACRO row,col,state          ; affects AH,BH,CX,DX
        IFNB <state>            ; positions cursor and optionally turns it
           IFE state-ON         ; on or off
              mov cx,0607h         ; cursor on for color
              mov ax,es
              cmp ax,0B800h        ; make sure using color
              je $+5
              mov cx,0C0Dh         ; cursor on for mono
           ELSE
              mov cx,2020h         ; cursor off
           ENDIF
           mov ah,1
           int video               ; set cursor type
        ENDIF
        mov dh,row
        mov dl,col
        mov bh,0
        mov ah,2
        int video               ; set cursor position
        ENDM

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

STACK   segment stack           ; stack segment
        dw 128 dup (?)          ; allow 256 bytes for stack
STACK   ends

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

DATA    segment
        tmpb label byte
        tmpw dw 0
        seed dw 0

        qs dw 40 dup(?) ; stack for quicksort

        menu db 80 dup (196) ; line character
             db 'Screen Sorter by John Dalton       F1 = Ripple sort',cr,lf
             db 'SPACE = Scramble Screen            F2 = Bubble sort'
             db '       F4 = Shell sort',cr,lf
             db 'Q = Quit    F,char = Fill          F3 = Heap Sort'
             db '         F5 = Quicksort',eos

        sorting db 'SORTING',eos
        nosorting  db '       ',eos
        routes dw scramble,fill,ripple,bubble,heap,shell,quick

DATA    ends
; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

CODE    segment

program proc far
        assume cs:code, ds:data, ss:stack
prg:    push ds                 ; allow return to DOS
        mov ax,0
        push ax

        mov ax,data             ; set up DS for data segment
        mov ds,ax


start:  call init
        call scramble
mloop:  set_cursor 22,60
        print nosorting
        wait_key                ; scan code for SPACE = 57, F1=59,F2=60 ...
        cmp ah,16               ; q,Q scan
        je quit
        cmp ah,33               ; f,F scan
        jne conv
        mov ah,58               ; make FILL command be rout #1
conv:   sub ah,57               ; convert SPACE to 0 F1 to 2, F2 to 3 ...
        cmp ah,6                ; make sure they typed a defined f-key
        ja mloop                ; F5 is last one used
        mov bl,ah
        mov bh,0
        shl bl,1                ; convert to word ptr
                                ; BX = offset to Routes for correct routine
        cmp ah,2                ; If sort command pressed, print "sorting"
        jb brnch
        push bx
        set_cursor 22,60
        print sorting
        pop bx
brnch:  call routes[bx]         ; do correct sorting rout. or other rout
        jmp mloop

quit:   clrscr
        set_cursor 3,0,on
        ret
program endp
;-----------
;       S U B R O U T I N E S
;
init proc near
        set_cursor 0,0,off      ; home the cursor, shut it off
        clrscr

; determine which screen to use
        assume es:nothing
        mov cx,0B800h           ; assume color screen
        mov ah,15               ; get video mode
        int 10h
        cmp al,7                ; mono mode?
        jne usecga
        sub cx,800h
usecga: mov es,cx

; init vars
        mov ah,0                ; read timer (DX = low word)
        int clock
        mov seed,dx             ; set random seed value to clock
        set_cursor 21,0
        print menu

        mov di,3640             ; set 7 bytes on screen(22,60)to flash
        mov cx,7                ; 'SORTING' message when sorting
        mov ah,10000100b        ; (red flash)
        mov al,32
        rep stosw

        ret
init endp
;--------
scramble proc near
        mov si,4000-(4*160)     ; all but last three lines
scr2:   call random
        mov es:[si-2],al
        sub si,2
        jnz scr2
        ret
scramble endp
;------------
fill proc near
        mov si,4000-(4*160)
        wait_key                ; get char to fill with in AL
fll2:   mov es:[si-2],al
        sub si,2
        jnz fll2
        ret
fill endp
;--------
keypressed proc near    ; returns Z if no key, NZ if key pressed
        mov ah,1        ; keypressed?
        int keybd
        jz out1         ; no, return with ZF=1
        pushf
        mov ah,0        ; yes, read it and return with ZF=0
        int keybd
        popf
out1:   ret
keypressed endp
;--------------
clear_scr proc near             ; clear screen (affects AX,BH,CX,DX)
        mov cx,0000             ; 0,0 = top left corner
        mov dx,184Fh            ; 18h,4Fh = 24,79 = bot right corner
        mov ax,0600h            ; set clear screen function
        mov bh,03h              ; cyan characters
        int video
        ret
clear_scr endp
;-------------
random proc near        ; returns AX = random
        push bx
pick:   mov ax,seed
        mov bx,25173
        mul bx
        add ax,13849
        mov seed,ax
        pop bx
        ret
random endp
;----------
ripple proc near

forf:   mov si,0000h            ; for si = 0 to N-1
fors:   mov di,si               ;    for di = si + 1 to N
nexts:  add di,2
        cmp di,4000-(4*160)
        jae nextf
        mov al,es:[si]          ;        if screen[si] > screen[di] then
        mov bl,es:[di]          ;            swap
        cmp al,bl
        jbe nexts               ;    next di
; swap
        mov es:[si],bl
        mov es:[di],al
        jmp nexts
nextf:  add si,2
        cmp si,(4000-(4*160))-2
        jb fors                 ; next si
        ret
ripple endp
;----------
bubble proc near
        mov si,2                ; for i = 2 to N do
nexti:  mov di,(4000-(4*160))-2 ;   for j = N downto i do
chk1:   mov al,es:[di-2]        ;        if es[j-1] > es[j] then
        mov bl,es:[di]          ;            swap
        cmp al,bl
        jbe nextj               ;
; swap
        mov es:[di-2],bl
        mov es:[di],al
nextj:  sub di,2                ;   next j
        cmp di,si
        jae chk1
        add si,2                ; next i
        cmp si,(4000-(4*160))-2
        jb nexti
        ret
bubble endp
;----------
heap proc near          ; heap sort (uses sift procedure)
        ; assume L=si, R=di

        N equ 4000-(4*160)
        mov si,N                ;
        mov di,si               ; R = N           (R=3358)
        sub di,2
        shr si,1                ; L = N div 2 + 1 (L=1680)
whileL1:cmp si,0                ; while L>1 do
        jbe whileR1
        sub si,2                ;    L=L-1
        call sift               ;    Sift
        jmp whileL1             ; end while
whileR1:cmp di,0                ; while R>1 do
        jbe dunheap
      mov dx,1535
dd1:  dec dx
      jnz dd1
        mov ah,es:[0]           ;    x=es[1]
        mov al,es:[di]          ;    es[1]=es[R]
        mov es:[0],al
        mov es:[di],ah          ;    es[R]=x
        sub di,2                ;    R=R-1
        call sift               ;    sift
        jmp whileR1             ; end while
dunheap:ret
;----
sift:   ; assume i=si,j=di,x=al,L=CX, R=BX
        mov cx,si               ; i=L
        mov bx,di               ; {save original di,si}
        mov di,si               ; j=2*i
        shl di,1
        mov al,es:[si]          ; x=es[i]
whilejr:cmp di,bx               ; while J<=R do
        ja lab13
        je lab2                 ;    if J<R then
           mov ah,es:[di]
           cmp ah,es:[di+2]     ;       if es[j]<es[j+1] then
           jae lab2
              add di,2          ;          j=j+1
lab2:   cmp al,es:[di]          ;    if x>=es[j] then 13
        jae lab13
        mov ah,es:[di]          ;    es[i] = es[j]
        mov es:[si],ah
        mov si,di               ;    i=j
        shl di,1                ;    j=2*i
        jmp whilejr             ; end while
lab13:  mov es:[si],al          ; es[i] = x
        mov si,cx                ; return original values of si,di
        mov di,bx
        ret
heap endp
;--------
shell proc near
        mov bp,(4000-(4*160))-2 ; (bp=N)
        mov bx,bp               ; G=N
rep1:   shr bx,1                ; G=G div 2
        and bx,0FFFEh           ; (make sure G stays even)
        je exit1                ; if G<1 then exit
while1: or dl,1                 ; done=true
        mov si,0                ; i=1
        mov cx,bp
        sub cx,bx               ; A=N-G
for1:   mov di,si
        add di,bx               ; j=i+G
        mov al,es:[si]
        cmp al,es:[di]          ; if E[i] > E[j]
        jbe next1
      mov ah,255
dd2:  dec ah
      jnz dd2
        mov ah,es:[di]          ; then swap, and
        mov es:[si],ah
        mov es:[di],al
        xor dl,dl               ; and set done=false
next1:  add si,2                ; i=i+1
        cmp si,cx               ; if i<=A
        jbe for1                 ; then goto FOR1
        and dl,1                ; if done=false
        jz while1               ; then goto WHILE1
        jmp rep1                ; goto REP1
exit1:  ret
shell endp
;---------
quick proc near                 ; dx=L, cx=F, si=I, di=J, al=D, bp=P
        mov ax,0
        push ax                 ; s(1)=1
        mov ax,(4000-(4*160))-2
        push ax                 ; s(2)=N
        mov bp,2                ; p=2
lab30:  pop dx                  ; L=s(p)
        sub bp,2                ; p=p-1:p=p-1
        pop cx                  ; f=s(p)
        mov si,cx               ; i=f
lab40:  mov di,dx               ; j=L
        mov bx,cx
        add bx,dx               ; bx=f+L
        shr bx,1                ;   =(f+L)/2
        and bx,0FFFEh           ; (make sure points to even location)
        mov al,es:[bx]          ; d=E[(f+L)/2]
lab50:  cmp es:[si],al          ; if E[i] < d
        jae lab60
        add si,2                ; then i=i+1
        jmp lab50               ; goto 50
lab60:  cmp es:[di],al          ; if E[j] > d
        jbe lab70
        sub di,2                ; then j=j-1
        jmp lab60               ; goto 60
lab70:  cmp si,di               ; if i<=j
        ja lab90
      mov bx,1535
dd3:  dec bx
      jnz dd3
        mov bl,es:[si]          ; then T=e[i]
        mov bh,es:[di]          ;      e[i]=e[j]
        mov es:[si],bh
        mov es:[di],bl          ;      e[j]=T
        add si,2                ;      i=i+1
        sub di,2                ;      j=j-1
        cmp si,di               ;      if i<=j then 50
        jbe lab50
lab90:  cmp cx,di               ; if f<j
        jae lab95
        push cx                 ; then p=p+1; s(p)=F
        push di                 ;      p=p+1; s(p)=J
        add bp,2
lab95:  mov cx,si               ; f=i
        cmp cx,dx               ; if f<L then 40
        jb lab40
        cmp bp,0                ; ifP<>0 then 30
        jne lab30
        ret
quick endp
;---------

CODE    ends                    ;end of code segment
        end prg                 ;end of program










