# MinimalOS-StorageManager-x86
![Language](https://img.shields.io/badge/Language-x86%20Assembly-red)
![Syntax](https://img.shields.io/badge/Syntax-AT%26T-blue)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green.svg)

x86 Assembly (AT&amp;T syntax) implementation of a minimal operating system storage manager. Simulates a low-level file allocation subsystem supporting both linear (1D) and matrix (2D) memory layouts. Implemented as part of the Computer Architecture course, University of Bucharest.

## What it simulates

The storage device has a fixed capacity of 8 MB, split into 8 kB blocks. Each file is identified by a descriptor between 1 and 255, a block can only hold data from one file, and a file must be stored contiguously - if no free run of blocks is long enough, the file can't be stored.

To keep the simulation small, each 8 kB block is represented by a single byte holding the descriptor of the file that occupies it (`0` = free). A file of *S* kB therefore needs ⌈*S* / 8⌉ blocks.

| Version | File | Memory |
|---|---|---|
| 1D (linear) | `linear_storage_manager.s` | 1024 blocks in a line (8 MB / 8 kB) |
| 2D (grid) | `grid_storage_manager.s` | 1024 × 1024 blocks (8 MB in each direction); a file must fit inside a single row |

## Operations

| Code | Operation | 1D | 2D |
|:---:|---|:---:|:---:|
| 1 | **ADD** - place N files, each in the first free interval that fits | ✅ | ✅ |
| 2 | **GET** - return the interval occupied by a descriptor | ✅ | ✅ |
| 3 | **DELETE** - free a file's blocks and print the memory | ✅ | ✅ |
| 4 | **DEFRAGMENTATION** - compact the files, keeping their order | ✅ | ✅ |
| 5 | **CONCRETE** - fill the grid from real files in a directory | - | ✅ |

## How it works

**Allocation (ADD).** First-fit: the memory is scanned left to right (row by row in 2D) for the first run of free blocks that is long enough. In 2D a file can't wrap onto the next row, so if a free run would cross the end of a row, the search moves on to the next one. Files needing more than 1024 blocks are rejected up front in 2D, since they could never fit in a single row.

**Defragmentation** takes a different approach in each version:
- **1D:** done in place. Whenever an occupied block follows a free one, the two are swapped and the scan steps back, so every block slides left until it reaches the previous file.
- **2D:** the grid is scanned in row-major order; each file found is cleared and immediately re-inserted through the ADD routine, starting the search right where the previously moved file ended. This keeps the files in their original order and moves all the free space to the bottom-right of the grid.

**CONCRETE (2D only).** Reads a directory path (adding a trailing `/` if it's missing) and walks it with `opendir`/`readdir`, skipping `.` and `..`. Each file is opened with `open`, gets the descriptor `(fd % 255) + 1`, and its size is read with `fstat` (`st_size / 1024`, in kB). The program prints the computed descriptor and size, then adds the file exactly like ADD - unless that descriptor is already in the grid, in which case it prints `fd: ((0, 0), (0, 0))` and skips it. A directory that can't be opened, or files that can't be opened or `fstat`-ed, are skipped.

**Under the hood.** 32-bit x86 in AT&T syntax, linked against the C library (`printf`/`scanf`, plus `opendir`, `readdir`, `open`, `fstat`, `strcmp`, `strcpy`, `strcat` for CONCRETE). The routines follow the cdecl convention: arguments are pushed right to left, the caller cleans up the stack, and the callee-saved registers each routine uses (`ebx`, `esi`, `edi`) are saved and restored. Output is flushed with `fflush` before the program exits through the `exit` system call (`int $0x80`).

## Input and output

Input is read from standard input: the first line is the number of operations, followed by each operation code and its arguments, one value per line.

| Operation | Arguments | Output (1D) | Output (2D) |
|---|---|---|---|
| ADD | `N`, then `N` pairs: descriptor, size in kB | `fd: (start, end)` per file | `fd: ((startRow, startCol), (endRow, endCol))` per file |
| GET | descriptor | `(start, end)` | `((startRow, startCol), (endRow, endCol))` |
| DELETE | descriptor | every stored file, in ADD format | every stored file, in ADD format |
| DEFRAGMENTATION | - | every stored file, in ADD format | every stored file, in ADD format |
| CONCRETE | directory path | - | per file: descriptor, size, then ADD format |

Intervals are closed (both ends included). A file that can't be stored (ADD) or isn't found (GET) is reported with zero coordinates, e.g. `fd: (0, 0)`.

## Building and running

The programs are 32-bit, so a 64-bit Linux needs 32-bit support for gcc (on Debian/Ubuntu: `sudo apt install gcc-multilib`).

```bash
gcc -m32 linear_storage_manager.s -o linear -no-pie
gcc -m32 grid_storage_manager.s -o grid -no-pie

./linear < input.txt
./grid < input.txt
```

## Example (1D)

The sample case from the assignment - 4 operations: ADD five files, GET descriptor 121, DELETE descriptor 4, then DEFRAGMENTATION.

Input:
```
4
1
5
1
124
4
350
121
75
254
1024
70
30
2
121
3
4
4
```

Output:
```
1: (0, 15)
4: (16, 59)
121: (60, 69)
254: (70, 197)
70: (198, 201)
(60, 69)
1: (0, 15)
121: (60, 69)
254: (70, 197)
70: (198, 201)
1: (0, 15)
121: (16, 25)
254: (26, 153)
70: (154, 157)
```

## Known limitations

- **2D defragmentation, last-cell edge case:** if a file other than the first one found ends exactly in the last cell of the grid (row 1023, column 1023), the routine returns without popping a value it pushed earlier - the return address ends up wrong (most likely a crash) and that file is not re-inserted.
- **CONCRETE never closes what it opens** (no `close`/`closedir`). Since Linux always hands out the lowest free descriptor, every file gets a new one, so the computed IDs (`fd % 255 + 1`) keep increasing - the assignment's reference snippet closes each file, in which case they would repeat. A directory with more files than the open-file limit (commonly 1024) would also make later `open` calls fail, and those files would be skipped.
- **The directory path** is read with `scanf("%s")` into a 1000-byte buffer, so paths containing spaces aren't supported and the length isn't checked.

## License

[MIT](LICENSE)
