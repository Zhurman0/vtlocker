# vtlocker

---

VTLocker is a minimal PAM‑based login program designed to replace getty on a
dedicated /dev/ttyN.  
It runs the terminal in VT_PROCESS mode, intercepts and
controls VT switch signals, blocks unauthorized VT changes, and provides a
raw‑TTY authentication UI with centered ANSI prompts.  
Input is handled via epoll in noncanonical mode, with password masking and
automatic retry on authentication failure.  
Suitable as a replacement for graphical lockscreen programs on dedicated VTs.

---

## Usage

```
vtlocker [TTY] [options]

TTY:  Virtual console number to activate (1..63)
      If omitted, vtlocker works on the current console

Options:
  -m / --mask CHAR      Mask character for password input (Default: none)
  -h / --help           Show help message
```

## Install

### Dependencies:
 - zig 0.16.x
 - libpam

### Build:

```
zig build install -Doptimize=ReleaseSmall
```
---

### Run:

- As a program:
```
vtlocker 6
```

- Replace getty:  
Modify your `/etc/inittab` to replace:  
`tty6::respawn:/sbin/getty 38400 tty6`  
with:  
`tty6::respawn:/usr/bin/vtlocker`

// but underlying logic is not implemented yet
