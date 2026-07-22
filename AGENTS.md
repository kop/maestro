# AGENTS

## Releasing

Bump `version` in `.claude-plugin/plugin.json` on every push. Claude Code only picks up plugin changes when the version increases; without a bump, `/plugin` reports the plugin is already at the latest version and users never receive the update.
