.model 	small
.stack 	100h
.386
.data
	var_filename_1	db	0fh dup (0)	; имя 1-го файла
	var_filename_2	db	0fh dup (0)	; имя 2-го файла
	var_filename_3	db	0fh dup (0)	; имя полученного файла
	var_file_1_descriptor	dw	0	; дескриптор 1 файла
	var_file_1_head_buff	db	2ch dup (?)	; буфер заголовка 1 и полученного файлов
	var_file_2_descriptor	dw	0	; дескриптор 2-го файла
	var_file_2_head_buff	db	2ch	dup (?)	; буфер заголовка 2 файла
	var_file_3_descriptor	dw	0	; дескриптор полученного файла
	var_blocksize	equ	0efffh	; размер блока чтения
	var_buff_data	db	var_blocksize dup (00h)	; буфер чтения блока д
	var_example	db	'RIFFWAVEdata'	; формат контейнера и аудио
	
	msg_no_params	db	'No parameters entered.',0dh,0ah,'$'
	msg_no_2_filename	db	'No second filename entered.',0dh,0ah,'$'
	msg_no_3_filename	db	'No third filename entered.',0dh,0ah,'$'
	msg_file_1	db	'First file:',0dh, 0ah, '$'
	msg_open	db	'Opening : $'
	msg_error	db	'Error : ',0dh,0ah,'File does not exists.',0dh,0ah,'$'
	msg_success	db	'Success',0dh,0ah,'$'
	msg_read_error	db	'Reading : Error',0dh,0ah,'$'
	msg_format_error	db	'Format : Invalid',0dh,0ah,'$'
	msg_right_format	db	'Format : Right',0dh,0ah,'$'
	msg_file_2	db	'Second file:',0dh, 0ah, '$'
	msg_merge	db	'Merging: ',0dh, 0ah, '$'
	msg_skip_check	db	'Format check was skipped.',0dh,0ah,'$'
	msg_compatibility_success	db	'Compatibility : Checked',0dh,0ah,'$'
	msg_compatibility_error	db	'Compatibility : Wrong',0dh,0ah,'Files are incompatible.',0dh,0ah,'$'
	msg_make	db	'Creating new file : $'
	msg_filesize_error	db	'Error : Filesize overflow',0dh,0ah,'$'
	msg_write_error	db	'Write : Error',0dh,0ah,'$'
	msg_write_success	db	'Write : Success',0dh,0ah,'$'
	msg_merge_success	db	'Successful merging.',0dh,0ah,'$'	
.code
start:				
	mov	ax,	@data		; инициализация сегмента es
	mov	es,	ax			
	push	es			; сохранение es для последующего
						; восстановления в ds

	mov	cl,	ds:[80h] ; заносим в cx длину строки параметров из командной строки
	cmp	cl,	0        
	jz		err_no_params  ; eсли параметры пусты -> выход с ошибкой
	lea	di,	var_filename_1 ; имя 1-го файла
	lea	dx,	var_filename_2 ; имя 2-го файла
	lea	bx,	var_filename_3 ; имя 3-го файла
	call	proc_read_names     ; вызов процедуры чтения параемтра
	
	pop	ds					; восстанавливаем ds
	cmp	var_filename_2,	0		; если имени второго файла нет
	je		err_no_2_filename			; выход с ошибкой
	cmp	var_filename_3,	0		; если имени третьего файла нет
	je		err_no_3_filename			; выход с ошибкой
	
	mov	ah,	9h			; вывод информации о первом файле
	lea	dx,	msg_file_1		
	int	21h				

	mov	ah,	9h			; вывод информации об открытии файла
	lea	dx,	msg_open		
	int	21h				

	mov	ah,	3dh			; открытие файла
	lea	dx,	var_filename_1	; имя первого файла
	lea	bx,	var_file_1_descriptor	; дескриптор первого файла
	call	proc_open_file	; вызов процедуры открытия файла
	jc		exit		; если была ошибка, то установится флаг переноса -> выход

	mov	bx,	var_file_1_descriptor			; дескриптор первого файла
	lea	dx,	var_file_1_head_buff				; буфер заголовка первого файла
	call	proc_header_check	; вызов процедуры проверки формата заголовка
	jc		exit				; если была ошибка, то установится флаг переноса -> выход
	jne	exit

	mov	ah,	9h			; вывод информации о втором файле
	lea	dx,	msg_file_2		
	int	21h				

	mov	ah,	9h			; вывод информации об открытии файла
	lea	dx,	msg_open		
	int	21h				

	mov	ah,	3dh			; открытие файла
	lea	dx,	var_filename_2	; имя второго файла
	lea	bx,	var_file_2_descriptor	; дескриптор второго файла
	call	proc_open_file	; вызов процедуры открытия файла
	jc		exit		; если была ошибка, то установится флаг переноса -> выход
	
	mov	bx,	var_file_2_descriptor			; дескриптор второго файла
	lea	dx,	var_file_2_head_buff				; буфер заголовка второго файла
	call	proc_header_check	; вызов процедуры проверки формата заголовка
	jc		exit				; если была ошибка, то установится флаг переноса -> выход
	jne	exit					
	
	mov	ah,	9h			; вывод информации о склейке
	lea	dx,	msg_merge		
	int	21h				
	
check_format:	
	lea	si,	var_file_1_head_buff + 0ch		; заголовки файлов
	lea	di,	var_file_2_head_buff + 0ch		; 
	call	proc_files_comp_check	; вызов процедуры проверки
	jc exit 
	
	mov	ah,	9h			; вывод информации создании нового файла
	lea	dx,	msg_make		
	int	21h				

	mov	ah,	3ch			; создание файла
	mov	cx,	0
	lea	dx,	var_filename_3	; имя полученного файла
	lea	bx,	var_file_3_descriptor 	; дескриптор полученного файла
	call	proc_open_file	; вызов процедуры создания файла
	jc		exit		; если была ошибка - выход	
	
; Формирование заголовка нового файла
	lea	si,	var_file_1_head_buff		; записываем в si заголовок первого файла
	add	si,	28h			; смещаемся до длины данных
	lodsw				; загружаем длину данных первого файла
	mov	cx,	ax			; младшие 2 байта в cx
	lodsw				 
	mov	dx,	ax			; старшие 2 байта в dx
	lea	si,	var_file_2_head_buff		; записываем в si заголовок второго файла
	add	si,	28h			; смещаемся до длины данных
	lodsw				; загружаем длины данных второго файла
	mov	bx,	ax			; старшие 2 байта в bx
	lodsw				
	xchg	bx,	ax			; старшие в ax, младшие в bx
	push	ax				; сохранение длины данных каждого файла
	push	bx				 
	push	cx				
	push	dx				
	add	ax,	cx					; вычисление младших 2 байт длины,
	adc	dx,	bx					; и старших с учетом переноса
	jc		err_overflow		; выход с ошибкой переполнения
	cmp	dx,	0effeh				; сравнение на предмет переполнения
	ja		err_overflow 	; если больше - ошибка переполнения
	jb		overflow_checked	; меньше - пропустить проверку младших
	cmp	ax,	1001h				; проверка младших разрядов размера
	ja		err_overflow 	; если больше - ошибка переполнения

overflow_checked:
	lea	si,	var_file_1_head_buff			; заголовок нового файла var_file_2_head_buff
	lea	di,	var_file_2_head_buff			; формируется из заголовка первого файла
first_continue:
	push	dx		; сохранение размера данных
	push	ax		 
	add	ax,	28h		; вычисление размера файла
	adc	dx,	0		
	mov	cx,	4		; копирование первых 4 символов: 'RIFF'
	rep	movsb	
	stosw			; добавление размера нового файла
	mov	ax,	dx		
	stosw			
	add	si,	4		; смещение на размер файла
	mov	cx,	20h		; копирование оставшегося заголовка 
	rep	movsb		; до длины данных
	pop	ax			; восстановление в ax длины данных
	stosw			; добавление длины данных
	pop	ax			
	stosw			

; Формирование заголовка нового файла
	mov	bx,	var_file_3_descriptor		;запись дескриптора нового файла в dx 
	lea	dx,	var_file_2_head_buff		; заголовок нового файла в var_file_2_head_buff
		
	mov	ah,	40h				; запись заголовка в файл
	mov	cx,	2ch				; запись 2с(44) байт
	int	21h					
	jc		err_write	; если была ошибка - выход

	mov	ah,	9h				; иначе сообщение
	lea	dx,	msg_write_success		; об успешной записи
	int	21h					

; Запись содержимого 1-го файла
	pop	dx						; восстановление старших битов длины
	pop	ax						; и младших
	mov	bx,	var_file_1_descriptor			; дескриптор первого файла
	call	proc_file_data_copy	; вызов процедуры копирования
	jc		err_write		; если была ошибка - выход
	
; Запись содержимого 2-го файла
	pop	dx					; восстановление старших битов длины
	pop	ax					; и младших
	mov	bx,	var_file_2_descriptor
	call	proc_file_data_copy
	jc		err_write
	
	mov	ah,	9h			; сообщение об успешной склейке файлов
	lea	dx,	msg_merge_success
	int	21h
	
exit:			; выход
	mov	ax,	4C00h
	int	21h
	
err_no_params:			; сообщение о пустых аргументах командной строки
	pop	ds			
	mov	ah,	9h
	lea	dx,	msg_no_params
	int	21h
	jmp	exit

err_no_2_filename:			; сообщение об отсутствии в имени второго файла в аргументах
	mov	ah,	9h
	lea	dx,	msg_no_2_filename
	int	21h
	jmp	exit
	
err_no_3_filename:			; сообщение об отсутствии в имени третьего файла в аргументах
	mov	ah,	9h
	lea	dx,	msg_no_3_filename
	int	21h
	jmp	exit

err_overflow: ; сообщение об ошибке переполнения
	mov	ah,	9h
	lea	dx,	msg_filesize_error
	int	21h
	jmp	exit

err_write:	; сооббщение об ошибке записи 
	mov	ah,	9h
	lea	dx,	msg_write_error
	int	21h
	jmp	exit

;==================================================================
; Процедура чтения имён файла
;==================================================================	
proc_read_names			proc
	mov	si,	81h				; записываем в si адрес первого символа в параметрах
	mov	cx,	4				; чтение трёх имён

skip_spaces:	; пропуск начальных пробелов
	lodsb					; загружаем очередной символ в al
	cmp	al,	20h				; сравнение с пробелом
	je		skip_spaces	; если пробел, повторить
write_char_name:				; запись имени файла
	jb		write_last_char	; если меньше, это 0Dh (конец параметров)
	stosb					; если нет, символ в имя файла
	lodsb					; следующий символ в al
	cmp	al,	20h				; сравнение с пробелом
	jne	write_char_name			; если не пробел, повторить
write_last_char:
	mov	al,	0				; в al нулевой символ
	stosb					; нулевой символ как конец имени файла
	pushf					; сохраняем в стеке значение регистра флагов
	mov	di,	bp				
	cmp	cx,	2				; если второй файл уже введен
	je	skip_step		; пропуск следующей команды
	mov	di,	bx
	cmp	cx,	3				; если третий файл уже введен
	je	skip_step		; пропуск следующей команды
	mov	di,	dx
skip_step:
	popf					; извлекаем значение регистра флагов из стека
	loope	skip_spaces	; если последний символ пробел, повторить
;========================================================================
	ret
proc_read_names			endp	

;==================================================================
; Процедура открытия/создания файла
;==================================================================
proc_open_file			proc
	mov	al,	0	; открыть для чтения 
	int	21h
	jc		err_opening	; если ошибка чтения, то установится флаг переноса -> выход с ошибкой
	mov	[bx],	ax				; запись идентификатора файла
	mov	ah,	9h				; сообщение об успешном чтении файлов
	lea	dx,	msg_success
	int	21h
	ret
err_opening:	; сообщение об ошибке чтения
	mov	ah,	9h
	lea	dx,	msg_error
	int	21h
	ret
proc_open_file	endp

;==========================================================================================
; Процедура чтения заголовка файла и проверки его соответствия формату RIFF/WAV 
;==========================================================================================
proc_header_check	proc
	mov	cx,	2ch				; считывание первых 2ch бит
	mov	ah,	3fh				; из указанного файла в указанный буфер
	int	21h					
	jc	err_read
	lea	si,	var_example	; загрузка строки-примера для сравнения
	mov	di,	dx				; сравнение строки-примера с буфером
	mov	cx,	4				; 4 первых символа ('RIFF')
	repe	cmpsb			
	jne	err_format		; если есть несовпадение - выход
	add	di,	4				; иначе смещение  на 4 символа
	mov	cx,	4				; и сравнение еще 4-х символов ('WAVE')
	repe	cmpsb			
	jne	err_format		; если есть несовпадение - выход
	add	di,	18h			; иначе смещение на 18 символов
	mov	cx,	4				; и сравнение еще 4-х символов ('data')
	repe	cmpsb			
	jne	err_format		; если есть несовпадение - выход
	mov	ah,	9h				; сообщение об успешном чтении файлов
	lea	dx,	msg_right_format	
	int	21h					
	ret						
err_read:
	mov	ah,	9h				; сообщение об ошибке чтения
	lea	dx,	msg_read_error
	int	21h
	ret
err_format:
	mov	ah,	9h				; сообщение о неверном формате файла
	lea	dx,	msg_format_error
	int	21h
	ret
proc_header_check	endp

;==================================================================
; Процедура проверки совместимости параметров файлов
;==================================================================
proc_files_comp_check	proc
	mov	cx,	1ch				; проверка 1ch символов на идентичность
	repe	cmpsb			;
	jne	err_compability			; если есть несовпадение - выход с ошибкой
	mov	ah,	9h				; сообщение об успешном сравнении форматов
	lea	dx,	msg_compatibility_success
	int	21h
	ret
err_compability:
	mov	ah,	9h				; сообщение об ошибке сравнения форматов
	lea	dx,	msg_compatibility_error
	int	21h
	ret
proc_files_comp_check	endp

;==================================================================
; Процедура копирования в из указанного в bx файла в новый файл
;==================================================================
proc_file_data_copy	proc
	mov	cx,	0efffh			; вычисление количества повторений 
	div	cx					; при записи блоками по EFFFh байт
	push	dx				; сохранение размера последнего блока
	cmp	ax,	0				; если файл меньше EFFFh
	je		write_once		; запись единственного блока длиной dx
	mov	cx,	ax				; иначе копирование блоков данных по EFFFh
write_several:
	jc		write_error			; если была ошибка записи - выход
	
	push	cx				; сохранение числа оставшихся повторений
	mov	ah,	3fh				; чтение из первого файла (идентификатор в bx)
	mov	cx,	0efffh			; блока EFFFh байтов
	lea	dx,	var_buff_data  	; в буфер
	int	21h					
	
	push	bx				; сохранение идентификатора первого файла
	mov	ah,	40h				; запись этого блока
	mov	bx,	var_file_3_descriptor		; в новый файл
	mov	cx,	0efffh			; блок EFFFh байтов
	int	21h					
	
	pop	bx					; восстановление идентификатора первого файла 
	pop	cx					; восстановление числа оставшихся повторов
	loop	write_several			; повтор цикла
	
write_once:	
	mov	ah,	3fh				; чтение из первого файла (идентификатор в bx)
	pop	cx					; последнего блока
	lea	dx,	var_buff_data 	; в буфер
	int	21h					;
	
	mov	ah,	40h				; запись этого блока
	mov	bx,	var_file_3_descriptor		; в новый файл
	int	21h					
write_error:
	ret
proc_file_data_copy	endp

end	start	
