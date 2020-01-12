Compact Implementations of Shabal
=================================

This package contains some implementations of the Shabal hash functions.
These implementations are optimized for using little code space, while
still providing reasonable performance.

All the implementations follow the C-based API described in the
"shabal_tiny.h" header file. The implementations themselves are
located in the various subdirectories:

   amd64/              x86, 64-bit mode
   armeb/              ARM, big-endian (three variants)
   armel/              ARM, little-endian (three variants)
   avr8/               AVR, 8-bit
   i386/               x86, 32-bit mode
   mips32eb/           MIPS, 32-bit, big-endian
   mips32el/           MIPS, 32-bit, little-endian
   portable/           Portable C code
   portable_lowram/    Portable C code (slower and bigger, but uses less RAM)
   ppc32eb/            PowerPC, 32-bit, big-endian

Each implementation uses a single C or assembly file. The "armeb/" and
"armel/" directories contain three implementations each, corresponding
to variations on ARM and Thumb modes usage.


Please refer to the Shabal-tiny.pdf file for detailed explanations.


The test_shabal.c file is a test application, which can be compiled and
linked against any of the implementations; it runs test vectors (the
"short" test vectors from the NIST submission package) and perform some
speed measures. For instance, on a Linux x86 system in 64-bit mode,
you can compile and test the "amd64" implementation with these commands:

   gcc -W -Wall -O -c test_shabal.c
   gcc -c -o amd64.o amd64/shabal_tiny_amd64.s
   gcc -o tt1 amd64.o test_shabal.o
   ./tt1

The "size amd64.o" command would then print out the compiled size of
the Shabal implementation, as described in the Shabal-tiny.pdf file.

For the C-based implementations ("portable" and "portable_lowram"), you
would use these lines:

   gcc -W -Wall -O -c test_shabal.c
   gcc -W -Wall -I. -fomit-frame-pointer -Os -c -o portable.o \
       portable/shabal_tiny_portable.c
   gcc -o tt2 portable.o test_shabal.o
   ./tt2

Note the "-I." option (so that the "portable.c" file may include the
"shabal_tiny.h" file) and the use of optimization flags (such as "-Os").

The test application prints out bandwidth on a "long" message, expressed
in megabytes per second, then performance on "small" messages, expressed
in thousands of messages per second. A "small" message is any message of
length 0 to 511 bits; in practice, we use 32-byte messages.


LICENSE
=======

The following license text is included in all source files:

-----------------------------------------------------------------------
(c) 2010 SAPHIR project. This software is provided 'as-is', without
any epxress or implied warranty. In no event will the authors be held
liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to no restriction.

Technical remarks and questions can be addressed to:
<thomas.pornin@cryptolog.com>
-----------------------------------------------------------------------

In plain words, this is the closest possible to Public Domain which
still makes sense under French law (it seems that under French law, it
is not possible to put some code under Public Domain, except through
dying and then waiting for 70 or so years). The gist of the license is
the following: you can do whatever you want with the code, including
using, reusing, modifying, redistributing and so on, as long as you
accept that whatever happens is not my fault.
