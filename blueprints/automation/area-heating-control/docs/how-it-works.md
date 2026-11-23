# How it works

Each run evaluates the whole area and only sends commands to thermostats whose mode, target or
preset differs from the wanted state. In order of priority:

1. **Limescale protection** (radiator valves only): once a week, at the configured day and minute,
   all valves are set to their maximum temperature for one minute.
2. **Heating off**, for the first reason that applies:
   - the heating system is off;
   - it is warm outside: the outdoor temperature is at or above the cutoff. Heating resumes once it
     drops below the cutoff minus the hysteresis; in between, the current state is kept. The outdoor
     temperature sensor is used first, the weather entity while the sensor has no valid value;
   - a room thermostat was turned off: the whole area stays off until it is turned on again;
   - a window is open, handled as set in *Window open behaviour* (see below). Room thermostats keep
     heating at the area target unless *Room thermostat window behaviour* is *Follow*.

   Thermostats are turned off, or set to their minimum temperature if they have no off mode.
3. **Boost**, while active: radiator thermostats use their `boost` preset, a boost switch on the
   same device, or the comfort temperature plus the boost offset (at most their maximum
   temperature), in that order.
4. The **level** temperature, clamped to each thermostat's range:
   - away while vacation mode is on;
   - comfort while the presence sensor detects someone;
   - away once nobody has been home for the away delay;
   - with schedules: comfort while any schedule is on and, if persons are configured, somebody is
     home, otherwise eco. On PTO days (workday entity off, or a PTO calendar with an active event),
     the PTO schedules are used instead, if any are set;
   - with persons or guest mode: comfort while somebody is home, otherwise eco;
   - otherwise: eco.

   Eco and away are calculated from the comfort temperature, see [Temperatures](#temperatures).

## Temperatures

Only the comfort temperature needs to be set. The other temperatures follow it:

| Level | Temperature | Default (comfort 22 °C) |
| ----- | ----------- | ----------------------- |
| Comfort | Comfort temperature entity, or the comfort temperature | 22 °C |
| Eco | Comfort − eco offset, at least 16 °C, never above comfort | 19 °C |
| Away | Comfort − away offset, at least 15 °C, never above comfort | 17 °C |
| Boost | Comfort + boost offset, at most the thermostat's maximum. Only without a native boost | 25 °C |

An eco or away temperature entity with a valid state overrides the calculated value. Changing the
comfort temperature entity updates all calculated levels at once.
Reaction times (delays) apply to persons, presence, windows and the heating system. After a Home
Assistant restart, states that have not changed since the start count as settled, so the delays do
not start again.

## Windows

A window counts as open while a window or door sensor is `on`, `open` or `tilted`. *Window
sensors* and *Door sensors* each use the area's sensors of that device class while empty, so a
balcony door in the area counts without further setup. *Additional door and window sensors*, for
example of an adjacent hallway, count on top of them with the same delays. *Excluded door and window
sensors* never count.

| Window open behaviour | Effect while a window is open |
| --------------------- | ----------------------------- |
| Off (default) | Thermostats are turned off, or set to their minimum temperature |
| Frost protection | Thermostats keep heating at the frost protection temperature (0: their minimum) |
| Native | The window state is sent to each thermostat's window input, and the thermostat reacts itself. Thermostats without one are turned off |

The window open behaviour applies to radiator thermostats. Room thermostats follow *Room thermostat
window behaviour*:

| Room thermostat window behaviour | Effect while a window is open |
| -------------------------------- | ----------------------------- |
| Ignore (default) | The room thermostat keeps heating at the area target, and changes on it are applied as usual. Its window input is kept closed |
| Follow | The room thermostat reacts like the radiator thermostats, and always gets the window state on its window input, so it can show it |

With *Ignore*, opening or closing a window does not end a temporary change on a room thermostat.
Radiator thermostats resume at that temperature once all windows are closed.

A window input is a `switch` or `select` on the thermostat's device whose id contains
`window_open`, `open_window` or `window_state`. Entities that only enable the device's own
detection (`detection`, `feature`, `function`, `enable`) are not used, except on models whose
`window_detection` entity puts the thermostat into window open mode: Bosch room thermostat II
(`BTH-RM`, `BTH-RM230Z`).

## Changes on thermostats

A change counts as manual when no automation made it: on the device itself or in the Home Assistant
UI. Changes that match the area target, such as a device confirming a command, are ignored.

| Input mode | Radiator thermostats | Room thermostats |
| ---------- | -------------------- | ---------------- |
| Temporary | Kept until the next change in the area (default) | All thermostats follow it until the next change in the area |
| Read-only | Reverted at once, child lock on | Reverted at once, child lock on |
| Persistent | | Saved as the new temperature of the active level (default) |

"Persistent" writes to the active level's temperature entity. For a calculated eco or away level,
it writes to the comfort temperature entity instead, as the change plus the offset, so the
calculated level matches the change (the floor still applies). Without a matching entity, it falls
back to "Temporary". In read-only mode, the
child lock of the thermostat's device is turned on, if it has one: a `lock` or `switch` whose id
contains `child_lock`, `childlock` or `child_protection`. In the other modes, the child lock is
turned off when the automation is reloaded, for example after saving it, and left alone
otherwise. While heating is off,
changes on room thermostats are reverted, except while only a window is open and *Room thermostat
window behaviour* is *Ignore*. A change in the area is any event the blueprint reacts
to, such as a schedule, a person, a window or the heating system. Selecting the `boost` preset on a
room thermostat, or turning on a boost switch on its device, boosts the whole area until the
thermostat leaves the preset or the switch turns off.

## Boost

A boost starts when the boost trigger turns on, or is pressed for an `input_button`, and lasts for
the boost duration. An `input_boolean` trigger is turned off again when the boost ends. While a
boost is active, heating off reasons still apply.

A boost can also start on the room thermostat, see [Changes on thermostats](#changes-on-thermostats).
With a room thermostat in the area, it is the room's input: a boost started on a single radiator
thermostat is not passed on to the area, and it ends with the next change in the area.

## Calibration

Calibration is on by default. Every 5 minutes and after a start or reload, each
radiator thermostat (and each room thermostat, if temperature sensors exist) is made to use the area
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

The area temperature is the median of the temperature sensors, or of the room thermostats if there
are no sensors. Sensors of a room thermostat and excluded temperature sensors are never used as
temperature sensors. Without sensors and room thermostats, calibration is skipped. Each thermostat
gets at most its own maximum temperature (`max_temp`), even if the area is warmer.
