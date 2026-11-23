# Template entities

The automation itself creates no entities. To show the state of an area on a dashboard, create
[template entities](https://www.home-assistant.io/integrations/template/) with the templates below.
They use the area's entities the way the blueprint does.

| Entity | Type | Shows |
| ------ | ---- | ----- |
| [Heating](#heating) | Binary sensor | Whether the area should be warm, or whether its radiators are heating |
| [Area temperature](#area-temperature) | Sensor | Median of the area's temperature sensors |
| [Area humidity](#area-humidity) | Sensor | Median of the area's humidity sensors |
| [Open windows](#open-windows) | Binary sensor | Whether a window or door in the area is open |

## Creating an entity

In **Settings → Devices & services → Helpers → Create helper**, choose **Template**, then
**Template sensor** or **Template binary sensor**. Paste the template into *State*, replace the ids
in its first lines with yours, and choose the settings listed in the section. The preview shows
the result before you save.

The same entities can be created in YAML, in `configuration.yaml`. Paste the template under
`state:`:

```yaml
template:
  - binary_sensor:
      - name: Living room heating
        unique_id: living_room_heating
        device_class: heat
        state: >
          {# paste the template here #}
  - sensor:
      - name: Living room temperature
        unique_id: living_room_temperature
        device_class: temperature
        unit_of_measurement: °C
        state_class: measurement
        state: >
          {# paste the template here #}
```

Without any value, for example while all sensors are unavailable, the sensors are `unknown`.
Entities that are added to the area later are picked up automatically.

## Heating

On while the area should be warm: at least one of its schedules is on. As in the automation, the
PTO schedules are used instead on PTO days. Use the schedules, PTO schedules, workday entity and
PTO calendars of your automation, and leave a list empty or the workday entity `''` if you don't
use it. See [Schedules](inputs.md#schedules).

| Setting | Value |
| ------- | ----- |
| Device class | Heat |

```jinja
{% set schedules = ['schedule.living_room_heating'] %}
{% set pto_schedules = ['schedule.living_room_heating_pto'] %}
{% set workday_entity = 'binary_sensor.workday_sensor' %}
{% set pto_calendars = ['calendar.days_off'] %}
{% set pto_day = (workday_entity != '' and is_state(workday_entity, 'off'))
     or pto_calendars | select('is_state', 'on') | list | count > 0 %}
{% set used = pto_schedules if pto_day and pto_schedules | count > 0 else schedules %}
{{ used | select('is_state', 'on') | list | count > 0 }}
```

This follows the schedules only. Persons, presence, vacation mode, boost, open windows and the
heating demand are not included, so the area can be at a different temperature than the entity
suggests. To see what the automation decided, use the
[event](troubleshooting.md#log-and-event).

### Alternative: radiators heating

On while at least one thermostat of the area reports that it is heating. This shows the actual
heating, but only works with thermostats that report an `hvac_action`. Check the thermostat's
attributes in **Developer tools → States**.

```jinja
{% set area = 'living_room' %}
{{ area_entities(area) | select('match', 'climate[.]')
   | select('is_state_attr', 'hvac_action', 'heating') | list | count > 0 }}
```

## Area temperature

The median of the area's temperature sensors that do not belong to a thermostat, or of the room
thermostats if there are none, like the area temperature of the automation, see
[Calibration](how-it-works.md#calibration). Unavailable sensors are skipped.

| Setting | Value |
| ------- | ----- |
| Unit of measurement | °C |
| Device class | Temperature |
| State class | Measurement |

```jinja
{% set area = 'living_room' %}
{% set sensors = [] %}
{% set exclude = [] %}
{% set ns = namespace(values=[]) %}
{% set candidates = sensors if sensors | count > 0 else area_entities(area)
     | select('match', 'sensor[.]') | select('is_state_attr', 'device_class', 'temperature')
     | list %}
{% for id in candidates | reject('in', exclude) %}
  {% set device = device_id(id) %}
  {% if states(id) | is_number and (sensors | count > 0
        or not (device and device_entities(device) | select('match', 'climate[.]') | list)) %}
    {% set ns.values = ns.values + [states(id) | float] %}
  {% endif %}
{% endfor %}
{% if ns.values | count == 0 %}
  {% for id in area_entities(area) | select('match', 'climate[.]') %}
    {% set value = state_attr(id, 'current_temperature') %}
    {% if state_attr(id, 'supported_features') | int(0) | bitwise_and(2) > 0
          and value is number %}
      {% set ns.values = ns.values + [value | float] %}
    {% endif %}
  {% endfor %}
{% endif %}
{{ ns.values | median | round(1) if ns.values | count > 0 else none }}
```

If your sensors report °F, use °F as the unit.

To leave out a sensor that does not measure the room, such as the chip temperature of a Zigbee
coordinator, use the same options as in the automation, see
[The area temperature is wrong](troubleshooting.md#the-area-temperature-is-wrong):

- **Exclude it:** add it to `exclude`, for example
  `{% set exclude = ['sensor.zigbee_coordinator_temperature'] %}`.
- **Select the sensors yourself:** list them in `sensors`. Like a selection in the automation,
  this turns off auto-discovery.
- **Disable it:** disabled entities have no state and are skipped.

Use the same `exclude` and `sensors` as in the automation, so both show the same temperature.

## Area humidity

The median of the area's humidity sensors. Unavailable sensors and values outside 0 to 100 % are
skipped. `sensors` and `exclude` work as for the [area temperature](#area-temperature).

| Setting | Value |
| ------- | ----- |
| Unit of measurement | % |
| Device class | Humidity |
| State class | Measurement |

```jinja
{% set area = 'living_room' %}
{% set sensors = [] %}
{% set exclude = [] %}
{% set ns = namespace(values=[]) %}
{% set candidates = sensors if sensors | count > 0 else area_entities(area)
     | select('match', 'sensor[.]') | select('is_state_attr', 'device_class', 'humidity')
     | list %}
{% for id in candidates | reject('in', exclude) %}
  {% set value = states(id) | float(-1) %}
  {% if states(id) | is_number and 0 <= value <= 100 %}
    {% set ns.values = ns.values + [value] %}
  {% endif %}
{% endfor %}
{{ ns.values | median | round(0) if ns.values | count > 0 else none }}
```

## Open windows

On while at least one window or door sensor of the area is open or tilted, like the automation.
Select sensors yourself in `windows` or `doors`, which turns off auto-discovery for that list, and
add sensors that never count to `excluded`.

| Setting | Value |
| ------- | ----- |
| Device class | Window |

```jinja
{% set area = 'living_room' %}
{% set windows = [] %}
{% set doors = [] %}
{% set excluded = [] %}
{% set found = area_entities(area) | select('match', '(binary_)?sensor[.]') | list %}
{% set ids = (windows if windows | count > 0
     else found | select('is_state_attr', 'device_class', 'window') | list)
     + (doors if doors | count > 0 else found | select('is_state_attr', 'device_class', 'door') | list) %}
{{ ids | reject('in', excluded) | select('is_state', ['on', 'open', 'tilted']) | list | count > 0 }}
```

To list the open windows on a dashboard, add an attribute in YAML:

```yaml
template:
  - binary_sensor:
      - name: Living room windows
        unique_id: living_room_windows
        device_class: window
        state: >
          {# paste the template here #}
        attributes:
          open: >
            {{ area_entities('living_room') | select('match', '(binary_)?sensor[.]')
               | select('is_state_attr', 'device_class', 'window')
               | select('is_state', ['on', 'open', 'tilted']) | list }}
```
