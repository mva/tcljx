module tcljx.alpha {
  requires transitive tcljc.core;

  exports tcljx.alpha.ptest;
  exports tcljx.alpha.ptest__align;
  exports tcljx.alpha.ptest__impl;
  exports tcljx.alpha.ptest__style;
  exports tcljx.alpha.textflow;
  exports tcljx.alpha.textflow__ansi;
  exports tcljx.alpha.textflow__insn;
  exports tcljx.alpha.textflow__pp;
  exports tcljx.alpha.textflow__table;
  exports tcljx.alpha.textflow__terminal;
  exports tcljx.alpha.textflow__termios;
  
  exports tcljx.alpha.pp.ansi;
  exports tcljx.alpha.pp.paragraph;
  exports tcljx.alpha.pp.recording;
  exports tcljx.alpha.pp.style;
  exports tcljx.alpha.pp.styled;
}
