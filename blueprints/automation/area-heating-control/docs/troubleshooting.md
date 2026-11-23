# Troubleshooting

Start with [Diagnostics](#diagnostics) to see what the automation decided, then look up the symptom
under [Common problems](#common-problems).

## Diagnostics

### Traces

Every run is recorded in the automation's **Traces** (open the automation, then ⋮ → **Traces**).
The trace shows the trigger and all calculated variables, such as `level`, `target_temperature`,
`area_off_reason` and the planned `tasks`. A run that ends with *Nothing to do* found all
thermostats already in the wanted state.

### Log and event

Every run that changes something writes one log entry and fires one event.

The log entry goes to the logger `blueprints.mxstzdev.area_heating_control`, at the level set in
the automation's *Log level* input (default `info`). Home Assistant only shows `warning` and above
by default, so lower the logger's level to see the entries:

```yaml
logger:
  logs:
    blueprints.mxstzdev.area_heating_control: debug
```

The event `area_heating_control_event` carries the same information, and can be watched in
**Developer tools → Events** or used in your own automations:

| Field | Meaning |
| ----- | ------- |
| `automation_id` | The automation that ran |
| `trigger_id` | What started the run, for example `reconcile_window_open` or `controller_setpoint` |
| `level` | `comfort`, `eco` or `away` |
| `target_temperature` | The temperature the area should have |
| `area_off_reason` | Why heating is off: `heating_system`, `outdoor`, `controller`, `windows`, or empty |
| `boost` | Whether a boost is active |
| `area_temperature` | Median of the temperature sensors, or of the room thermostats without sensors |
| `valves` / `controllers` | The radiator thermostats and room thermostats in use |
| `tasks` | The commands sent in this run |

### Templates

These templates show what the automation sees right now. Paste one into **Developer tools →
Template** and replace the ids in the first lines with the ones from your automation.

#### Schedules and PTO days

Shows whether today is a PTO day and why, which schedules are used, their state and next change,
and the level they give before persons, presence and vacation mode are applied:

```jinja
{% set schedules = ['schedule.living_room_heating'] %}
{% set pto_schedules = ['schedule.living_room_heating_pto'] %}
{% set workday_entity = 'binary_sensor.workday_sensor' %}
{% set pto_calendars = ['calendar.days_off', 'calendar.holidays'] %}
{% set workday_off = workday_entity != '' and is_state(workday_entity, 'off') %}
{% set calendars_on = pto_calendars | select('is_state', 'on') | list %}
{% set pto_day = workday_off or calendars_on | count > 0 %}
{% set use_pto = pto_day and pto_schedules | count > 0 %}
{% set used = pto_schedules if use_pto else schedules %}
Workday entity: {{ workday_entity ~ ' is ' ~ states(workday_entity)
                    if workday_entity else 'not set' }}
PTO calendars with an active event:
{%- for id in calendars_on %} {{ id }} ({{ state_attr(id, 'message') }}){% else %} none{% endfor %}
PTO day: {{ 'yes' if pto_day else 'no' }}
Used: {{ 'PTO schedules' if use_pto else 'schedules' }}
{% for id in used %}
- {{ id }}: {{ states(id) }}, next change {{ state_attr(id, 'next_event') or 'none' }}
{% endfor %}
Schedule level: {{ 'comfort' if used | select('is_state', 'on') | list else 'eco' }}
```

#### Temperature sensors

Lists the temperature sensors that auto-discovery uses, with your area id in the first line, and
flags readings above `limit` or more than `deviation` °C away from the median:

```jinja
{% set area = 'living_room' %}
{% set deviation = 3 %}
{% set limit = 30 %}
{% set ns = namespace(ids=[]) %}
{% for id in area_entities(area) | select('match', 'sensor[.]')
     | select('is_state_attr', 'device_class', 'temperature') %}
  {% set device = device_id(id) %}
  {% if states(id) | is_number
        and not (device and device_entities(device) | select('match', 'climate[.]') | list) %}
    {% set ns.ids = ns.ids + [id] %}
  {% endif %}
{% endfor %}
{% set values = ns.ids | map('states') | map('float') | list %}
{% set median = values | median if values else none %}
Median: {{ median }}
{% for id in ns.ids %}
{%- set value = states(id) | float %}
- {{ id }} ({{ device_attr(device_id(id), 'name') or 'no device' }}): {{ value }}
  {{- ' ⚠️ above ' ~ limit if value > limit
      else ' ⚠️ ' ~ deviation ~ ' °C off the median' if (value - median) | abs > deviation }}
{% endfor %}
```

## Common problems

### A thermostat is not controlled

- **It is not in the area.** Check the device's area in **Settings → Devices & services**. An entity
  with its own area overrides the area of its device.
- **It was unavailable.** Thermostats that are `unavailable` or `unknown` are skipped until they
  come back.
- **It was detected as the wrong type.** Thermostats with a target temperature range are treated as
  room thermostats, all others as radiator thermostats. Check the `valves` and `controllers` fields
  of the event. If one is wrong, select the thermostats explicitly in the automation.

### Heating stays off

Check `area_off_reason`:

| Reason | Cause | Fix |
| ------ | ----- | --- |
| `heating_system` | The heating system entity is off | Check the entity and the heating system delay |
| `outdoor` | The outdoor temperature is at or above the cutoff | Heating resumes below the cutoff minus the hysteresis |
| `controller` | A room thermostat is turned off | Turn the thermostat on again |
| `windows` | A window or door sensor is open | See below |

### An open door turns the heating off

Auto-discovery uses window **and** door sensors of the area. If a door should not count, select the
window sensors explicitly in the automation.

### A change on a thermostat is reverted or ignored

This is set by *Radiator thermostat input mode* and *Room thermostat input mode*, see
[Changes on thermostats](how-it-works.md#changes-on-thermostats). By default, changes on radiator
thermostats are kept only until the next change in the area, and changes on room thermostats apply
to the whole area until then. While heating is off, changes on room thermostats are reverted.

### The temperature does not follow the schedule

- **Presence or vacation mode wins.** A detected presence keeps the area at comfort, vacation mode
  keeps it at away, regardless of schedules.
- **Nobody is home.** With persons configured, a schedule only gives comfort while somebody is home.
  Use guest mode for guests without a `person`.
- **A temporary change is active.** A change on a room thermostat with *Temporary* lasts until the
  next change in the area, which can be the next schedule switch.
- **A PTO schedule is used.** With PTO schedules set, they replace the schedules while the workday
  entity is off or a PTO calendar has an active event. Workday is off on weekends by default. The
  log shows `pto_day=True` on such days, and the [schedules template](#schedules-and-pto-days)
  shows why. Check Workday's *Offset* option: with an offset, it describes another day than today.

### Calibration does not write anything

- **Calibration is off.** It is enabled by default; check that it was not turned off.
- **No calibration entity was found.** The thermostat's device needs an external temperature input
  or a `calibration` or `offset` number, see [Calibration](how-it-works.md#calibration). Entities are
  recognised by their entity id. If yours uses a different name, rename the entity id so that it
  contains one of the listed words, for example `number.living_room_trv_external_temperature`.
- **The difference is too small or too recent.** Offsets are only written if they change by at least
  the calibration delta and the last change is older than the calibration timeout.
- **There is no area temperature.** Without temperature sensors and room thermostats, there is
  nothing to calibrate against.

### The area temperature is wrong

Auto-discovery uses every temperature sensor in the area that does not belong to a thermostat,
including sensors that do not measure the room, such as the chip temperature of a Zigbee
coordinator. A few of them are enough to make the median implausible. The
[temperature sensors template](#temperature-sensors) finds them.

Keep the sensor out of the area temperature in one of these ways:

- **Exclude it:** add it to *Excluded temperature sensors*. The sensor stays available for
  everything else.
- **Disable it:** if you don't need the sensor at all, disable the entity in
  **Settings → Devices & services → Entities**. Disabled entities have no state and are skipped.
- **Select the sensors yourself:** under *Temperature sensors*, which turns off auto-discovery.

### Boost or the window input is not used natively

The thermostat's own boost preset, a boost switch and window inputs are recognised by their entity
ids, see [Windows](how-it-works.md#windows) and [Boost](how-it-works.md#boost). Rename the entity
id if yours is not found. Without a native option, boost uses the comfort temperature plus the
boost offset, and native window handling turns the thermostat off.

### Nothing happens after a restart

The *Startup delay* postpones the first run after a Home Assistant start. Changes during the delay
are applied once it ends.

## Limitations

The blueprint keeps no state of its own. It decides from the current states, so a few edge cases
are resolved by assumption:

- A window that was open for less than the open delay can still turn heating off for up to the close
  delay, if another event happens in that time.
- The heating system or the outdoor temperature end a temporary change on a room thermostat. An
  open window ends it only if *Room thermostat window behaviour* is *Follow*.
- If someone turns a room thermostat off while heating is already off for another reason, it is
  turned on again when that reason ends.
- Inside the outdoor hysteresis band, the area counts as warm outside while all its thermostats are
  off.
- External temperature inputs, window inputs and boost switches are recognised by their entity ids,
  since Home Assistant has no standard for them.

## Reporting a problem

Open an [issue](https://github.com/mxstzdev/home-assistant-blueprints/issues) with:

- the Home Assistant version and the blueprint version (the Version badge in its description);
- the automation's YAML (⋮ → **Edit in YAML**);
- the thermostat models and their integration, for example Zigbee2MQTT or ZHA;
- the trace of the run in question (⋮ → **Download trace**) or the matching log entries.
