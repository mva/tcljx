## Tiny Clojure Compiler

Impetus for this project was the wish for easier use of
[LWJGL](https://github.com/LWJGL/lwjgl3) classes, and to have a test
bed for features that [Project
Valhalla](https://openjdk.org/projects/valhalla/) may bring to the
JVM.  With Clojure's runtime classes and the JVM doing all the heavy
lifting, building a suitable compiler would surely be a limited
effort.  So I thought a few weeks after the release of JDK 9 and
before doing multiple iterations of the "tiny" compiler.

### How to use the thing

See [hello-tcljx](https://github.com/mva/hello-tcljx) for
prerequisites and basic usage.

### Kind of Clojure, but more static

Starting with a rather static view on Clojure source code, `tcljx`
produces concise and predictable byte code.  From this it recovers some
but not all of Clojure's more dynamic aspects.  This is not quite as
scary as it sounds, because the JVM is very dynamic machine on its
own.  The list of the good, the bad, and the ugly begins like this:

* Type hints act as type assertions.  They enforce the given type
  (instead of suggesting it), and they take effect at the point of
  declaration (instead of the point of use).  All primitive types are
  supported and they are supported everywhere.  The array type
  notation introduced with [Clojure
  1.12.0-alpha10](https://clojure.org/news/2024/04/28/clojure-1-12-alpha10)
  works, but I decided to drop the old notations.  That is, `^int/1`
  replaces both `^ints` and ```^"[I"``` and things like ```(new int/2
  3 5)``` and ```(instance? Object/1 x)``` work.

* Arithmetic resembles that of Java and is *not* a wrapper for
  `clojure.lang.Numbers`.  For example, binary `+` is always compiled
  to one of the `[ILFD]ADD` instructions, depending on the types of
  its primitive arguments.

* There is only auto-boxing and -unboxing for assignment situations,
  like passing an argument to a parameter or returning the value of a
  function arity.  For arithmetics conversion from reference to
  primitive view must be done manually, for example by writing `^int
  foo` (taking an `Integer` or one of its super types).

* Functions are implemented via [method
  handles](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/invoke/MethodHandle.html).
  `clojure.lang.IFn` still exists but is only a thin wrapper
  supporting the other `clojure.lang.*` classes.  Function compilation
  is often able to map individual arities to static methods, without
  any need to have a dedicated class holding the arity methods and
  representing the function itself.

* There is no runtime reflection.  If the compiler cannot resolve a
  method or field, then it will complain loudly.  Kind of
  `*warn-on-reflection*`, but always on.

* The compiler's symbol tables (globals, namespace aliases, imports)
  are not available during runtime.  As a consequence, there is no
  REPL, no `resolve`, no `macroexpand`, and so on.

* [...]

### Compiler Ancestry

`tcljx` is a rewrite of the prior compiler, called
[`tcljc`](https://github.com/mva/tcljc).  Its development setup uses
`tcljc` for the bootstrap compiler, although `tcljx` is capable of
hosting itself.  As for the name?  Naming is hard.  This started as an
experiment on top of an experimental compiler, and now it is the thing
to stay because I consider the experiment to be a success.

There were three ideas that went into this particular rewrite:

* Explore a very specific gap between Clojure's and Java's view on
  types.  Contrary to Java, this compiler interprets `void` as a
  polymorphic expression type.  Depending on the context, it turns
  into an actual value of a "real" type.  This can be the traditional
  choice of `nil`, or a primitive numeric zero, or the character zero,
  or the boolean `false`, or even Java's interpretation of `void`.
  And in the case of `throw`, `void` represents the situation that the
  whole operand stack is destroyed and control does not continue past
  this point.

* Push type adaption of any expression as far down into the code
  generation phase as possible.  That is, the difference between the
  typing rules of the input language and the typing rules of the JVM
  is only resolved at the very end, when actual bytecode is written.
  At this time a small and centralised set of code springs to life and
  does the necessary work.  There are no implicit type adaption nodes
  in the intermediate representation before this point.
  
* Put as much as possible of the intermediate representation into
  closures.  Technically, this is done via the local equivalent of
  lambda expressions and `reify`, but the idea is the same.  Closures
  save a lot of busy work when creating the intermediate
  representation, and they also makes it completely impossible to
  extract any data from the intermediate expression tree.  Everything
  is opaque, hidden, and out of reach.

The new compiler is in a surprisingly usable state, but some caveats
apply:

* It is in active use since around mid November 2025.  I was able to
  do all of Advent of Code 2025 with it, only finding four smallish
  bugs in the process, but a single user and a few weeks of time is
  not sufficient to get to a truly reliable code base.

* Names of core library namespaces have reverted back to `clojure.*`.
  While the difference between for example `clojure/core.clj` and
  `clojure/core.cljt` is larger than I would like, my experience up to
  now indicates that it is not likely to grow further in the future.

* Error messages are more terse than those of the predecessor
  compiler.  While I put some infrastructure in place to emit
  additional context specific information, for now errors are compact
  one liners with some styling to help readability.  On the other
  hand, this is the first of my compilers that has a dedicated
  framework for unit tests covering error reporting.

* Unlike `tcljc`, the current version is single-threaded.  I tried to
  anticipate stuff required to delegate both namespace processing and
  function compilation to virtual threads like before, but
  multi-threading has not been added yet.  Because it would need a
  truly huge code base for compilation time to become a nuisance,
  there is no pressing need to add it at this time.

### What the future may bring

The compiler is a vehicle for experiments, and it follows both the
development branch of [OpenJDK](https://github.com/openjdk/jdk) and to
a lesser degree upstream
[Clojure](https://github.com/clojure/clojure).

The JVM is rapidly adding features that are valuable even for non-Java
language implementations.  Over the past years the compiler made use
of [Dynamic Class-File Constants](https://openjdk.java.net/jeps/309),
[JVM Constants API](https://openjdk.java.net/jeps/334), [Virtual
Threads](https://openjdk.org/jeps/444), and [Class-File
API](https://openjdk.org/jeps/457) in their preview stage and
sometimes even before that.  I do not expect the pace of interesting
stuff to slow down.

The biggest item on the horizon is Valhalla.  Once it enters preview
(maybe in the course of ~~'24~~ ~~'25~~ '26?), I intend make any
additional type decorations available on the language level.  Both the
Class-File API and the new array type syntax may help with the
implementation.

The Clojure pipeline has also interesting things to offer.  Some of
this brings immediate benefits for `tcljx`, like the change to
`LazySeq` and `Delay` that was good for a compiler bootstrap speedup
of 1.05.  Other plans are more [far
reaching](https://clojure.org/news/2023/09/08/deref) and touch on
topics where `tcljx` already has an opinion on.  The goal is always to
close gaps between `tcljx` and Clojure proper as far as possible,
given the fact that one comes from the direction of "more static" and
the other from "more dynamic".  I'm not sure what will turn out to be
a good path here.

Whatever the future brings: I intend to have fun.  I hope you will
have fun as well!
