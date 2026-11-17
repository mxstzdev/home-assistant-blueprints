# How it works

Each run evaluates the whole area and only sends commands to thermostats whose mode, target or
preset differs from the wanted state. In order of priority:

1. **Limescale protection** (radiator valves only): once a week, at the configured day and minute,
   all valves are set to their maximum temperature for one minute.
2. **Heating off**, for the first reason that applies:
   - the heating system is off;
   - it is warm outside: the outdoor temperature is at or above the cutoff. Heating resumes once it
     drops below the cutoff minus the hysteresis; in between, the current state is kept;
   - a wall controller was turned off: the whole area stays off until it is turned on again;
   - a window is open, handled as set in *Window open behaviour* (see below).

   Thermostats are turned off, or set to their minimum temperature if they have no off mode.
3. **Boost**, while active: radiator thermostats use their `boost` preset, a boost switch on the
   same device, or their maximum temperature, in that order.
4. The **level** temperature, clamped to each thermostat's range:
   - away while vacation mode is on;
   - comfort while the presence sensor detects someone;
   - away once nobody has been home for the away delay;
   - with schedules: comfort while any schedule is on and, if persons are configured, somebody is
     home, otherwise eco;
   - with persons or guest mode: comfort while somebody is home, otherwise eco;
   - otherwise: eco.

Reaction times (delays) apply to persons, presence, windows and the heating system. After a Home
Assistant restart, states that have not changed since the start count as settled, so the delays do
not start again.

## Windows

| Window open behaviour | Effect while a window is open |
| --------------------- | ----------------------------- |
| Off (default) | Thermostats are turned off, or set to their minimum temperature |
| Frost protection | Thermostats keep heating at the frost protection temperature (0: their minimum) |
| Native | The window state is sent to each thermostat's window input, and the thermostat reacts itself. Thermostats without one are turned off |

Wall controllers always get the window state on their window input, if they have one, so they can
show it. A window input is a `switch` or `select` on the thermostat's device whose id contains
`window_open`, `open_window` or `window_state`. Entities that only enable the device's own
detection (`detection`, `feature`, `function`, `enable`) are not used.

## Changes on thermostats

A change counts as manual when no automation made it: on the device itself or in the Home Assistant
UI. Changes that match the area target, such as a device confirming a command, are ignored.

| Setting | Radiator thermostats | Wall controllers |
| ------- | -------------------- | ---------------- |
| Ignore | Kept until the next change in the area (default) | |
| Read-only | Reverted at once | Reverted at once |
| Temporary | Kept for the hold duration or until the next change in the area | All thermostats follow it until the next change in the area (default) |
| Persistent | Written to the active comfort, eco or away entity | Written to the active comfort, eco or away entity |

"Persistent" falls back to "Temporary" if the active level has no entity. While heating is off,
changes on wall controllers are reverted. A change in the area is any event the blueprint reacts
to, such as a schedule, a person, a window or the heating system. Selecting the `boost` preset on a
wall controller boosts the whole area until the controller leaves the preset.

## Boost

A boost starts when the boost trigger turns on, or is pressed for an `input_button`, and lasts for
the boost duration. An `input_boolean` trigger is turned off again when the boost ends. While a
boost is active, heating off reasons still apply.

## Calibration

Calibration is off by default. When enabled, every 5 minutes and after a start or reload, each
radiator thermostat (and each wall controller, if temperature sensors exist) is made to use the area
temperature:

- If the thermostat's device has an **external temperature input** (a `number` whose id contains
  `external_temp`, `temperature_external`, `external_measured_room_sensor`,
  `external_sensor_temp` or `remote_temp`), the area temperature is written to it. Inputs with a
  maximum above 100 get 1/100 °C. A `select` on the device with an `external` option and `sensor`
  in its id is set to `external`. The input is refreshed every 30 minutes, because some devices fall
  back to their own sensor otherwise.
- Otherwise, a `number` whose id contains `calibration` (preferred) or `offset` is set to

  ```text
  new_offset = old_offset - (thermostat_temperature - area_temperature)
  ```

  clamped and rounded to the entity's range and step. It is only written if it changes by at least
  the calibration delta and the last change is older than the calibration timeout.

The area temperature is the mean of the temperature sensors, or of the wall controllers if there are
no sensors.
