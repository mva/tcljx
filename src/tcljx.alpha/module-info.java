module tcljx.alpha {
  requires transitive tcljc.core;

  exports tcljx.alpha.ptest;
  exports tcljx.alpha.ptest__impl;
  
  exports tcljx.alpha.pp;
  exports tcljx.alpha.pp.style;
  exports tcljx.alpha.pp.styled;
  exports tcljx.alpha.pp.ansi;
  exports tcljx.alpha.pp.buffer;
  exports tcljx.alpha.pp.paragraph;
  
  exports tcljx.alpha.pp.treetext;
  exports tcljx.alpha.pp.stringify;
  exports tcljx.alpha.pp.prettify;

  exports tcljx.alpha.pp.tokenize;
  exports tcljx.alpha.pp.diff;
  exports tcljx.alpha.pp.prettydiff;
}
