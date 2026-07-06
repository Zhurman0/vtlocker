# linux-vtlocker

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

## Install

### Dependencies:
 - linux-headers (build)
 - linux-pam-dev (build)
 - libpam

### Build:

```
make
sudo make install
```

### Run:

- As a program:
```
chvt 6
vtlocker
```

- Replace getty:  
Modify your `/etc/inittab` to replace:  
`tty6::respawn:/sbin/getty 38400 tty6`  
with:  
`tty6::respawn:/usr/bin/vtlocker`

## Roadmap

- Rewrite to zig 0.16
- Make ui as separate module with logic improvements
- Screensavers (especially DVD)
- Configuration through arguments
- Post on r/unixporn
