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

## `nodemanager`

I'm turning off the `codemux` plugin that has been confirmed to be the cause for the slice re-creation problems we've experienced all along in the lxc build. 

I was not able to spot exactly what it is that is wrong with this plugin. What I was able to confirm though is that

* under f23, when codemux is at work, and a slice gets torn away, the cgroups area for that slice does not get properly cleaned up. 
* and that taking codemux out of the equation was bringing the f20 build up to speed entirely.

# previous releases

## `ipfw` 

 * turned off in builds from f21 and on

## `procprotect` 

* turned off in builds from f20 and on
## `fprobe-ulog`

* turned off in builds from f20 an on

