# Area Heating Control

[![License](https://img.shields.io/badge/license-MIT-blue)](../../../LICENSE) [![Version](https://img.shields.io/static/v1?label=version&message=2.1.0&color=blue)](CHANGELOG.md) [![Home Assistant](https://img.shields.io/badge/Home%20Assistant-%E2%89%A5%202025.1.0-41BDF5?logo=homeassistant&logoColor=white)](https://www.home-assistant.io/) <!-- x-release-please-version -->

Blueprint for advanced, area-based heating control automations. It uses Home Assistant's
[areas](https://www.home-assistant.io/docs/organizing/areas/) to find the thermostats and sensors of
a room and keeps them at the right temperature.

- 🌱 Auto-calculated temperatures: set your comfort temperature, and eco, away and boost follow it
  (overridable with custom entities)
- 🕵️ Entity auto-discovery for thermostats, window sensors and temperature sensors
- 🗓️ Multiple heating schedules, e.g. one per household member
- 👥 Persons and presence detection, including guest and vacation mode
- 🪟 Open window detection with heating off or frost protection
- ⚙️ Thermostat calibration against external temperature sensors
- ♨️ Heating demand detection based on outdoor temperature and central heating system status
- 🚀 Temperature boost support for a quick warm-up
- 🎛️ Wall controller support to control your area from one place
- ⚔️ Weekly limescale protection for radiator valves

## Requirements

- Home Assistant 2025.1.0 or newer
- An area with at least one `climate` entity. Assign your thermostats and sensors to the area
  before you create the automation.

## Installation

1. Import the blueprint:

   [![Import](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2Fmxstzdev%2Fhome-assistant-blueprints%2Fblob%2Fmain%2Fblueprints%2Fautomation%2Farea-heating-control%2Farea-heating-control.yaml)

   Or, in Home Assistant, go to **Settings → Automations & Scenes → Blueprints → Import Blueprint**
   and paste this URL:

   ```text
   https://github.com/mxstzdev/home-assistant-blueprints/blob/main/blueprints/automation/area-heating-control/area-heating-control.yaml
   ```

2. Open **Area Heating Control 2.0** in the blueprint list and click **Create automation**.
3. Select the area. Everything else is optional; see [Inputs](docs/inputs.md).
4. Create one automation per area.

The [setup guide](docs/area-setup.md) walks through an area step by step, including the helpers and
sensors to create.

## Updating

1. In **Settings → Automations & Scenes → Blueprints**, open the menu (⋮) of **Area Heating Control 2.0**
   and choose **Re-import blueprint**.
2. Confirm overwriting the existing file. Your automations use the new version right away.

> [!NOTE]
> The installed version is shown in the Version badge at the top of the blueprint's description.

> [!WARNING]
> Major versions can rename or remove inputs. Read the [CHANGELOG.md](CHANGELOG.md) before updating
> across a major version. Coming from 1.x? See [Migrating to 2.0](docs/migration-to-v2.md).

## Documentation

- [Setting up an area](docs/area-setup.md): devices, helpers, sensors and the automation
- [Inputs](docs/inputs.md): all inputs with their YAML keys and defaults
- [How it works](docs/how-it-works.md): priorities, windows, changes on thermostats, boost and calibration
- [Troubleshooting](docs/troubleshooting.md): diagnostics, common problems, limitations and reporting issues
- [Migrating to 2.0](docs/migration-to-v2.md): from the 1.x standalone blueprint

## License

[MIT](../../../LICENSE)
