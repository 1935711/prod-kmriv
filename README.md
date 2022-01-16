# Bootsector Demo
A demo which fits into a boot sector.

## Physarum Polycephalum Simulation
Also known as 'slime mold', is a yellow organism forming a network of interlaced tubes. It's global goal is to search as much area as possible while keeping the overall length of tube as low as possible.

In order to simulate this organism, we can form 2 maps, one describing the discrete state of each agent and another describing the continuus map of the trails (more formally chemotactic stimuli) that the agents both deposit and follow.

The state of every agent is simply:
- Position (2D vector).
- Heading Angle (in radians).

The simulation itself proceeds like this:
1. **Sense** = Measure the concentration of trails ahead to find the angle relative to the heading in which there is a highest trail concentration.
2. **Rotate** = Change of heading angle based on the sensed value.
3. **Move** = Agent moves in the heading direction but will avoid collisions through smallest possible change in heading angle (if a collision can be avoided to the left and right with equal length, the direction chosen is random).
4. **Deposit** = At the new position of the agent, a fresh trail is left in the trail map.
5. **Diffuse** = A mean filter is applied on the trail map to simulate the trails spreading out.
6. **Decay** = The trail map is multiplied (element-wise) by some number 0 < n < 1 to simulate the trail slowly dissipating over time.
7. Repeat.

All the details mentioned above can be found in the original [paper](https://uwe-repository.worktribe.com/output/980579).

## Instructions
The assembler used is [FASM](http://flatassembler.net/) and the makefile can be
run on both Windows (under MinGW32) and Linux.
1. Run `make` on Linux or `mingw32-make` on Windows.
2. Run `make run` on Linux or `mingw32-make run` on Windows to run bootsector in QEMU. This of course requires QEMU to be installed (get it from https://www.qemu.org/download/).