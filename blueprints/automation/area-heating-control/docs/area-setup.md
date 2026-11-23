# Setting up an area

This guide walks through one area, from assigning devices to a working automation. Repeat it for
every room you want to heat. Only the area itself is required; every other step is optional and can
be added later.

## 1. Assign devices to the area

The blueprint finds most entities through the area, so assign them first in
**Settings → Areas, labels & zones**, or on each device's page. An entity belongs to an area if
the entity itself or its device is assigned to it.

| Device | Found automatically as |
| ------ | ---------------------- |
| Radiator thermostats (TRVs) | `climate` entities with a single target temperature |
| Room thermostats | `climate` entities with a target temperature range |
| Room temperature sensors | `sensor` entities with device class `temperature` that are not part of a thermostat |
| Window sensors | `binary_sensor` or `sensor` entities with device class `window` |
| Door sensors | `binary_sensor` or `sensor` entities with device class `door` |

If auto-discovery picks up something you do not want, select the wanted entities explicitly in the
automation. A selection replaces the auto-discovery for that input only. To drop a single sensor,
for example a wardrobe door, add it to *Excluded door and window sensors* instead. Door and window
sensors of adjacent areas, for example the front door in the hallway, go into *Additional door and
window sensors*; they count without replacing the auto-discovery.

## 2. Create helpers

Create helpers in **Settings → Devices & services → Helpers → Create helper**. All of them are
optional: without helpers, the blueprint uses the static values of its inputs.

### Temperatures

Eco, away and boost temperatures are calculated from the comfort temperature, see
[Temperatures](how-it-works.md#temperatures). Create a **Number** helper for the comfort
temperature, so you can change it from a dashboard instead of editing the automation:

| Helper | Suggested settings | Input |
| ------ | ------------------ | ----- |
| `input_number.living_room_comfort` | 15 to 25 °C, step 0.5 | Comfort temperature entity |
| `input_number.living_room_eco` | 15 to 25 °C, step 0.5 | Eco temperature entity (optional override) |
| `input_number.living_room_away` | 5 to 20 °C, step 0.5 | Away temperature entity (optional override) |

Only create the eco and away helpers to set a fixed value instead of the calculated one. Helpers
can be shared: one `input_number.home_away` for all areas is a common choice. Changes on the room
thermostats are written back to these helpers (*Persistent*, the default); for a calculated level,
they go to the comfort helper.

### Schedules

Create a **Schedule** helper with the times the room should be warm, for example
`schedule.living_room_heating` with weekdays 06:30 to 08:00 and 17:00 to 22:30. While any of the
selected schedules is on, the area uses the comfort temperature, otherwise eco.

Several schedules can be combined, for example one per household member, and one schedule can be
used by several areas.

### PTO schedules

For days at home, such as public holidays or vacation days, create a second schedule, for example
`schedule.living_room_heating_pto`, and select it as *PTO schedule*. It is used instead of the
regular schedules on PTO (paid time off) days. Tell the blueprint which days these are:

- **Workday entity:** the `binary_sensor` or `calendar` of the
  [Workday](https://www.home-assistant.io/integrations/workday/) integration. While it is off, the
  day is a PTO day. With its default settings, this covers weekends and public holidays.
- **PTO calendars:** the calendar of the
  [Holiday](https://www.home-assistant.io/integrations/holiday/) integration for public holidays,
  and a calendar you maintain yourself, such as a
  [Local Calendar](https://www.home-assistant.io/integrations/local_calendar/), with an all-day
  event for each day off at home. While any of them has an active event, the day is a PTO day.

Workday alone cannot know that you take a week off, so add your own calendar for that. For time away
from home, use vacation mode instead.

### Toggles and buttons

| Helper | Type | Input | Use |
| ------ | ---- | ----- | --- |
| `input_boolean.guest_mode` | Toggle | Guest mode | Counts as somebody at home, for guests without a `person` |
| `input_boolean.vacation_mode` | Toggle | Vacation mode | Away temperature while on; share one helper across all areas |
| `input_button.living_room_boost` | Button | Boost trigger | Starts a boost for the boost duration |

A **Toggle** works as boost trigger too: it is turned off again when the boost ends, so it shows
whether a boost is running.

## 3. Optional sensors

### Presence sensor

An occupancy, presence or motion `binary_sensor` in the room keeps it at comfort temperature while
someone is there, regardless of schedules and persons. Use the delays to ignore short visits: the
defaults need 5 minutes of presence before heating up, and 5 minutes without presence before
returning to the schedule.

### Persons

Select the `person` entities of the household. With persons, comfort temperature requires somebody
to be home, and the *Away delay* switches to the away temperature once nobody has been home for
that long, for example 4 hours.

### Outdoor temperature

Select an outdoor temperature sensor, a `weather` entity, or both, to turn heating off on warm
days. The sensor is used first, the weather entity while the sensor has no valid value. With the
defaults, heating stops at 18 °C outside and resumes below 17 °C.

### Heating system

If the central heating system has a summer mode or is switched off at times, select an entity that
is on while it heats. If the boiler only exposes a `climate` entity, a template binary sensor can
provide it:

```yaml
template:
  - binary_sensor:
      - name: Heating system
        state: "{{ not is_state('climate.boiler', 'off') }}"
```

## 4. Create the automation

1. Go to **Settings → Automations & Scenes → Blueprints**, open **Area Heating Control 2.0** and click
   **Create automation**.
2. Select the area.
3. Open the sections you need and select the helpers and sensors from steps 2 and 3. Leave entity
   lists empty to use auto-discovery.
4. Choose how changes on the thermostats are handled, see
   [Changes on thermostats](how-it-works.md#changes-on-thermostats).
5. Save the automation, for example as *Heating: Living room*.

The same automation in YAML:

```yaml
alias: "Heating: Living room"
use_blueprint:
  path: mxstzdev/area-heating-control.yaml
  input:
    area: living_room
    comfort_temperature_entity: input_number.living_room_comfort
    schedules:
      - schedule.living_room_heating
    pto_schedules:
      - schedule.living_room_heating_pto
    workday_entity: binary_sensor.workday_sensor
    pto_calendars:
      - calendar.days_off
    persons:
      - person.alex
      - person.sam
    guest_mode: input_boolean.guest_mode
    vacation_mode: input_boolean.vacation_mode
    away_delay:
      hours: 4
    boost_entity: input_button.living_room_boost
    outdoor_weather_entity: weather.home
```

## 5. Check the result

Open the automation's **Traces** after the first run, or change the comfort helper and watch the
thermostats follow. To see why the area chose a temperature, enable the debug log as described in
[Troubleshooting](troubleshooting.md#diagnostics).

## Next steps

- Check **Calibration**, which is on by default and uses the room sensors or the room thermostats,
  see [Calibration](how-it-works.md#calibration).
- Check **Limescale protection**, which is on by default, and pick a day and time that suit you.
- Choose a **Window open behaviour**, see [Windows](how-it-works.md#windows).
- Show the area on a dashboard with [template entities](template-entities.md) for heating,
  temperature, humidity and open windows.
