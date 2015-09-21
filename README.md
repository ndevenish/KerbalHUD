KerbalHUD
=========

Implements an RPM-style flight hud in swift 2.0 for runnning on iOS devices.
This means that it requires a minimum of Xcode 7, along with some method of
getting it onto your device.

Requires currently:

- Telemachus; Custom build from http://github.com/ndevenish/Telemachus/tree/wsredo
- RasterPropMonitor

Where the custom changes for telemachus are currently in the process of being 
reviewed and included in the main branches.

In principle the RPM dependency could be eased out down the line by e.g. not
requiring any of the variables, but at the moment the supported instruments
require quite a few RPM variables.

For the FAR flaps setting visibility, a version of RasterPropMonitor > v0.22.0
is required.

As far as compatibility and efficiency, I've tested on a 1st Gen iPad mini, an
iPhone 5 and an iPad mini 4 and it works fine, but claim no expertise or even
that the OpenGL code is a good and efficient implementation. It seems to work
well enough though.

Configuration
-------------

There is no run-time configuration at the moment. The address that it uses to
connect is currently hardcoded; currently at `GameViewController.swift:60`.

Without a connection, it will run with some contrived test data.

Future Plans
------------
More screens/configurability would be nice. A lot of the infrastructure for
reading external displays, or even reading RPM definitions directly are in place,
but this is still in very early stages.

A proper interface with configurable kerbal connections would be very useful.

Current status
--------------
- Multiple simultaneous instruments, zoomable to fullscreen based on touch
- RPM Plane HUD 
- RPM NavBall - spherical texture created on the fly at full resolution
- Navutilities HSI
- Pretty flexible text layout from arbitrary variables
- SVG-based overlays/images

![Navball Display](Screenshot_navball.png?raw=true "Navball Display")
![Plane HUD](Screenshot_plane.png?raw=true "Plane HUD")