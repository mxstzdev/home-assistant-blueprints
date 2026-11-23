# Inputs

Inputs are grouped in the same sections as in the Home Assistant UI. The *Key* column is the name
to use in YAML, under `use_blueprint.input`.

All inputs except the area are optional. If an entity list is left empty, matching entities of the
area are used.

## Area

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Area | `area` | | The area to control. Required |

## Temperatures

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Comfort temperature | `comfort_temperature` | 22 °C | Used while a schedule, a person or presence asks for comfort. Eco, away and boost are calculated from it |
| Comfort temperature entity | `comfort_temperature_entity` | | Recommended. `input_number` that overrides the static value |
| Eco offset | `eco_temperature_offset` | 3 °C | Eco = comfort − offset, at least 16 °C, never above comfort. Used otherwise |
| Eco temperature entity | `eco_temperature_entity` | | Manual override. Empty: calculated |
| Away offset | `away_temperature_offset` | 5 °C | Away = comfort − offset, at least 15 °C, never above comfort. Used in vacation mode or after the away delay |
| Away temperature entity | `away_temperature_entity` | | Manual override. Empty: calculated |
| Boost offset | `boost_temperature_offset` | 3 °C | Boost = comfort + offset, at most the thermostat's maximum. Only for thermostats without a boost preset or switch |
| Frost protection temperature | `frost_protection_temperature` | 0 (thermostat minimum) | Used by the *Frost protection* window open behaviour |

The floors of 16 °C (eco) and 15 °C (away) are fixed: lower setbacks rarely save more energy and
risk damp and mould. With the comfort temperature at or below a floor, the level uses the comfort
temperature. A temperature entity with a valid state always wins over the calculated value.

## Schedules

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Schedules | `schedules` | | `schedule` entities. Comfort while any is on |
| PTO schedules | `pto_schedules` | | `schedule` entities used instead on PTO days. Empty: the schedules apply every day |
| Workday entity | `workday_entity` | | Workday `binary_sensor` or `calendar`. Off: PTO day |
| PTO calendars | `pto_calendars` | | `calendar` entities, such as Holiday and your own days off. Active event: PTO day |

A day is a **PTO** (paid time off) day while the workday entity is off or any PTO calendar has an
active event. An unavailable workday entity counts as a workday.

## Persons and presence

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Persons | `persons` | | `person` entities |
| Arrive delay | `person_arrive_delay` | 1 min | |
| Leave delay | `person_leave_delay` | 1 min | |
| Guest mode | `guest_mode` | | Counts as somebody at home while on |
| Presence sensor | `presence_sensor` | | Occupancy, presence or motion sensor, or `input_boolean` |
| Presence detected delay | `presence_on_delay` | 5 min | |
| Presence cleared delay | `presence_off_delay` | 5 min | |
| Vacation mode | `vacation_mode` | | Away temperature while on |
| Away delay | `away_delay` | 0 (off) | Away temperature once nobody has been home this long. Requires persons |

## Windows

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Window sensors | `windows` | area: window sensors | |
| Door sensors | `doors` | area: door sensors | Doors that count as windows, for example balcony doors |
| Excluded door and window sensors | `excluded_door_window_sensors` | | Never count, for example a wardrobe door |
| Window open behaviour | `window_open_behaviour` | `"off"` | `"off"`, `frost_protection` or `native`, see [Windows](how-it-works.md#windows) |
| Window open delay | `window_open_delay` | 1 min | |
| Window close delay | `window_close_delay` | 1 min | |

## Boost

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Boost trigger | `boost_entity` | | `input_boolean`, `input_button` or `binary_sensor`, see [Boost](how-it-works.md#boost) |
| Boost duration | `boost_duration` | 15 min | |

## Room thermostats

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Room thermostats | `controllers` | area: target temperature range | |
| Room thermostat input mode | `controller_behaviour` | `persistent` | `readonly`, `temporary` or `persistent`, see [Changes on thermostats](how-it-works.md#changes-on-thermostats) |
| Room thermostat window behaviour | `controller_window_behaviour` | `ignore` | `ignore` (keep heating at the area target) or `follow` (react like the radiator thermostats), see [Windows](how-it-works.md#windows) |

## Radiator thermostats

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Radiator thermostats | `valves` | area: single target temperature | |
| Radiator thermostat input mode | `valve_behaviour` | `temporary` | `temporary` or `readonly`, see [Changes on thermostats](how-it-works.md#changes-on-thermostats) |

## Calibration

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Calibration | `calibration` | `true` | See [Calibration](how-it-works.md#calibration) |
| Temperature sensors | `temperature_sensors` | area: temperature sensors not on a thermostat | Sensors of a room thermostat are always ignored |
| Excluded temperature sensors | `excluded_temperature_sensors` | | Never used for the area temperature, for example a Zigbee coordinator's chip temperature |
| Calibration delta | `calibration_delta` | 0.5 °C | Minimum offset change |
| Calibration timeout | `calibration_timeout` | 5 min | Minimum time between two offset changes per thermostat |
| Calibration reset | `calibration_reset` | | Resets all offsets to 0 when it turns on |

## Heating demand

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Heating system | `heating_system` | | `on` or `active` while the boiler heats |
| Heating system delay | `heating_system_delay` | 2 min | |
| Outdoor temperature sensor | `outdoor_temperature_entity` | | Temperature sensor, used first |
| Weather | `outdoor_weather_entity` | | `weather` entity, used while the sensor has no valid value |
| Outdoor cutoff | `outdoor_cutoff_temperature` | 18 °C | Heating off at or above this temperature |
| Outdoor hysteresis | `outdoor_cutoff_hysteresis` | 1 °C | Heating resumes below the cutoff minus this value |

## Maintenance

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Limescale protection | `limescale_protection` | `true` | Opens all radiator valves for one minute once a week |
| Limescale protection day | `limescale_protection_day` | `fri` | `mon` to `sun` |
| Limescale protection time | `limescale_protection_time` | `12:00:00` | |

## Advanced

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Action delay | `action_delay` | 0 s | Delay between two device commands |
| Startup delay | `startup_delay` | 0 s | Delay after a Home Assistant start |
| Log level | `log_level` | `info` | `debug`, `info` or `warning`, see [Diagnostics](troubleshooting.md#diagnostics) |
