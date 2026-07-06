SRCDIR   := src
BUILDDIR := build
BINDIR   := bin

CC     := cc
CFLAGS := -Wall -Wextra -O2
LIBS   := -lpam -lpam_misc

PREFIX  := /usr/local
INSTALL := $(PREFIX)/bin/vtlocker

SRC    := $(wildcard $(SRCDIR)/*.c)
OBJ    := $(patsubst $(SRCDIR)/%.c,$(BUILDDIR)/%.o,$(SRC))
TARGET := $(BINDIR)/vtlocker

all: $(TARGET)

$(TARGET): $(OBJ)
	@mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) $(OBJ) -o $(TARGET) $(LIBS)
	strip $(TARGET)

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

install: $(TARGET)
	@mkdir -p $(PREFIX)/bin
	cp $(TARGET) $(INSTALL)
	chmod 755 $(INSTALL)

delete:
	rm -f $(INSTALL)

clean:
	rm -rf $(BUILDDIR) $(BINDIR)

.PHONY: all clean install uninstall
