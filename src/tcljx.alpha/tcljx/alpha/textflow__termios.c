#include <stddef.h>
#include <stdio.h>
#include <termios.h>
#include <unistd.h>

#define def_offset(X) printf("(def offsetof-" #X " %ld)\n", offsetof(struct termios, X))
#define def_int(X) printf("(def " #X " 0x%x)\n", X)
#define def_hex(X) printf("(def " #X " 0x%x)\n", X)

/* based on https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html */
/* also see "man termios" */
int main() {
  printf("(ns tcljx.alpha.textflow__termios)\n");
  printf("\n");
  printf("(def sizeof-struct %ld)\n", sizeof(struct termios));
  printf("(def alignof-struct %ld)\n", __alignof__(struct termios));
  /* def_offset(c_iflag); */
  /* def_offset(c_oflag); */
  /* def_offset(c_cflag); */
  /* def_offset(c_lflag); */
  /* def_offset(c_line); */
  printf("\n");
  def_int(STDIN_FILENO);
  def_int(TCSAFLUSH);
  printf("\n");
  /* printf(";;; c_iflag:\n"); */
  /* def_hex(BRKINT); */
  /* def_hex(INPCK); */
  /* def_hex(ISTRIP); */
  /* def_hex(ICRNL); */
  /* def_hex(IXON); */
  /* printf(";;; c_oflag:\n"); */
  /* def_hex(OPOST); */
  /* printf(";;; c_cflag:\n"); */
  /* def_hex(CS8); */
  /* printf(";;; c_lflag:\n"); */
  /* def_hex(ISIG); */
  /* def_hex(ICANON); */
  /* def_hex(ECHO); */
  /* def_hex(IEXTEN); */
  return 0;
}
