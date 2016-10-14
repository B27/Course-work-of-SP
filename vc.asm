data segment
	VIDEO_BUF dw 2000 DUP(?)
	DIRECT dw 0 ; направление перемещения
	EXIT db 0 ; признак завершения программы (не 0)
	MOV_SCR db 0 ; признак сдвига таблицы (если не 0, то сдвинуть)
	DRAW db 0 ; признак перерисовки таблицы (не 0)
	ATRIBUT1 db 14 ; атрибут символа (жёлтый)
	ATRIBUT2 db 10 ; атрибут символа (зелёный)
	OLD_CS dw ? ; адрес сегмента старого вектора 1Сh
	OLD_IP dw ? ; адрес смещения старого вектора 1Сh
data ends
code segment
assume cs:code, ds:data
; Подпрограмма обработки прерывания 1Сh
NEW_1C proc far
		push ax ; сохранить все регистры
		push bx
		push cx
		push dx
		push ds
		push es
		mov ax, DATA ; установить ds на сегмент данных
		mov ds, ax ; основной программы
		mov ax, 40h ; установить es на
		mov es, ax ; сегмент данных bios
		mov ax, es:[1ch]
		mov bx, es:[1ah]
		cmp bx , ax
		jne m5
		jmp back
m5: 	mov al, es:[bx] ;  чтение символа
		mov es:[1ch], bx
		
		cmp al,33h   	; если нажата
		jnz m1			; клавиша 3
		inc DRAW	; то создать новую таблицу
		jmp back
		
m1:		cmp al, 30h
		jnz m6
		mov EXIT, 1
		jmp back
		
m6: 	cmp al, 31h ;  клавиша '1'
		jz m2
		cmp al, 32h ;   клавиша '2'
		jz m3 
		mov DRAW,al ; код любой случайной клавиши в DRAW, для создания таблицы
		jmp back
m3:		cmp DIRECT,79 ; для того, чтобы символы не уходили за экран 
		jg back
		inc DIRECT
		inc MOV_SCR
		jmp back
		
m2: 	cmp DIRECT,-79 ; для того, чтобы символы не уходили за экран
		jl back
		dec DIRECT
		inc MOV_SCR
		
back: 	pop es
		pop ds
		pop dx
		pop cx
		pop bx
		pop ax
		iret
NEW_1C endp

; Подпрограмма очистки экрана
CLS proc near
		push cx
		push ax
		push si
		xor si, si
		mov ah, 7
		mov al, ' '
		mov cx, 2000
CL1: 	mov es:[si], ax
		inc si
		inc si
		loop CL1
		pop si
		pop ax
		pop cx
		ret
CLS endp

; Подпрограмма вывода  таблицы, со смещением
OUT_SYMBOL proc near
		push ax
		push bx
		push cx
		push si
		xor si,si
		cmp DIRECT,-80 ; для того, чтобы символы не уходили за экран 
		jnz cmp1
		jmp vr4
cmp1:	cmp DIRECT,80 ; для того, чтобы символы не уходили за экран
		jnz cmp2
		jmp vr5
cmp2:	cmp DIRECT,0
		jl vr2
		jz vr3
			
		mov dx,25
row25:		
		mov cx,DIRECT
		mov ah, 7
		mov al, ' '
bo_s:	mov es:[si],ax
		inc si
		inc si
		loop bo_s

		
		mov cx, 80
		sub cx, DIRECT
		mov ax, DIRECT
		shl ax,1
		mov bx,si
		sub bx,ax
o_s:	mov ax, VIDEO_BUF[bx]
		mov es:[si], ax
		inc si
		inc si
		inc bx
		inc bx
		loop o_s
		
		dec dx
		jnz row25
		jmp bck

	
vr2:	
		push DIRECT	
		neg DIRECT
		mov dx,25
row25_2:		
		mov cx, 80
		sub cx, DIRECT
		mov ax, DIRECT
		shl ax,1
		mov bx,si
		add bx,ax
o_s2:	mov ax, VIDEO_BUF[bx]
		mov es:[si], ax
		inc si
		inc si
		inc bx
		inc bx
		loop o_s2
		
		mov cx,DIRECT
		mov ah, 7
		mov al, ' '
bo_s2:	mov es:[si],ax
		inc si
		inc si
		loop bo_s2
		
		dec dx
		jnz row25_2
		pop DIRECT
		jmp bck		
		
vr3:	mov cx, 2000
o_s3: 	mov ax, VIDEO_BUF[si]
		mov es:[si], ax
		inc si
		inc si
		loop o_s3	
		jmp bck
		
vr4:	
		mov cx,25
		mov ah, 7
		mov al, ' '
o_s4:	mov es:[si],ax
		add si, 80*2
		loop o_s4
		jmp bck
		
vr5:	
		mov cx,25
		mov si, 80*2-2
		mov ah, 7
		mov al, ' '
o_s5:	mov es:[si],ax
		add si,80*2
		loop o_s5
		
bck:	pop si
		pop cx
		pop bx
		pop ax
		ret
OUT_SYMBOL endp

NEW_TABLE proc near
		push cx
		push bx
		push ax
		push si
		mov bl, DRAW
		xor si, si ; заполнение буфера в ram случайными символами
		mov ah, 1
		mov al, 1
		mov cx, 2000
RND2: 	mov VIDEO_BUF[si], ax
		inc si
		inc si
		inc ah
		inc al
		cmp al,bl
		jl cont2
		mov ah, 1
		mov al, 1
cont2:	loop RND2
		call OUT_SYMBOL
		pop si
		pop ax
		pop bx
		pop cx
		ret
NEW_TABLE endp

; Основная программа
START: 	mov ax, DATA
		mov ds, ax
		
		mov ah, 02h  ; скрыть курсор
		mov dh,25
		int 10h    
		
		; чтение вектора прерывания
		mov ah, 35h
		mov al, 1Ch
		int 21h
		mov OLD_IP, bx
		mov OLD_CS, es
		; установка вектора прерывания
		push ds
		mov dx, offset NEW_1C
		mov ax, seg NEW_1C
		mov ds, ax
		mov ah, 25h
		mov al, 1Ch
		int 21h
		pop ds
		mov ax, 0B800h
		mov es, ax
		call CLS
		
		call NEW_TABLE
		xor si, si ; вывод созданной таблицы
		mov cx, 2000
RND1: 	mov ax, VIDEO_BUF[si]
		mov es:[si], ax
		inc si
		inc si
cont:	loop RND1
		
		
p1: 	cmp EXIT, 0
		jne quit
		cmp MOV_SCR, 0
		jz p2
		mov MOV_SCR,0
		call OUT_SYMBOL
p2:		cmp DRAW,0
		jz p1
		call NEW_TABLE
		mov DRAW,0
		jmp p1
quit: 	call CLS
		mov dx, OLD_IP
		mov ax, OLD_CS
		mov ds, ax
		mov ah, 25h
		mov al, 1Ch
		int 21h
		mov ax, 4c00h
		int 21h
CODE ends
end START