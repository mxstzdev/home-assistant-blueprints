# Home Assistant Blueprints

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Validate](https://img.shields.io/github/actions/workflow/status/mxstzdev/home-assistant-blueprints/validate.yml?branch=main&label=validate)](https://github.com/mxstzdev/home-assistant-blueprints/actions/workflows/validate.yml)

My personal collection of [Home Assistant](https://www.home-assistant.io/) blueprints.
Each blueprint is versioned and released independently.

## Blueprints

### Automations

| Blueprint | Description |
| --------- | ----------- |
| [Area Heating Control](blueprints/automation/area-heating-control) | Area based heating with comfort, eco and away levels, windows, boost and calibration |

## Installation

Open a blueprint above and follow its Installation section, or in Home Assistant go to
**Settings → Automations & Scenes → Blueprints → Import Blueprint** and paste the URL of
the blueprint's `.yaml` file.

Each blueprint states the oldest Home Assistant version it supports in its README.

## Updating

Every blueprint has its own `CHANGELOG.md` and
[GitHub releases](https://github.com/mxstzdev/home-assistant-blueprints/releases)
tagged `<name>-X.Y.Z`. The installed version is shown in the Version badge at the top of the
blueprint's description. To update, re-import the blueprint and confirm overwriting the existing file.

## Support

- **Found a bug or have an idea?**
  [Open an issue](https://github.com/mxstzdev/home-assistant-blueprints/issues).
- **Want to fix or improve something?** Pull requests are welcome, see
  [CONTRIBUTING.md](CONTRIBUTING.md).
- **Enjoying the blueprints?** You can support the work on Ko-fi:

  [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/mxstzdev)

## License

[MIT](LICENSE)
