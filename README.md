KerbalHUD
=========

Implements an RPM-style flight hud in swift 2.0 for runnning on iOS devices.
This means that it requires a minimum of Xcode 7, along with some method of
getting it onto your device.

Requires:

- Telemachus

However, for the full HUD the mod currently requires by custom build of
telemachus; https://github.com/ndevenish/Telemachus, which adds support
for accessing RasterPropMonitor variables directly via the Telemachus API.
This obviously adds a dependency on RasterPropMonitor. Without these, it should
run fine but with limited data (e.g. angle of attack and slip angle is pulled
from RPM).

For the FAR flaps setting visibility, a version of RasterPropMonitor > v0.22.0
is required. At time of writing, this is the development version as a small
patch has been merged to make it easier to extract that information. Obviously
FAR and a plane with flaps would also be needed.

As far as compatibility and efficiency, I've tested on a 1st Gen iPad mini and
it works fine, but claim no expertise or even that the OpenGL code is a good
and efficient implementation. It seems to work well enough though.

Configuration
-------------

There is no run-time configuration at the moment. The address that it uses to
connect is currently hardcoded; currently at `GameViewController.swift:60`.
The instrument displayed is determined by `GameViewController.swift:124`, but
this is only really the plane HUD at the moment.

Without a connection, it will run with some contrived test data.

Future Plans
------------
There is the start of work on a NavUtilities screen (http://forum.kerbalspaceprogram.com/threads/85353-1-0-2-NavUtilities-ft-HSI-Instrument-Landing-System-v0-5-1-RC-1-*June-2015*) but this is only visual
and doesn't pull any data out yet.

Otherwise, more screens/configurability would be nice. I only really use the 
RPM hud at the moment, so don't know which screens would be useful, for myself
or for other people.
