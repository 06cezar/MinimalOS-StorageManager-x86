.data 
    m: .space 0x00100000 # spatiul nostru de memorie ce va tine un array bidimensional de elemente de tip byte (1024x1024 bytes)
    # desi avand descriptori de la 1 la 255, putem avea maximum
    # 255 linii active (255 x 1024)
    # 1024x1024 = 16^5 = 1048576
    formatReadInt: .asciz "%d"
    formatReadPath: .asciz "%s"
    formatPrintf: .asciz "%d\n"
    formatPrintfstring: .asciz "%s\n"
    operationsCount: .space 4
    operationCode: .space 4          # va fi pus pe stiva deci ii alocam 4 bytes
    addFilesCount: .space 4
    formatPrintfAdd: .asciz "%d: ((%d, %d), (%d, %d))\n"
    formatPrintfGet: .asciz "((%d, %d), (%d, %d))\n"
    fileDescriptor: .space 4 # va fi pus pe stiva deci ii alocam 4 bytes
    fileSize: .space 4
    countBlocksNeeded: .space 4
    path: .space 1000 
    buffer: .space 1024
    dir_ptr: .space 4
    dirent_ptr: .space 4
    full_path: .space 10000
    SystemFileDescriptor: .space 4 # va fi pus pe stiva deci ii alocam 4 bytes
    dot: .asciz "."
    double_dot: .asciz ".."
.text 
.global main
print_memory:
    push %ebp 
    mov %esp, %ebp # setam base pointerul 
    push %edi 
    push %esi
    xor %ecx, %ecx # counter pentru a parcurge array-ul
    mov 8(%ebp), %edi # adresa array-ului
et_loop_print_memory:
    cmpl $0x00100000, %ecx 
    je et_exit_print_memory 
    xor %eax, %eax
    mov (%edi, %ecx, 1), %al # %al va contine elementul de la pozitia ecx din memorie
    mov %eax, fileDescriptor
    cmpb $0, %al
    je et_print_memory_increment
    # altfel avem un descriptor la pozitia ecx (salvat in al)
    mov %ecx, %edx # edx avem prima pozitie
et_loop_descriptor:
    cmpl $0x00100000, %ecx
    je et_printMemoryInterval
    cmpb %al, (%edi, %ecx, 1)
    jne et_printMemoryInterval
    inc %ecx 
    jmp et_loop_descriptor
et_print_memory_increment:
    inc %ecx 
    jmp et_loop_print_memory
et_printMemoryInterval:
    dec %ecx # (%edi, %ecx, 1) != descriptor, ca sa ajunga la eticheta asta
    # deci decrementam ecx
    push %ecx # salvam counterul in stiva
    push %edx # salvat in stiva
    movl %ecx, %eax 
    movl $1024, %esi
    xor %edx, %edx
    divl %esi
    pop %ecx # salvez in ecx pe edx din stiva (inainte de impartire)
    # = capatul din stg
    push %edx # capat din dreapta, coloana
    push %eax # capat din dreapta, linie = capat din stanga, linie
    movl %ecx, %eax 
    movl $1024, %esi
    xor %edx, %edx
    divl %esi
    push %edx # capat din stanga, coloana
    push %eax # capat din stanga, linie = capat din dreapta, linie
    push fileDescriptor
    push $formatPrintfAdd # acelasi format ca la afisul de la add
    call printf 
    add $24, %esp
    pop %ecx # restauram counter-ul
    inc %ecx
    jmp et_loop_print_memory

et_exit_print_memory:
    pop %esi
    pop %edi 
    pop %ebp
    ret
op_add:
    push %ebp 
    mov %esp, %ebp # pun base pointer-ul
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
    cmpl $1024, %eax 
    jg op_add_memory_error # daca avem dimensiuni mai mari de 8192 kB => nu poate fi stocat
    mov %eax, countBlocksNeeded # pt ambele cazuri mutam in
    # countBlocksNeeded catul, singura diferenta e ca
    # afaugam 1 daca restul e nenul
    mov 12(%ebp), %eax # al va contine descriptorul
    xor %ecx, %ecx # counter pt a parcurge vectorul
    mov 20(%ebp), %ecx # !!! ultimul argument al functiei add = 
    # pozitia de unde incepem sa cautam! 
    # 0 pt add, !!! pt defrag de unde trebuie sa adaugam
    # (dupa fila de dinainte, pt a pastra ordinea)
    # (descriptorul de dinainte, pastrandu-se ordinea)
op_add_search_loop: 
    cmpl $0x00100000, %ecx
    je op_add_memory_error
    # daca ajungem pana la final si nu gasim
    # niciun bloc cu memorie destula pt fisierul curent
    # inseamna ca memoria este plina, iar fisiere nu mai pot fi adaugate
    xor %ebx, %ebx
    movb (%edi, %ecx, 1), %bl # bl are 1 byte
    # il folosim pt a stoca elementul curent
    # din array
    cmpb $0, %bl
    jne op_add_searchIncrement
       # ajungem in acest scope cand am gasit un bloc
    # gol in memorie (v[ecx] = 0)
    xor %edx, %edx # <1024
     # deja am verificat ca (%edi, %ecx + $edx, 1) = (%edi, %ecx + 0, 1) = 0
    # un al doilea counter
    inc %edx
op_add_validateBlocks_loop:
    push %edx # edx counter de la 0 pana la nr de blocuri necesare
    cmpl countBlocksNeeded, %edx
    je op_addToMemory
    add %ecx, %edx # edx = pozitia elementului in array
    cmpl $0x00100000, %edx
    jge op_add_memory_error_pop
    cmpb $0, (%edi,%edx,1)
    jne op_add_searchIncrement_pop
op_add_verifyNewLine:
    movl %edx, %eax 
    xorl %ebx, %ebx 
    xorl %edx, %edx
    movl $1024, %ebx
    divl %ebx
    cmpl $0, %edx # edx contine restul = nr coloanei
    je op_add_pop_TryNewLine
    pop %edx
    inc %edx 
    jmp op_add_validateBlocks_loop
op_addToMemory:
    pop %edx
    add %ecx, %edx # edx devine capatul din dreapta al intervalului de afisat + 1
op_add_loop_addToMemory:
    cmpl %edx, %ecx 
    je op_add_print_addToStack
    xor %ebx, %ebx 
    mov 12(%ebp), %ebx # in bl se va gasi descriptorul
    movb %bl, (%edi, %ecx, 1) # mut descriptorul in memorie
    inc %ecx 
    jmp op_add_loop_addToMemory
op_add_searchIncrement_pop:
    pop %edx
op_add_searchIncrement:
    inc %ecx
    jmp op_add_search_loop
op_add_pop_TryNewLine:
    pop %edx # acest edx este multiplu de 1024, deci este primul element
    # de pe o linie noua (prima coloana), asta insemnand ca nu am avut destul loc
    # pe linia anterioara pt fisier
    # deci continuam cautarea de la acest edx
    addl %edx, %ecx
    jmp op_add_search_loop
op_add_print_addToStack:
    dec %edx 
    subl countBlocksNeeded, %ecx
    movl %edx, %eax 
    movl $1024, %ebx
    xor %edx, %edx
    divl %ebx
    # acum eax contine catul (linia), iar edx coloana
    push %edx # capatul din dreapta, coloana
    push %eax # capatul din dreapta, linia
    movl %ecx, %eax 
    xor %edx, %edx
    divl %ebx
    push %edx # capatul din stanga, coloana
    push %eax # capatul din stanga, linia
    movl 12(%ebp), %ebx  
    xorl %eax, %eax 
    movb %bl, %al
    push %eax # descriptorul
    jmp op_add_print
op_add_memory_error_pop:
    pop %edx
op_add_memory_error:
    push $0
    push $0
    push $0
    push $0
    movl 12(%ebp), %ebx  
    xorl %eax, %eax 
    movb %bl, %al
    push %eax
op_add_print:
    push $formatPrintfAdd
    call printf
    add $24, %esp 
    pop %ebx 
    pop %edi
    pop %ebp
    ret
op_get:
    push %ebp 
    mov %esp, %ebp # pun base pointer-ul
    push %edi 
    push %ebx
    push %esi 
    mov 8(%ebp), %edi # adresa vectorului
    xor %eax, %eax
    mov 12(%ebp), %eax # descriptorul de cautat se gaseste in al
    xor %ecx, %ecx 
op_get_search_loop:
    cmpl $0x00100000, %ecx 
    je op_get_print_not_found
    cmpb %al, (%edi,%ecx,1)
    jne op_get_increment
    # aici ajunge daca se gaseste fisierul in memorie
    # acum cautam prima si ultima sa aparitie
    mov %ecx, %ebx # in ebx vom avea prima val
    inc %ecx
op_get_search_last_loop:
    cmpb %al, (%edi,%ecx,1)
    jne op_get_update_last
    inc %ecx 
    jmp op_get_search_last_loop
op_get_increment:
    inc %ecx
    jmp op_get_search_loop
op_get_update_last:
    dec %ecx 
op_get_print_found:
    # ecx ultimul capat
    # ebx primul capat
    movl %ecx, %eax 
    movl $1024, %esi
    xor %edx, %edx
    divl %esi
    # acum eax contine catul (linia), iar edx coloana
    push %edx # capatul din dreapta, coloana
    push %eax # capatul din dreapta, linia
    movl %ebx, %eax 
    movl $1024, %esi
    xor %edx, %edx
    divl %esi
    # acum eax contine catul (linia), iar edx coloana
    push %edx # capatul din stanga, coloana
    push %eax # capatul din stanga, linia
    jmp op_get_print
op_get_print_not_found:
    push $0
    push $0
    push $0
    push $0
op_get_print:
    push $formatPrintfGet
    call printf 
    add $20, %esp
    pop %esi
    pop %ebx 
    pop %edi
    pop %ebp
    ret
op_delete:
    push %ebp 
    mov %esp, %ebp
    push %edi 
    mov 8(%ebp), %edi # adresa vectorului
    xor %eax, %eax
    mov 12(%ebp), %eax # descriptorul de cautat se gaseste in al
    xor %ecx, %ecx 
op_delete_search_loop:
    cmpl $0x00100000, %ecx 
    je op_delete_exit
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
    cmpl $0x00100000, %ecx 
    je op_delete_exit
    # avem descriptorul in vector
    movb $0, (%edi, %ecx, 1)
    inc %ecx
    jmp op_delete_loop
op_delete_increment:
    inc %ecx 
    jmp op_delete_search_loop
op_delete_exit:
    push %edi 
    call print_memory
    pop %edi 
    pop %edi
    pop %ebp
    ret
op_defragmentation:
    push %ebp 
    mov %esp, %ebp
    push %edi 
    mov 8(%ebp), %edi # adresa vectorului
    xor %ecx, %ecx 
    push %ebx
op_defragmentation_firstFile:
    cmpl $0x00100000, %ecx 
    je op_defragmentation_exit
    xor %al, %al
    xor %edx, %edx 
    movb (%edi, %ecx, 1), %dl # dl file descriptor (!=0)
    cmpb $0, %dl #  cautam blocuri ocupate ce se afla dupa blocuri goale
    jne op_defragmentation_firstFileFound
    inc %ecx 
    jmp op_defragmentation_firstFile
op_defragmentation_firstFileFound:
    xor %ebx, %ebx # counter pt nr de blocuri pe care il ocupa
    movb $0, (%edi, %ecx, 1) # adaugam 0 peste descriptor
    # ca sa il adaugam iarasi
    inc %ebx 
    inc %ecx
op_defragmentation_firstFileFound_loop:
    movb (%edi, %ecx, 1), %al 
    cmpb %al, %dl # dl e descriptorul curent
    jne op_defragmentation_firstFile_exit
    inc %ebx 
    movb $0, (%edi, %ecx, 1)
    inc %ecx
    jmp op_defragmentation_firstFileFound_loop
op_defragmentation_firstFile_exit:
    # calculez filesize
    push %edx 
    movl $8, %eax
    mull %ebx 
    pop %edx
    push $0 # prima fila gasita incercam sa o adaugam de la inceput
    push %eax # file size
    push %edx # file Descriptor
    push $m 
    call op_add
    pop %edi
    pop %edx 
    pop %eax
    pop %ecx
    jmp op_defragmentation_loop
op_defragmentation_loop:
    # prima oara caut unde s-a terminat descriptorul fisierului anterior
op_defragmentation_search_loop:
    cmpl $0x00100000, %ecx 
    je op_defragmentation_exit
    cmpb %dl, (%edi, %ecx, 1)
    je op_defragmentation_search_last_loop
    inc %ecx 
    jmp op_defragmentation_search_loop
op_defragmentation_search_last_loop:
    # am gasit deja unde se afla fisierul adaugat ultimul
    cmpb %dl, (%edi, %ecx, 1)
    jne op_defragmentation_search_last_exit
    inc %ecx 
    jmp op_defragmentation_search_last_loop
op_defragmentation_search_last_exit:
    push %ecx # va fi de unde incepem operatia add  (exact dupa descriptorul anterior)
op_defragmentation_File_loop:
    cmpl $0x00100000, %ecx 
    je op_defragmentation_exit_pop
    xor %eax, %eax
    xor %edx, %edx 
    movb (%edi, %ecx, 1), %dl # dl file descriptor (!=0)
    cmpb $0, %dl #  cautam blocuri ocupate ce se afla dupa blocuri goale
    jne op_defragmentation_FileFound
    inc %ecx 
    jmp op_defragmentation_File_loop
op_defragmentation_FileFound:
    xor %ebx, %ebx # counter pt nr de blocuri pe care il ocupa
    movb $0, (%edi, %ecx, 1) # adaugam 0 peste descriptor
    # ca sa il adaugam iarasi
    inc %ebx 
    inc %ecx
op_defragmentation_FileFound_loop:
    cmpl $0x00100000, %ecx 
    je op_defragmentation_exit
    movb (%edi, %ecx, 1), %al 
    cmpb %al, %dl # dl e descriptorul curent
    jne op_defragmentation_File_exit
    inc %ebx 
    movb $0, (%edi, %ecx, 1)
    inc %ecx
    jmp op_defragmentation_FileFound_loop
op_defragmentation_File_exit:
    # calculez filesize
    pop %ecx # restaurez ecx
    push %edx 
    movl $8, %eax
    mull %ebx 
    pop %edx
    push %ecx # de aici incep add-ul (pastrez astfel ordinea fisierelor)
    push %eax # file size
    push %edx # file Descriptor
    push $m 
    call op_add
    pop %edi
    pop %edx 
    pop %eax
    pop %ecx
    jmp op_defragmentation_loop
op_defragmentation_exit_pop:
    pop %ecx
op_defragmentation_exit:
    pop %ebx
    pop %edi
    pop %ebp
    ret
main:
et_init:
    mov $m, %edi # aici tinem adresa array-ului
    xor %ecx, %ecx # initializam counter-ul cu 0 
et_loop_init:
    cmpl $0x00100000, %ecx 
    je et_exit_init
    movb $0, (%edi, %ecx, 1) # alocam doar un spatiu de un byte (8kB in enunt)
    inc %ecx 
    jmp et_loop_init
et_exit_init:
    # aici s-au initializat toate blocurile din memorie cu 0
    # (de la 0 la 1024*1024 - 1)
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
    push %ecx # salvez ecx in stiva pt a ii restaura val modificata de scanf
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
    cmpl $5, operationCode 
    je et_concrete
    jmp et_exit
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
    push $0
    push fileSize 
    push fileDescriptor
    push $m 
    call op_add
    pop %edi
    add $12, %esp 
    pop %ecx 
    inc %ecx
    jmp et_add_loop
et_add_exit:
    pop %ecx 
    pop %ecx
    inc %ecx 
    jmp et_read_loop
et_get:
    push $fileDescriptor
    push $formatReadInt
    call scanf 
    add $8, %esp 
    push fileDescriptor
    push $m
    call op_get
    add $8, %esp
et_get_exit:
    pop %ecx
    inc %ecx
    jmp et_read_loop
et_delete:
    push $fileDescriptor
    push $formatReadInt
    call scanf 
    add $8, %esp 
    push fileDescriptor
    push $m
    call op_delete
    add $8, %esp
et_delete_exit:
    pop %ecx 
    inc %ecx 
    jmp et_read_loop
et_defragmentation:                     
    push $m
    call op_defragmentation
    pop %edi              
et_defragmentation_exit:
    pop %ecx 
    inc %ecx 
    jmp et_read_loop
et_concrete:
    push $path 
    push $formatReadPath 
    call scanf # citesc path-ul absolut al directorului
    add $8, %esp 
    # push $path # afisez - test
    # push $formatPrintfstring
    # call printf
    # add $8, %esp 
    # apelez opendir(path)          
    push $path                      
    call opendir                   
    add $4, %esp                  
    cmp $0, %eax # verific daca este nul
    je et_concrete_pathNotExistent
    mov %eax, dir_ptr  # salvez pointerul *DIR
    # verific daca path-ul are / la final
    mov $path, %eax    # incarc adresa path-ului
check_slash:
    xor %ecx, %ecx # counter pt a parcurge caracterele din string-ul path pana la gasirea
    # terminatorului de sir
check_last_char:
    movb (%eax, %ecx, 1), %bl # incarc in bl caracterul curent (1 byte)
    cmp $0, %bl  # verific daca este \0 (0 este codul ASCII pt terminatorul de sir)
    je append_slash                        
    inc %ecx # trec la urmatorul caracter
    jmp check_last_char

append_slash:
    dec %ecx # ma mut inapoi la ultimul caracter
    cmpb $47, (%eax, %ecx, 1) # verific daca este slash (47 este codul ASCII pt slash)
    je et_concrete_loop  # daca da, path-ul se termina deja cu '/'
    inc %ecx  # ma mut la terminatorul de sir
    movb $47, (%eax, %ecx, 1)
    inc %ecx  
    movb $0, (%eax, %ecx, 1)


et_concrete_loop:
    # apelez readdir(dir_ptr)
    mov dir_ptr, %eax      
    push %eax                     
    call readdir                 
    add $4, %esp                   
    cmp $0, %eax              
    je et_concrete_done                       
    mov %eax, dirent_ptr       
    # avem numele fisierului din struct-ul dirent
    # compar numele fisierului cu . (director curent)
    mov dirent_ptr, %eax        
    add $11, %eax  # pointer pentru campul d_name
    push $dot        
    push %eax                      
    call strcmp # compar string-urile
    add $8, %esp                   
    cmp $0, %eax              
    je et_concrete_loop                

    # compar numele fisierului cu ".." (directorul parinte)
    mov dirent_ptr, %eax  # pointer la struct-ul dirent
    add $11, %eax   # pointer pentru campul d_name
    push $double_dot               
    push %eax                      
    call strcmp                    
    add $8, %esp                   
    cmp $0, %eax              
    je et_concrete_loop     
    
    # daca s-a ajuns pana aici, avem un fisier valid (nu . sau ..)
    push $path
    push $full_path # copiez in full_path path-ul fisierului (o sa il modific la fiecare fisier cand apelez strcat)
    call strcpy
    add $8, %esp

    mov dirent_ptr, %eax    
    add $11, %eax # pointer pentru campul d_name
    push %eax   
    push $full_path 
    call strcat # apelez strcat pt a avea path-ul fisierului
    add $8, %esp 
    
    # push $full_path # afis full path pt fila
    # push $formatPrintfstring                
    # call printf                    
    # add $8, %esp 

    # aici avem path-ul full al fisierului, scris corect
et_concrete_getFileDescriptor:
    push $0 # flag-ul O_RDONLY
    push $full_path                             
    call open                           
    add $8, %esp                    
    cmp $0, %eax             
    jl et_concrete_loop  # Daca da eroare (negativ), trec peste aceasta fila
    mov %eax, %ebx # Salvez file descriptor-ul in %ebx
    mov %ebx, SystemFileDescriptor
    # push %ebx
    # push $formatPrintf # afisez file descriptorul dat de sistem ( dar o sa il folosesc pe cel cu modulo)
    # call printf
    # add $8, %esp
et_concrete_computeFileDescriptor:
    mov SystemFileDescriptor, %eax # calculez descriptorul dat de sistem % 255 + 1
    mov $255, %ebx
    xor %edx, %edx # golesc edx pt impartire 
    div %ebx 
    inc %edx # in %edx se afla SystemFileDescriptor % 255
    # deci il incrementam
    mov %edx, fileDescriptor
    push %edx
    push $formatPrintf # afisez file descriptorul calculat
    call printf
    add $8, %esp
et_concrete_getFileSize:
    # adresa stat bufferului
    mov SystemFileDescriptor, %ebx
    push $buffer
    push %ebx # file descriptorul dat de sistem
    call fstat     
    add $8, %esp                     
    cmp $0, %eax                     
    jl et_concrete_loop # -1 semnaleaza o eroare (putem folosi si sign flag)                  

    mov $buffer, %eax 
    add $44, %eax # dimensiunea fisierului din st_size (pt 32 biti)
    mov (%eax), %eax # dereferentiez
    xor %edx, %edx # pt impartire
    mov $1024, %ebx 
    div %ebx # aflu nr de Kb pe care il are fisierul (rounded down)
    # fsize ne este dat in B
    mov %eax, fileSize
    push %eax # afisez size-ul fisierului in kB
    push $formatPrintf
    call printf 
    add $8, %esp    
    # aici verific daca avem deja in memorie descriptorul calculat
    xor %ecx, %ecx # counter pt a parcurge memoria
    xor %eax, %eax
    mov fileDescriptor, %eax # se va afla in al
et_concrete_get_loop:
    cmpl $0x00100000, %ecx 
    je et_concrete_addFile # file descriptorul nu este deja in memorie
    cmpb %al, (%edi,%ecx,1)
    je et_concrete_DescriptorAlreadyFound
    inc %ecx 
    jmp et_concrete_get_loop
et_concrete_DescriptorAlreadyFound:
    push $0
    push $0
    push $0
    push $0    
    push fileDescriptor
    push $formatPrintfAdd # daca un descriptor calculat se repeta, afisez fd: ((0, 0), (0, 0))
    # si nu il mai adaug in memorie
    call printf 
    add $24, %esp
    jmp et_concrete_loop
et_concrete_addFile:
    push $0 # pozitia in array de unde incepe cautarea de spatiu liber pentru fisier
    push fileSize 
    push fileDescriptor
    push $m 
    call op_add # apelez add pt fila din memorie cu descriptorul calculat
    pop %edi
    add $12, %esp 
    jmp et_concrete_loop
et_concrete_pathNotExistent:
et_concrete_done:
    pop %ecx 
    inc %ecx
    jmp et_read_loop
et_exit:
    pushl $0
    call fflush
    popl %eax
    mov $1, %eax 
    mov $0, %ebx 
    int $0x80