Notes on modules that have been left behind while moving forward with the successive versinos of fedora

# Modules turned off in f23

## `liboml`

* See `Makefile` for details on this one

* many of our modules exhibited an issue (see details in Makefile) an empty `debugfiles.list`

* so to work around that I added this line to `header.spec`

#
            echo "%define debug_package %{nil}" >> $@

* Now with this in place `liboml` won't build anymore; I haven't tried *without* the patch yet with just `liboml`

* In any case to keep things simple and to move forward I am turning off liboml in the f23 builds and on.

# previous releases

## `ipfw` 

 * turned off in builds from f21 and on

## `procprotect` 

* turned off in builds from f20 and on
## `fprobe-ulog`

* turned off in builds from f20 an on

