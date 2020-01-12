# Shabal

This is an archive of code related to the Shabal hash function. Shabal
was a candidate to the SHA-3 competition (made it to round 2). It was
especially fast on small 32-bit architectures in wide use at that time.
Like all other candidates that made it to round 2, no real flaw was
found in it, but since it was not selected for round 3, it did not
benefit from much scrutiny after 2011. Therefore, **this repository is
for research purposes only** and should not be used in deployed
applications.

[`shabal-tiny-20101011/`](shabal-tiny-20101011/) contains a set of
implementations of Shabal optimized for code size, for various platforms
(for instance, down to 416 bytes of code on 64-bit x86). The
implementations are very small but usable (they all follow a generic,
streamable API). Since this was in 2010, the choice of architectures
is a bit "old-style" as per today's standards (e.g. the ARM code is
for ARMv4T, while the popular embedded ARM cores of 2020 use ARMv6M
or ARMv7M).
