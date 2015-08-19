#!/usr/bin/env python3

import websockets
import asyncio
import time

# import logging
# logger = logging.getLogger('websockets')
# logger.setLevel(logging.DEBUG)
# logger.addHandler(logging.StreamHandler())

VARS = ["v.atmosphericDensity", "v.dynamicPressure",
      "v.altitude", "v.heightFromTerrain", "v.terrainHeight",
      "n.pitch", "n.heading", "n.roll",
      "f.throttle",
      "v.sasValue", "v.lightValue", "v.brakeValue", "v.gearValue",
      "v.surfaceSpeed", "v.verticalSpeed",
      "v.surfaceVelocityx", "v.surfaceVelocityy", "v.surfaceVelocityz",
      "rpm.available",
      "rpm.ATMOSPHEREDEPTH","rpm.EASPEED","rpm.EFFECTIVETHROTTLE",
      "rpm.ENGINEOVERHEATALARM", "rpm.GROUNDPROXIMITYALARM", "rpm.SLOPEALARM",
      "rpm.RADARALTOCEAN", "rpm.ANGLEOFATTACK", "rpm.SIDESLIP",
      "rpm.PLUGIN_JSIFAR:GetFlapSetting", "rpm.TERMINALVELOCITY", "rpm.SURFSPEED"]

@asyncio.coroutine
def testws():
    websocket = yield from websockets.connect('ws://192.168.1.73:8085/datalink')
    yield from websocket.send('{"+": [' + ",".join('"' + x + '"' for x in VARS) + ']}')
    start = time.time()

    while True:
      message = yield from websocket.recv()
      if message is None:
        break
      print(str(time.time()-start) + "    " + message)

asyncio.get_event_loop().run_until_complete(testws())