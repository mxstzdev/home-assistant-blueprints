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
| Comfort temperature | `comfort_temperature` | 22 °C | Used while a schedule, a person or presence asks for comfort |
| Comfort temperature entity | `comfort_temperature_entity` | | `input_number` that overrides the static value |
| Eco temperature | `eco_temperature` | 19 °C | Used otherwise |
| Eco temperature entity | `eco_temperature_entity` | | `input_number` that overrides the static value |
| Away temperature | `away_temperature` | 15 °C | Used in vacation mode or after the away delay |
| Away temperature entity | `away_temperature_entity` | | `input_number` that overrides the static value |

## Radiator thermostats

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Radiator thermostats | `valves` | area: single target temperature | |
| Radiator thermostat input mode | `valve_behaviour` | `temporary` | `temporary` or `readonly`, see [Changes on thermostats](how-it-works.md#changes-on-thermostats) |

## Wall controllers

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Wall controllers | `controllers` | area: target temperature range | |
| Wall controller input mode | `controller_behaviour` | `temporary` | `readonly`, `temporary` or `persistent`, see [Changes on thermostats](how-it-works.md#changes-on-thermostats) |

## Calibration

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Calibration | `calibration` | `true` | See [Calibration](how-it-works.md#calibration) |
| Temperature sensors | `temperature_sensors` | area: temperature sensors not on a thermostat | Sensors of a wall controller are always ignored |
| Calibration delta | `calibration_delta` | 0.5 °C | Minimum offset change |
| Calibration timeout | `calibration_timeout` | 5 min | Minimum time between two offset changes per thermostat |
| Calibration reset | `calibration_reset` | | Resets all offsets to 0 when it turns on |

## Maintenance

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Limescale protection | `limescale_protection` | `true` | Opens all radiator valves for one minute once a week |
| Limescale protection day | `limescale_protection_day` | `fri` | `mon` to `sun` |
| Limescale protection time | `limescale_protection_time` | `12:00:00` | |

## Windows

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Window sensors | `windows` | area: window and door sensors | |
| Window open behaviour | `window_behaviour` | `"off"` | `"off"`, `frost_protection` or `native`, see [Windows](how-it-works.md#windows) |
| Frost protection temperature | `window_frost_protection_temperature` | 0 (thermostat minimum) | |
| Window open delay | `window_open_delay` | 1 min | |
| Window close delay | `window_close_delay` | 1 min | |

## Schedules

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Schedules | `schedules` | | `schedule` entities. Comfort while any is on |

## Presence

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Presence sensor | `presence_sensor` | | Occupancy, presence or motion sensor, or `input_boolean` |
| Presence detected delay | `presence_on_delay` | 5 min | |
| Presence cleared delay | `presence_off_delay` | 5 min | |

## Persons

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Persons | `persons` | | `person` entities |
| Arrive delay | `person_arrive_delay` | 1 min | |
| Leave delay | `person_leave_delay` | 1 min | |
| Guest mode | `guest_mode` | | Counts as somebody at home while on |

## Away

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Vacation mode | `vacation_mode` | | Away temperature while on |
| Away delay | `away_delay` | 0 (off) | Away temperature once nobody has been home this long. Requires persons |

## Boost

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Boost trigger | `boost_entity` | | `input_boolean`, `input_button` or `binary_sensor`, see [Boost](how-it-works.md#boost) |
| Boost duration | `boost_duration` | 30 min | |

## Outdoor temperature

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Outdoor temperature | `outdoor_temperature_entity` | | Temperature sensor or `weather` entity |
| Outdoor cutoff | `outdoor_cutoff_temperature` | 18 °C | Heating off at or above this temperature |
| Outdoor hysteresis | `outdoor_cutoff_hysteresis` | 1 °C | Heating resumes below the cutoff minus this value |

## Heating system

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Heating system | `heating_system` | | `on` or `active` while the boiler heats |
| Heating system delay | `heating_system_delay` | 2 min | |

## Advanced

| Input | Key | Default | Description |
| ----- | --- | ------- | ----------- |
| Action delay | `action_delay` | 0 s | Delay between two device commands |
| Startup delay | `startup_delay` | 0 s | Delay after a Home Assistant start |
| Log level | `log_level` | `info` | `debug`, `info` or `warning`, see [Diagnostics](troubleshooting.md#diagnostics) |
