.data 
    v: .space 1024 # spatiul nostru de memorie ce va tine un array unidimensional de elemente de tip byte (1024 bytes)
    formatReadInt: .asciz "%d"
    formatPrintf: .asciz "%d\n"
    operationsCount: .space 4
    operationCode: .space 4  # va fi pus pe stiva deci ii alocam 4 bytes
    addFilesCount: .space 4
    formatPrintfAdd: .asciz "%d: (%d, %d)\n"
    formatPrintfGet: .asciz "(%d, %d)\n"
    fileDescriptor: .space 4 # va fi pus pe stiva deci ii alocam 4 bytes
    fileSize: .space 4
    countBlocksNeeded: .space 4
.text 
.global main
print_memory:
    push %ebp 
    mov %esp, %ebp # setam base pointerul 
    push %edi
    xor %ecx, %ecx # counter pentru a parcurge vectorul
    mov 8(%ebp), %edi # adresa vectorului
et_loop_print_memory:
    cmpl $1024, %ecx 
    je et_exit_print_memory 
    xor %eax, %eax
    mov (%edi, %ecx, 1), %al # %al va contine elementul de la pozitia ecx din memorie
    cmpb $0, %al
    je et_print_memory_increment
    # altfel avem un descriptor la pozitia ecx (salvat in al)
    mov %ecx, %edx # in edx avem prima pozitie ocupata de fisierul cu descriptorul respectiv
et_loop_descriptor:
    cmpl $1024, %ecx
    je et_printMemoryInterval
    cmpb %al, (%edi, %ecx, 1) # in al ramane descriptorul stocat in primul bloc
    jne et_printMemoryInterval # odata ce gasim un alt descriptor/ spatiu liber, inseamna ca
    # am terminat de parcurs spatiul continuu ocupat de descriptorul initial
    inc %ecx # cautam ultimul bloc ocupat de fisierul curent
    jmp et_loop_descriptor
et_print_memory_increment:
    inc %ecx # continuam sa cautam blocuri ocupate de fisiere
    jmp et_loop_print_memory
et_printMemoryInterval:
    dec %ecx # (%edi, %ecx, 1) != descriptor, ca sa ajunga la eticheta sta
    # deci decrementam ecx
    push %ecx # salvam counter-ul, pentru a continua de aici cautarea
    push %ecx # capatul din dreapta al intervalului
    push %edx # capatul din stanga al intervalului
    push %eax # descriptorul
    push $formatPrintfAdd # acelasi format ca la afisul de la add
    call printf 
    add $16, %esp
    pop %ecx # restauram counter-ul
    inc %ecx
    jmp et_loop_print_memory

et_exit_print_memory:
    pop %edi 
    pop %ebp
    ret
op_add:
    push %ebp
    mov %esp, %ebp # plasam base pointer-ul
    push %edi 
    push %ebx
    mov 8(%ebp), %edi # adresa vectorului
    xor %ebx, %ebx 
    mov 16(%ebp), %eax # fileSize
    mov $8, %ebx # avem nevoie de partea intreaga superioara
    # a lui fileSize / 8
    xorl %edx, %edx # golesc edx inainte de impartire
    divl %ebx 
    xor %ebx, %ebx
    cmpl $0, %edx
    je et_no_remainder
    # in edx se stocheaza restul, deci daca edx nu este egal cu 0
    # programul nu va sari la eticheta et_no_remainder
    # si va continua liniar executarea, cu cazul in care
    # restul e nenul, deci nu se imparte exact
    # fileSize la 8, in acest caz pt a avea partea
    # intreaga superioara adaugam 1 la catul impartirii
    # obtinand nr de blocuri necesare fisierului
    inc %eax # incrementam catul
et_no_remainder:
    mov %eax, countBlocksNeeded # pt ambele cazuri mutam in
    # countBlocksNeeded catul, singura diferenta e ca
    # afaugam 1 daca restul e nenul
    mov 12(%ebp), %eax # al va contine descriptorul
    xor %ecx, %ecx # counter pt a parcurge vectorul
op_add_search_loop: 
    cmpl $1024, %ecx
    je op_add_memory_error
    # daca ajungem pana la final si nu gasim
    # niciun bloc cu memorie destula pt fisierul curent
    # inseamna ca memoria este plina, iar fisiere nu mai pot fi adaugate
    movb (%edi, %ecx, 1), %bl # bl are 1 byte
    # il folosim pt a stoca elementul curent
    # din array
    cmpb $0, %bl
    jne op_add_searchIncrement
    # ajungem in acest scope cand am gasit un bloc
    # gol in memorie (v[ecx] = 0)
    xor %edx, %edx # <1024
    inc %edx # deja am verificat ca (%edi, %ecx + %edx, 1) = (%edi, %ecx + 0, 1) = 0
    # un al doilea counter
op_add_validateBlocks_loop:
    push %edx # edx counter de la 0 pana la nr de blocuri necesare
    cmpl countBlocksNeeded, %edx
    je op_addToMemory # am gasit atatea blocuri goale de cate avem nevoie, vom adauga in array 
    # si vom afisa intervalele
    add %ecx, %edx # edx = pozitia efectiva a elementului in array
    cmp $1023, %edx
    jg op_add_memory_error_pop # nu avem spatiu liber necesar, vom afisa (0, 0)
    # trebuie sa dam pop la %edx pentru a restaura corect valorile din stiva, la final
    cmpb $0, (%edi,%edx,1) 
    jne op_add_searchIncrement_pop # trebuie sa dam pop, deoarece nu se mai ajunge la randurile
    # ce urmeaza de cod
    pop %edx
    inc %edx 
    jmp op_add_validateBlocks_loop
op_addToMemory:
    pop %edx
    add %ecx, %edx # edx devine capatul din dreapta al intervalului de afisat + 1
op_add_loop_addToMemory:
    cmpl %edx, %ecx 
    je op_add_print_addToStack # memoria a fost deja umpluta corect, putem umple stiva pt apela printf
    # pentru intervalul umplut de fisier
    movb %al, (%edi, %ecx, 1) # descriptorul
    inc %ecx 
    jmp op_add_loop_addToMemory
op_add_searchIncrement_pop:
    pop %edx
op_add_searchIncrement:
    inc %ecx # cautam alta succesiune de blocuri libere
    jmp op_add_search_loop
op_add_print_addToStack:
    dec %edx 
    subl countBlocksNeeded, %ecx # capatul din stanga
    push %edx # capatul din dreapta
    push %ecx # capatul din stanga
    xor %eax, %eax
    mov (%edi,%edx,1), %al
    push %eax # descriptorul
    jmp op_add_print
op_add_memory_error_pop:
    pop %edx
op_add_memory_error:
    push $0
    push $0
    push %eax
op_add_print:
    push $formatPrintfAdd # format string-ul pt add
    call printf
    add $16, %esp 
    pop %ebx 
    pop %edi
    pop %ebp
    ret
op_get:
    push %ebp
    mov %esp, %ebp # pun base pointer-ul
    push %edi 
    push %ebx
    mov 8(%ebp), %edi # adresa vectorului
    xor %eax, %eax
    mov 12(%ebp), %eax # descriptorul de cautat se gaseste in al
    xor %ecx, %ecx # counter pentru parcurs array-ul
op_get_search_loop:
    cmpl $1024, %ecx 
    je op_get_print_not_found
    cmpb %al, (%edi,%ecx,1)
    jne op_get_increment
    # aici ajunge daca se gaseste fisierul in memorie
    # acum cautam prima si ultima sa aparitie
    mov %ecx, %ebx # in ebx vom avea prima val
    inc %ecx
op_get_search_last_loop:
    cmpb %al, (%edi,%ecx,1) # caut prima val diferita de descriptor
    jne op_get_update_last
    cmpl $1024, %ecx # in caz ca se afla la finalul memoriei
    je op_get_update_last
    inc %ecx 
    jmp op_get_search_last_loop
op_get_increment:
    inc %ecx # nu am gasit inca fisierul in memorie
    jmp op_get_search_loop
op_get_update_last:
    dec %ecx 
op_get_print_found:
    push %ecx # capatul din dreapta
    push %ebx # capatul din stanga
    jmp op_get_print
op_get_print_not_found:
    push $0
    push $0
op_get_print:
    push $formatPrintfGet # string format-ul pt get
    call printf 
    add $12, %esp
    pop %ebx 
    pop %edi
    pop %ebp
    ret
op_delete:
    push %ebp 
    mov %esp, %ebp # pun base pointer-ul
    push %edi 
    mov 8(%ebp), %edi # adresa vectorului
    xor %eax, %eax
    mov 12(%ebp), %eax # descriptorul de cautat se gaseste in al
    xor %ecx, %ecx 
op_delete_search_loop:
    cmpl $1024, %ecx 
    je op_delete_exit # afisamn memoria nemodificata (nu a fost gasit fisierul in memorie
    # si am iterat pana la finalul array-ului)
    cmpb %al, (%edi,%ecx,1)
    jne op_delete_increment
    # aici ajunge daca se gaseste fisierul in memorie
    # acum dorim sa stergem acest fisier, inlocuind
    # toate aparitiile din memorie ale descriptorului
    # acestuia cu 0
    movb $0, (%edi, %ecx, 1)
    inc %ecx
op_delete_loop:
    cmpb %al, (%edi, %ecx, 1)
    jne op_delete_exit 
    cmpl $1024, %ecx 
    je op_delete_exit # afisam memoria, fisierul era la final si a fost sters
    movb $0, (%edi, %ecx, 1)
    inc %ecx
    jmp op_delete_loop
op_delete_increment:
    inc %ecx # continui cautarea fisierului de sters
    jmp op_delete_search_loop
op_delete_exit:
    push %edi 
    call print_memory # afisam intreaga memorie, in starea curenta, dupa stergere
    pop %edi
    pop %edi
    pop %ebp
    ret
op_defragmentation:
    push %ebp
    mov %esp, %ebp # pun base pointer-ul
    push %edi 
    mov 8(%ebp), %edi # adresa vectorului
    xor %ecx, %ecx 
    # inc %ecx 
op_defragmentation_loop:
    cmpl $0, %ecx # pt ca ecx trb sa inceapa de la 1, dar si daca va ajunge 0
    jne op_defragmentation_notZero # vreodata in rularea programului, trebuie sa il incrementam (pe prima poz vom avea descriptor)
    inc %ecx
op_defragmentation_notZero:
    cmpl $1024, %ecx # s-a terminat operatia (am iterat pana la final)
    je op_defragmentation_exit
    xor %al, %al
    xor %dl, %dl 
    movb (%edi, %ecx, 1), %dl # dl file descriptor (!=0)
    cmpb $0, %dl #  cautam blocuri ocupate ce se afla dupa blocuri goale
    jne op_defragmentation_fileFound
    inc %ecx 
    jmp op_defragmentation_loop
op_defragmentation_fileFound:
    dec %ecx # ecx maxim 1022 aici, minim 0
    movb (%edi, %ecx, 1), %al # al zero
    cmpb $0, %al # verificam daca avem spatiu liber inainte
    je op_defragmentation_swap
    # am ajuns aici daca si v[i-1] = fileDescriptor => crestem i de 2 ori
    addl $2, %ecx # daca nu avem crestem ecx
    jmp op_defragmentation_loop
op_defragmentation_swap:
    # ne aflam la pozitia cu 0 in vector
    movb %dl, (%edi, %ecx, 1) # punem file descriptorul
    inc %ecx 
    movb %al, (%edi, %ecx, 1) # punem 0 (se ajunge la swap doar cand al==0)
    dec %ecx # pt cazul cu mai multe zerouri inainte
    jmp op_defragmentation_loop
op_defragmentation_exit:
    push %edi 
    call print_memory
    pop %edi
    pop %edi
    pop %ebp
    ret
main:
et_init:
    mov $v, %edi # aici tinem adresa array-ului
    xor %ecx, %ecx # initializam counter-ul cu 0 
et_loop_init:
    cmpl $1024, %ecx 
    je et_exit_init
    movb $0, (%edi, %ecx, 1) # alocam doar un spatiu de un byte (8kB in enunt)
    inc %ecx 
    jmp et_loop_init
et_exit_init:
    # aici s-au initializat toate blocurile din memorie cu 0
    # (de la 0 la 1023)
    jmp et_read
et_read:
    push $operationsCount # citesc nr de operatii
    push $formatReadInt
    call scanf
    add $8, %esp # golesc stiva cu 2 pop-uri
    xor %ecx, %ecx # initializez counter-ul pt operatii
et_read_loop:
    cmpl operationsCount, %ecx 
    je et_exit
    push %ecx # salvez counter-ul pt operatii in stiva pt a ii restaura val modificata de scanf
    push $operationCode 
    push $formatReadInt
    call scanf 
    add $8, %esp # golesc stiva cu 2 pop-uri
    cmpl $1, operationCode
    je et_add
    cmpl $2, operationCode
    je et_get
    cmpl $3, operationCode
    je et_delete
    cmpl $4, operationCode 
    je et_defragmentation
et_add:
    push $addFilesCount # citesc nr de fisiere ce vor fi adaugate
    push $formatReadInt
    call scanf
    add $8, %esp 
    # initializez counter-ul pt fisiere
    xor %ecx, %ecx
et_add_loop:
    push %ecx # counter - ul pt fisiere
    cmpl addFilesCount, %ecx
    je et_add_exit
    push $fileDescriptor
    push $formatReadInt
    call scanf 
    add $8, %esp 
    push $fileSize 
    push $formatReadInt 
    call scanf
    add $8, %esp
    push fileSize 
    push fileDescriptor
    push $v 
    call op_add
    pop %edi
    add $8, %esp 
    pop %ecx 
    inc %ecx
    jmp et_add_loop
et_add_exit:
    pop %ecx # golesc stiva de counter-ul pt fisiere (nu mai avem nevoie de el)
    pop %ecx # restaurez counter-ul pt operatii
    inc %ecx 
    jmp et_read_loop
et_get:
    push $fileDescriptor
    push $formatReadInt
    call scanf 
    add $8, %esp 
    push fileDescriptor
    push $v
    call op_get
    add $8, %esp
et_get_exit:
    pop %ecx # restaurez counter-ul pt operatii
    inc %ecx
    jmp et_read_loop
et_delete:
    push $fileDescriptor
    push $formatReadInt
    call scanf 
    add $8, %esp 
    push fileDescriptor
    push $v
    call op_delete
    add $8, %esp
et_delete_exit:
    pop %ecx # restaurez counter-ul pt operatii
    inc %ecx 
    jmp et_read_loop
et_defragmentation:                     
    push $v 
    call op_defragmentation
    pop %edi              
et_defragmentation_exit:
    pop %ecx # restaurez counter-ul pt operatii
    inc %ecx 
    jmp et_read_loop
et_exit:
    pushl $0
    call fflush
    popl %eax
    mov $1, %eax 
    mov $0, %ebx 
    int $0x80