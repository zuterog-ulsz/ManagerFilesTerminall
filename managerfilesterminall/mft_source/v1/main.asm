section .data
    VERSION      db "MFT Version 1", 0xA, 0
    dot          db ".", 0
    dot_dot      db "..", 0
    newline_char db 0xA, 0
    lang_file    db "lang.txt", 0

    ; Переменные состояния
    lang_mode       db 0    ; 0 = RU, 1 = EN
    warning_enabled db 1    ; 1 = ON, 0 = OFF (по умолчанию 1)

    ; Сообщения для AW
    aw_msg_ru    db "Предупреждения включены (Active Warnings)", 0xA, 0
    aw_msg_en    db "Warnings enabled (Active Warnings)", 0xA, 0
    utw_msg_ru   db "Предупреждения отключены", 0xA, 0
    utw_msg_en   db "Warnings disabled", 0xA, 0

    ; Сообщения помощи
    help_ru      db "--- Команды MFT v1 ---", 0xA
                 db "v          - Показать версию", 0xA
                 db "ln         - Переключить язык (RU/EN)", 0xA
                 db "lf         - Список файлов в текущей папке", 0xA
                 db "md         - Показать текущий путь (pwd)", 0xA
                 db "nf [путь]  - Перейти в папку (cd)", 0xA
                 db "cd [имя]   - Создать новую папку (mkdir)", 0xA
                 db "cf [имя]   - Создать пустой файл (touch)", 0xA
                 db "cpf [откуда] [куда] - Копировать файл", 0xA
                 db "m [откуда] [куда]   - Переместить или переименовать", 0xA
                 db "rf [имя]   - Удалить файл", 0xA
                 db "rd [имя]   - Удалить папку (со всем содержимым)", 0xA
                 db "aw         - Включить предупреждения (Active Warnings)", 0xA
                 db "utw        - Отключить предупреждения (Silent Mode)", 0xA
                 db "h          - Показать эту справку", 0xA
                 db "q          - Выход из программы", 0xA, 0

    help_en      db "--- MFT v1 Commands ---", 0xA
                 db "v          - Show version", 0xA
                 db "ln         - Switch language (RU/EN)", 0xA
                 db "lf         - List files in current directory", 0xA
                 db "md         - Show current path (pwd)", 0xA
                 db "nf [path]  - Go to folder (cd)", 0xA
                 db "cd [name]  - Create new directory (mkdir)", 0xA
                 db "cf [name]  - Create empty file (touch)", 0xA
                 db "cpf [src] [dest] - Copy file", 0xA
                 db "m [src] [dest]   - Move or rename", 0xA
                 db "rf [name]  - Remove file", 0xA
                 db "rd [name]  - Remove directory (recursive)", 0xA
                 db "aw         - Enable warnings (Active Warnings)", 0xA
                 db "utw        - Disable warnings (Silent Mode)", 0xA
                 db "h          - Show this help", 0xA
                 db "q          - Exit program", 0xA, 0

    warn_msg_ru  db "Вы уверены, что хотите удалить? (y/n): ", 0
    warn_msg_en  db "Are you sure you want to delete? (y/n): ", 0
    prompt_ru    db "mft> ", 0
    prompt_en    db "mft_en> ", 0
    err_ru       db "Ошибка: команда не найдена или ошибка операции", 0xA, 0
    err_en       db "Error: command not found or operation error", 0xA, 0
    root_err     db "Run as sudo!", 0xA, 0
    warn_not_empty_ru db "Папка не пуста! Удалить всё содержимое? (y/n): ", 0
    warn_not_empty_en db "Folder is not empty! Delete everything inside? (y/n): ", 0

    ;wrm
    ls_msg_ru    db "Содержимое папки:", 0xA, 0
    ls_msg_en    db "Folder content:", 0xA, 0

section .bss
    input_buf    resb 255
    path_buf     resb 255
    dest_buf     resb 255    
    dir_buf      resb 8192
    copy_buffer  resb 16384  
    cwd_buf      resb 512    

section .text
    global _start

_start:
    ; --- ПРОВЕРКА НА ROOT ---
    mov rax, 102        
    syscall
    test rax, rax
    jz .is_root
    
    mov rsi, root_err
    call print_string
    mov rax, 60         
    mov rdi, 1
    syscall

.is_root:
    call load_settings  
    jmp main_loop       
    
save_settings:
    mov rax, 2                 
    mov rdi, lang_file
    mov rsi, 0101o             
    mov rdx, 0666o
    syscall
    test rax, rax
    js .ret_s
    
    mov rdi, rax
    mov al, [lang_mode]
    mov [input_buf], al
    mov al, [warning_enabled]
    mov [input_buf+1], al
    
    mov rax, 1                 
    mov rsi, input_buf
    mov rdx, 2
    syscall
    
    mov rax, 3                 
    syscall
.ret_s:
    ret

load_settings:
    mov rax, 2
    mov rdi, lang_file
    mov rsi, 0
    syscall
    test rax, rax
    js .default
    
    mov rdi, rax
    mov rax, 0
    mov rsi, input_buf
    mov rdx, 2
    syscall
    
    mov al, [input_buf]
    mov [lang_mode], al
    mov al, [input_buf+1]
    mov [warning_enabled], al
    
    mov rax, 3
    syscall
    ret
.default:
    mov byte [lang_mode], 0
    mov byte [warning_enabled], 1
    ret

main_loop:
    ; Отрисовка промпта
    cmp byte [lang_mode], 0
    je .p_ru
    mov rsi, prompt_en
    jmp .p_d
.p_ru:
    mov rsi, prompt_ru
.p_d:
    call print_string

    ; Чтение ввода
    mov rax, 0
    mov rdi, 0
    mov rsi, input_buf
    mov rdx, 255
    syscall
    cmp rax, 1
    jle main_loop

    ; --- ЛОГИКА КОМАНД ---

    ; 1. v (Version)
    mov al, [input_buf]
    cmp al, 'v'
    jne .c_ln
    cmp byte [input_buf+1], 0xA
    jne .c_ln
    mov rsi, VERSION
    call print_string
    jmp main_loop

.c_ln:
    ; 2. ln (Language)
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x0A6E6C
    jne .c_h
    call switch_lang
    jmp main_loop

.c_h:
    ; 3. h (Help)
    cmp byte [input_buf], 'h'
    jne .c_lf
    cmp byte [input_buf+1], 0xA
    jne .c_lf
    call handle_h
    jmp main_loop

.c_lf:
    ; 4. lf (List Files)
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x0A666C
    jne .c_nf
    call list_files
    jmp main_loop

.c_nf:
    ; 5. nf (Next Folder)
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x20666E
    jne .c_md
    call handle_nf
    jmp main_loop

.c_md:
    ; 6. md (My Directory)
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x0A646D
    jne .c_cd
    call handle_md
    jmp main_loop

.c_cd:
    ; 7. cd (Create Directory)
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x206463
    jne .c_cf
    call handle_cd
    jmp main_loop

.c_cf:
    ; 8. cf (Create File)
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x206663
    jne .c_utw
    call handle_cf
    jmp main_loop

.c_utw:
    mov eax, [input_buf]
    and eax, 0xFFFFFF
    cmp eax, 0x777475          
    jne .c_aw
    mov byte [warning_enabled], 0
    call save_settings         
    ; Вывод текста (опционально)
    mov rsi, utw_msg_ru
    cmp byte [lang_mode], 0
    je .p_utw
    mov rsi, utw_msg_en
.p_utw:
    call print_string
    jmp main_loop

.c_aw:
    mov ax, [input_buf]
    cmp ax, 0x7761             
    jne .c_rf
    mov byte [warning_enabled], 1
    call save_settings         
    mov rsi, aw_msg_ru
    cmp byte [lang_mode], 0
    je .p_aw
    mov rsi, aw_msg_en
.p_aw:
    call print_string
    jmp main_loop

.c_rf:
    ; 11. rf (удаление файла)
    mov ax, [input_buf]
    cmp ax, 0x6672
    jne .c_rd
    call handle_rf          
    jmp main_loop

.c_rd:
    ; 11. rd (Remove Directory)
    mov ax, [input_buf]
    cmp ax, 0x6472
    jne .c_m
    call handle_rd
    jmp main_loop

.c_m:
    ; 12. m (Move)
    cmp byte [input_buf], 'm'
    jne .c_cpf
    cmp byte [input_buf+1], ' '
    jne .c_cpf
    call handle_m
    jmp main_loop

.c_cpf:
    ; 13. cpf (Copy File) - проверяем 4 байта: c(63) p(70) f(66) ' '(20)
    mov eax, [input_buf]
    cmp eax, 0x20667063
    jne .c_q
    call handle_cpf
    jmp main_loop

.c_q:
    ; 14. q (Quit)
    cmp byte [input_buf], 'q'
    je exit_prog

    ; Ошибка
    cmp byte [lang_mode], 0
    je .err_ru_msg
    mov rsi, err_en
    call print_string
    jmp main_loop
.err_ru_msg:
    mov rsi, err_ru
    call print_string
    jmp main_loop

; --- ФУНКЦИИ ---

handle_h:
    cmp byte [lang_mode], 0
    je .h_ru
    mov rsi, help_en
    call print_string
    ret
.h_ru:
    mov rsi, help_ru
    call print_string
    ret

handle_rf:
    call parse_one_arg
    call check_warning
    test rax, rax
    jz .rf_exit
    mov rax, 87 
    mov rdi, path_buf
    syscall
.rf_exit:
    ret

handle_rd:
    call parse_one_arg
    
    ; 1. Проверка основного предупреждения
    call check_warning
    test rax, rax
    jz .rd_exit

    ; 2. Пробуем быстро удалить папку (если она уже пустая)
    mov rax, 84               
    mov rdi, path_buf
    syscall
    
    ; 3. Если ошибка -39 (ENOTEMPTY), значит папка не пуста
    cmp rax, -39
    jne .rd_exit               
    
    ; Проверяем режим тишины (utw)
    cmp byte [warning_enabled], 0
    je .do_cleaning_immediately

    ; Выводим вопрос про непустую папку
    cmp byte [lang_mode], 0
    je .w_ne_ru
    mov rsi, warn_not_empty_en
    jmp .w_ne_p
.w_ne_ru:
    mov rsi, warn_not_empty_ru
.w_ne_p:
    call print_string
    
    ; Ждем подтверждения y/n
    mov rax, 0
    mov rdi, 0
    mov rsi, input_buf
    mov rdx, 10
    syscall
    cmp byte [input_buf], 'y'
    jne .rd_exit

.do_cleaning_immediately:
    ; --- НАЧАЛО ЦИКЛА ОЧИСТКИ ---
    mov rax, 2                 
    mov rdi, path_buf
    mov rsi, 0o200000          
    syscall
    test rax, rax
    js .rd_exit
    push rax                   

.rd_read_loop:
    mov rdi, [rsp]            
    mov rax, 217               
    mov rsi, dir_buf
    mov rdx, 8192
    syscall
    test rax, rax
    jle .rd_done_cleaning      
    
    mov rbx, rax               
    xor rcx, rcx               

.rd_entry_loop:
    push rcx
    push rbx
    lea rsi, [dir_buf + rcx + 19] 
    
    ; Пропускаем "." и ".."
    cmp byte [rsi], '.'
    je .rd_skip
    
    ; Удаляем файл внутри (через chdir туда-сюда)
    mov rax, 80               
    mov rdi, path_buf
    syscall
    
    mov rax, 87                
    mov rdi, rsi
    syscall
    
    mov rax, 80                
    mov rdi, dot_dot
    syscall

.rd_skip:
    pop rbx
    pop rcx
    movzx rdx, word [dir_buf + rcx + 16] 
    add rcx, rdx
    cmp rcx, rbx
    jl .rd_entry_loop
    jmp .rd_read_loop

.rd_done_cleaning:
    pop rdi                    
    mov rax, 3
    syscall
    
    ; Теперь папка точно пустая, удаляем её
    mov rax, 84                
    mov rdi, path_buf
    syscall

.rd_exit:
    ret

handle_m:
    call parse_two_args
    mov rax, 82                
    mov rdi, path_buf          
    mov rsi, dest_buf          
    syscall
    test rax, rax
    js .m_err                 
    ret
.m_err:
    call show_error
    ret

handle_cpf:
    call parse_two_args
    ; Открыть источник
    mov rax, 2
    mov rdi, path_buf
    mov rsi, 0
    syscall
    test rax, rax
    js .cp_err
    push rax 

    ; Создать цель
    mov rax, 85
    mov rdi, dest_buf
    mov rsi, 0666o
    syscall
    test rax, rax
    js .cp_err_pop
    push rax 

    ; Копирование (16Кб)
    mov rax, 0
    mov rdi, [rsp+8]
    mov rsi, copy_buffer
    mov rdx, 16384
    syscall
    
    mov rdx, rax
    mov rdi, [rsp]
    mov rax, 1
    mov rsi, copy_buffer
    syscall

    ; Закрываем
    pop rdi
    mov rax, 3
    syscall
    pop rdi
    mov rax, 3
    syscall
    ret

.cp_err_pop:
    pop rdi      ; Достаем FD источника
    mov rax, 3   ; Номер sys_close
    syscall
    jmp .cp_err
.cp_err:
    call show_error
    ret

; Маленькая вспомогательная функция для вывода ошибки
show_error:
    cmp byte [lang_mode], 0
    je .se_ru
    mov rsi, err_en
    jmp .se_p
.se_ru:
    mov rsi, err_ru
.se_p:
    call print_string
    ret

check_warning:
    cmp byte [warning_enabled], 0
    je .ok
    cmp byte [lang_mode], 0
    je .w_ru
    mov rsi, warn_msg_en
    jmp .w_p
.w_ru:
    mov rsi, warn_msg_ru
.w_p:
    call print_string
    mov rax, 0
    mov rdi, 0
    mov rsi, input_buf
    mov rdx, 10
    syscall
    cmp byte [input_buf], 'y'
    je .ok
    xor rax, rax
    ret
.ok:
    mov rax, 1
    ret

parse_two_args:
    ; 1. Очистка буферов (path_buf и dest_buf)
    xor rcx, rcx
.cl_loop:
    mov byte [path_buf+rcx], 0
    mov byte [dest_buf+rcx], 0
    inc rcx
    cmp rcx, 255
    jne .cl_loop
    
    ; 2. Пропуск команды до первого пробела
    mov rsi, input_buf
.find_space:
    inc rsi
    cmp byte [rsi], 0xA        ; Если Enter раньше пробела - выходим
    je .done_args
    cmp byte [rsi], ' '
    jne .find_space
    inc rsi                    ; Теперь rsi указывает на ПЕРВЫЙ аргумент
    
    ; 3. Копируем ПЕРВЫЙ аргумент в dest_buf (до пробела)
    xor rcx, rcx
    mov rdi, dest_buf
.copy_arg1:
    mov al, [rsi]
    cmp al, ' '                ; Пробел разделяет аргументы
    je .next_arg
    cmp al, 0xA                ; Если Enter - второго аргумента нет
    je .done_args
    mov [rdi], al
    inc rsi
    inc rdi
    inc rcx
    cmp rcx, 254               ; Защита от переполнения
    je .next_arg
    jmp .copy_arg1

.next_arg:
    inc rsi                    ; Пропускаем пробел между аргументами
    xor rcx, rcx
    mov rdi, path_buf          ; Теперь копируем во ВТОРОЙ буфер
.copy_arg2:
    mov al, [rsi]
    cmp al, 0xA                ; До конца строки
    je .done_args
    cmp al, 0
    je .done_args
    mov [rdi], al
    inc rsi
    inc rdi
    inc rcx
    cmp rcx, 254               ; Защита от переполнения
    je .done_args
    jmp .copy_arg2

.done_args:
    ret

parse_one_arg:
    ; 1. Очистка буфера path_buf перед использованием
    push rcx
    mov rcx, 255
.cl1:
    mov byte [path_buf+rcx-1], 0
    loop .cl1
    pop rcx

    ; 2. Пропуск самой команды (например, "nf " или "rf ")
    mov rsi, input_buf
.f2:
    inc rsi
    cmp byte [rsi], 0xA        ; Если строка кончилась внезапно
    je .e1
    cmp byte [rsi], ' '        ; Ищем пробел после команды
    jne .f2
    inc rsi                    ; Переходим к самому аргументу

    ; 3. Копирование аргумента в path_buf
    push rcx
    xor rcx, rcx               ; Счетчик для защиты от переполнения
    mov rdi, path_buf
.c1:
    mov al, [rsi]
    cmp al, 0xA                ; Конец строки (Enter)
    je .done_p
    cmp al, 0                  ; Нуль-терминатор
    je .done_p
    
    mov [rdi], al
    inc rsi
    inc rdi
    inc rcx
    cmp rcx, 254               ; Защита: не более 254 символов
    je .done_p
    jmp .c1

.done_p:
    pop rcx
.e1:
    ret

handle_md:
    mov rax, 79
    mov rdi, cwd_buf
    mov rsi, 4096
    syscall
    mov rsi, cwd_buf
    call print_string
    mov rsi, newline_char
    call print_string
    ret

handle_nf:
    call parse_one_arg
    mov rax, 80
    mov rdi, path_buf
    syscall
    ret

handle_cd:
    call parse_one_arg
    mov rax, 83
    mov rdi, path_buf
    mov rsi, 0777o
    syscall
    ret

handle_cf:
    call parse_one_arg
    mov rax, 85
    mov rdi, path_buf
    mov rsi, 0666o
    syscall
    ret

list_files:
    cmp byte [lang_mode], 0
    je .l_ru
    mov rsi, ls_msg_en
    jmp .l_p
.l_ru:
    mov rsi, ls_msg_ru
.l_p:
    call print_string
    mov rax, 2
    mov rdi, dot
    mov rsi, 0o200000
    syscall
    push rax
    mov rdi, rax
    mov rax, 217
    mov rsi, dir_buf
    mov rdx, 8192
    syscall
    mov rbx, rax
    xor rcx, rcx
.lp_ls:
    cmp rcx, rbx
    jge .cl_ls
    lea rsi, [dir_buf + rcx + 19]
    call print_string
    push rcx
    push rbx
    mov rax, 1
    mov rdi, 1
    mov rsi, newline_char
    mov rdx, 1
    syscall
    pop rbx
    pop rcx
    movzx rdx, word [dir_buf + rcx + 16]
    add rcx, rdx
    jmp .lp_ls
.cl_ls:
    pop rdi
    mov rax, 3
    syscall
    ret

 switch_lang:
    xor byte [lang_mode], 1
    call save_settings 
    ret

load_lang:
    mov rax, 2
    mov rdi, lang_file
    mov rsi, 0
    syscall
    test rax, rax
    js .def_l
    mov rdi, rax
    mov rax, 0
    mov rsi, lang_mode
    mov rdx, 1
    syscall
    mov rax, 3
    syscall
    ret
.def_l:
    mov byte [lang_mode], 0
    ret

print_string:
    push rax
    push rbx
    push rcx
    push rdx
    xor rdx, rdx
.cnt:
    cmp byte [rsi + rdx], 0
    je .pr
    inc rdx
    jmp .cnt
.pr:
    mov rax, 1
    mov rdi, 1
    syscall
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

exit_prog:
    mov rax, 60
    xor rdi, rdi
    syscall