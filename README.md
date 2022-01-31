# KMRIV Demo
It fits inside a boot sector!

## Physarum Polycephalum Simulation
Also known as 'slime mold', is a yellow organism forming a network of interlaced tubes. It's global goal is to search as much area as possible while keeping the overall length of tube as low as possible.

In order to simulate this organism, we can form 2 maps, one describing the discrete state of each agent and another describing the continuus map of the trails (more formally chemotactic stimuli) that the agents both deposit and follow.

The state of every agent is simply:
- Position (2D vector).
- Heading Angle (in radians).

The simulation itself proceeds like this:
1. **Sense** = Measure the concentration of trails ahead to find the angle relative to the heading in which there is a highest trail concentration.
2. **Rotate** = Change of heading angle based on the sensed value.
3. **Move** = Agent moves in the heading direction (collisions will be accepted here even though the original paper did not allow them).
4. **Deposit** = At the new position of the agent, a fresh trail is left in the trail map.
5. **Diffuse** = A mean filter is applied on the trail map to simulate the trails spreading out.
6. **Decay** = The trail map is multiplied (element-wise) by some number 0 < n < 1 to simulate the trail slowly dissipating over time.
7. Repeat.

All the details mentioned above can be found in the original [paper](https://uwe-repository.worktribe.com/output/980579).

The foundations of the demo are roughly based on the above but due to various modifications, they look nothing alike.

## Notes
- [This](https://web.archive.org/web/20211125233250/https://www.agner.org/optimize/) is a great resource for data-driven optimization of assembly, especially the per instruction latency, throughput (etc...) measurements.
- I did my best (where possible) to respect the intended purpose of the x86 registers (more on this [here](https://web.archive.org/web/20211127172355/https://www.swansontec.com/sregisters.html)).

## How To Build and Run
The assembler used is [FASM](http://flatassembler.net/) and the makefile can be
run on both Windows (under MinGW32) and Linux.
1. Run `make` on Linux or `mingw32-make` on Windows.
2. Run `make qemu-run` on Linux or `mingw32-make qemu-run` on Windows to run bootsector in QEMU. This of course requires [QEMU](https://www.qemu.org/) to be installed. Alternatively, the [bochs](https://bochs.sourceforge.io/) emulator can be used via the `bochs-run` task.

- To be able to get instruction listings, FASMs LISTING program is used. The source for this program are bundled with FASM but require manual compiling. In the FASM root dir at `TOOLS/WIN32/` is `LISTING.ASM` which includes some files from `INCLUDE/` and `INCLUDE/API/` (both inside FASMs root dir). While assembling with FASM, some of the included files may be reported as missing but really the include paths in `LISTING.ASM` assume all files in `INCLUDE/` are present in the same folder which they are not so it's a matter of modifying the paths. Lastly make sure the compiled LISTING program is in the root directory together with the main FASM executable so that the PATH environment variable doesn't need to be modified. The same goes for the SYMBOLS program (requires the exact same steps to build).

## Recording
I recorded the final demo according to this [wiki](https://trac.ffmpeg.org/wiki/Capture/Desktop).

1. `mingw32-make qemu-dbg` on Windows or `make qemu-dbg` on Linux to run the demo in such a way that QEMU stops execution at the beginning and waits for a GDB session to let it continue.
2. `gdb` then `target remote :1234` and `c` to continue.
3. `ffmpeg -framerate 60 -f gdigrab -i title="QEMU [Stopped]" -c:v libx264rgb -crf 0 -preset ultrafast output.mkv`
4. `ffmpeg -i output.mkv -c:v libx264rgb -crf 0 -preset veryslow output-smaller.mkv`
