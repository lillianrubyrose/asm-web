format ELF64 executable

AF_INET = 2
SOCK_STREAM = 1
IPPROTO_IP = 0
INADDR_ANY = 0

macro linux_write fd, buf, len {
    mov rax, 1
    mov rdi, fd
    mov rsi, buf
    mov rdx, len
    syscall
}

macro sout buf, len {
    linux_write 1, buf, len
}

macro linux_socket domain, type, protocol {
    mov rax, 41
    mov rdi, domain
    mov rsi, type
    mov rdx, protocol
    syscall
}

macro linux_bind fd, addr, len {
    mov rax, 49
    mov rdi, fd
    mov rsi, addr
    mov rdx, len
    syscall
}

; output goes in ax register.
macro htons val {
    mov ax, val
    mov cx, ax

    ; htons reimplemented
    and ax, 0xFF
    shl ax, 8
    and cx, 0xFF00
    shr cx, 8
    or ax, cx
}

macro linux_close fd {
    mov rax, 3
    mov rdi, fd
    syscall
}

macro linux_listen fd, backlog {
    mov rax, 50
    mov rdi, fd
    mov rsi, backlog
    syscall
}

macro linux_accept fd, addr, len {
    mov rax, 43
    mov rdi, fd
    mov rsi, addr
    mov rdx, len
    syscall
}

segment readable executable
    sout start_message, start_message_len

    linux_socket AF_INET, SOCK_STREAM, IPPROTO_IP
    cmp rax, 0
    jl non_zero_exit
    mov qword [socket_fd], rax

    mov word [bind_address.sin_family_t], AF_INET
    htons 8080
    mov word [bind_address.sin_port], ax
    mov dword [bind_address.sin_addr], INADDR_ANY

    sout linux_bind_message, linux_bind_message_len
    linux_bind [socket_fd], bind_address.sin_family_t, sizeOfBindAddress
    cmp rax, 0
    jl non_zero_exit

    linux_listen [socket_fd], 1337 ; max connections, we're single threaded so doesnt rly matter.
    cmp rax, 0
    jl non_zero_exit

handle_request:
    linux_accept [socket_fd], client_address.sin_family_t, client_address.len
    cmp rax, 0
    jl non_zero_exit

    mov qword [client_fd], rax

    linux_write [client_fd], page_content, page_content_len
    linux_close [client_fd]

    jmp handle_request
 
    linux_close [socket_fd]

    mov rax, 60 ; exit
    mov rdi, 0  ; code
    syscall

non_zero_exit:
    sout error_message, error_message_len
    linux_close [client_fd]
    linux_close [socket_fd]

    mov rax, 60
    mov rdi, 1
    syscall

segment readable writeable
    start_message db "asm-http starting", 0xA
    start_message_len = $ - start_message

    error_message db "asm-http encountered an error.", 0xA
    error_message_len = $ - error_message

    linux_bind_message db "asm-http is binding to port 8080", 0xA
    linux_bind_message_len = $ - linux_bind_message

    page_content db "HTTP/1.1 200 OK", 0xD, 0xA ; cr lf
                 db "Connection: close", 0xD, 0xA
                 db "Content-Type: text/html", 0xD, 0xA
                 db 0xD, 0xA
                 db "<p class=", 0x22, "red", 0x22, ">Hello World!</p>", 0xA
                 db "<style> .red { color: red; } </style>", 0xA
    page_content_len = $ - page_content

    socket_fd dq -999
    bind_address.sin_family_t dw 0
    bind_address.sin_port dw 0
    bind_address.sin_addr dd 0
    bind_address.sin_zero dq 0 ; padding
    sizeOfBindAddress = $ - bind_address.sin_family_t

    client_fd dq -999
    client_address.sin_family_t dw 0
    client_address.sin_port dw 0
    client_address.sin_addr dd 0
    client_address.sin_zero dq 0 ; padding
    client_address.len dd sizeOfBindAddress ; accept requires a ptr