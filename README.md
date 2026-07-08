# vtlocker

---

VTLocker is a PAM‑based login program designed to replace getty on a
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
vtlocker [options]

Options:
  -m / --mask CHAR      Mask character for password input (Default: none)
  -h / --help           Show help message
```

## Install

### Dependencies:
 - zig 0.16.x
 - libpam
 - libc

### Build:

```
zig build install -Doptimize=ReleaseSmall
```
---

### Run:

- As a program:
```
sudo chvt 6
vtlocker
```

- Replace getty:  
Modify your `/etc/inittab` to replace:  
`tty6::respawn:/sbin/getty 38400 tty6`  
with:  
`tty6::respawn:/usr/bin/vtlocker`

## Roadmap

- Split project into 2 binaries:
  - `vtlock-switch`: uses setuid to change VT;
  - `vtlocker`: actually a locker.
- Make ui module/framework with smart redraw of characters
- Add screensavers (especially a DVD)
- Post on r/unixporn
