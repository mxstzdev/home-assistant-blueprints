# Migrating to 2.0

Version 1.x lived in a
[standalone repository](https://github.com/mxstzdev/home-assistant-blueprint-area-heating-control).
2.0 is a rewrite with new input names and a new file name, so existing automations do not pick it
up automatically. The 1.x blueprint keeps working until you switch, so you can migrate one area at
a time.

## Steps

1. Import the 2.0 blueprint, see [Installation](../README.md#installation). It is listed as
   **Area Heating Control 2.0**, next to the 1.x **Area Heating Control**.
2. Open an automation that uses 1.x, open the menu (⋮) and choose **Edit in YAML**.
3. Change `use_blueprint.path` to `mxstzdev/area-heating-control.yaml`.
4. Rename the inputs as listed in [Input mapping](#input-mapping). Inputs you never set can be
   left out. All 2.0 inputs are listed in [Inputs](inputs.md).
5. Save, and check the automation's **Traces** after its next run.
6. Read the [behaviour changes](#behaviour-changes), especially for wall controllers.
7. Once no automation uses 1.x any more, delete the 1.x blueprint in
   **Settings → Automations & Scenes → Blueprints**.

## Example

Before, with 1.x:

```yaml
use_blueprint:
  path: mxstzdev/area-heating-control.yaml
  input:
    input_area_id: living_room
    input_area_temperature_settings_comfort_entity: input_number.living_room_comfort
    input_area_temperature_settings_eco_entity: input_number.living_room_eco
    input_area_heating_schedules:
      - schedule.living_room_heating
    input_persons:
      - person.alex
    input_area_thermostat_maintenance_limescale_protection: true
    input_area_thermostat_maintenance_limescale_protection_day: Fri
```

After, with 2.0:

```yaml
use_blueprint:
  path: mxstzdev/area-heating-control.yaml
  input:
    area: living_room
    comfort_temperature_entity: input_number.living_room_comfort
    eco_temperature_entity: input_number.living_room_eco
    schedules:
      - schedule.living_room_heating
    persons:
      - person.alex
    limescale_protection: true
    limescale_protection_day: fri
```

The 1.x path depends on where you imported it from. Check it in your automation before changing
it.

## Input mapping

| 1.x input | 2.x input |
| --------- | --------- |
| `input_area_id` | `area` |
| `input_area_temperature_settings_comfort_static` | `comfort_temperature` |
| `input_area_temperature_settings_comfort_entity` | `comfort_temperature_entity` |
| `input_area_temperature_settings_eco_static` | `eco_temperature` |
| `input_area_temperature_settings_eco_entity` | `eco_temperature_entity` |
| `input_area_thermostat_valves` | `valves` |
| `input_area_thermostat_controllers` | `controllers` |
| `input_area_temperature_sensors` | `temperature_sensors` |
| `input_area_thermostat_calibration_delta` | `calibration_delta` |
| `input_area_thermostat_calibration_threshold` | `calibration_timeout` |
| `input_area_thermostat_calibration_reset` | `calibration_reset` |
| `input_area_thermostat_maintenance_limescale_protection` | `limescale_protection` |
| `input_area_thermostat_maintenance_limescale_protection_day` | `limescale_protection_day` (now lowercase, e.g. `fri`) |
| `input_area_thermostat_maintenance_limescale_protection_time` | `limescale_protection_time` |
| `input_area_windows` | `windows` |
| `input_area_windows_opening_event_threshold` | `window_open_delay` |
| `input_area_windows_closing_event_threshold` | `window_close_delay` |
| `input_area_heating_schedules` | `schedules` |
| `input_area_presence_sensor` | `presence_sensor` |
| `input_area_presence_sensor_on_event_threshold` | `presence_on_delay` |
| `input_area_presence_sensor_off_event_threshold` | `presence_off_delay` |
| `input_heating_system_heating_mode` | `heating_system` |
| `input_heating_system_event_threshold` | `heating_system_delay` |
| `input_persons` | `persons` |
| `input_persons_entering_home_event_threshold` | `person_arrive_delay` |
| `input_persons_leaving_home_event_threshold` | `person_leave_delay` |
| `input_guest_mode` | `guest_mode` |
| `input_automation_action_delay` | `action_delay` |
| `input_automation_startup_delay` | `startup_delay` |
| `input_automation_log_level` | `log_level` (`error`, `fatal` and `critical` were removed) |

## Behaviour changes

- Calibration now actually writes to the thermostats. It is off by default; enable it with
  `calibration`.
- The presence sensor now works and overrides schedules and persons while it detects someone.
- All selected schedules are used, not only the first one.
- Window auto-discovery also finds door sensors.
- The startup delay postpones changes instead of dropping them.
- Changes on a wall controller made in the Home Assistant UI now count as well, and by default apply
  to the whole room until the next change in the area (`controller_behaviour: temporary`). Set it to
  `persistent` for the 1.x behaviour of writing them to the temperature entity.
- Turning a wall controller off turns the whole area off.

## New in 2.0

Away temperature, vacation mode and away delay, radiator thermostat change handling, window open
behaviour and window inputs, outdoor cutoff, boost, and external temperature inputs.
