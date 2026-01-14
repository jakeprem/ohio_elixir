# Lazyoh

A lazygit-style TUI for managing Ohio Elixir events and venues.

## Installation

```bash
cd tui
go build -o lazyoh .
```

Optionally, move to a directory in your PATH:
```bash
mv lazyoh ~/.local/bin/
```

## Usage

Launch the TUI:
```bash
lazyoh
```

### Authentication

First, authenticate with your Ohio Elixir account:

```bash
lazyoh login
```

This opens your browser to sign in via magic link. After successful login, your credentials are saved to `~/.ohio_elixir/config.yaml`.

Check your login status:
```bash
lazyoh whoami
```

Sign out:
```bash
lazyoh logout
```

### TUI Navigation

Once authenticated, launch `lazyoh` to open the interactive interface:

- **Tab / 1-4**: Switch between panels (Events, Venues, Details, Attendees)
- **j/k**: Navigate up/down in lists
- **Enter**: Select item
- **e**: Edit selected item
- **n**: Create new item
- **p**: Publish draft event
- **?**: Show help
- **q**: Quit

### CLI Commands

List all events:
```bash
lazyoh events list
```

Show event details:
```bash
lazyoh events show <event-id>
```

Edit event description (opens $EDITOR):
```bash
lazyoh events edit <event-id>
```

Publish a draft event:
```bash
lazyoh events publish <event-id>
```

Cancel an event:
```bash
lazyoh events cancel <event-id>
```

List all venues:
```bash
lazyoh venues list
```

Show venue details:
```bash
lazyoh venues show <venue-id>
```

## Configuration

Config file location: `~/.ohio_elixir/config.yaml`

```yaml
api_url: https://ohioelixir.com/api
token: <your-auth-token>
email: your@email.com
```

The config directory is created with `0700` permissions and the config file with `0600` (only you can read/write).

### API URL Precedence

The API URL is determined in this order:
1. `--api-url` flag (highest priority)
2. `LAZYOH_API_URL` environment variable
3. `api_url` in config file
4. Default: `https://ohioelixir.com/api`

### Local Development

For local development, set the environment variable:
```bash
export LAZYOH_API_URL=http://localhost:4001/api
lazyoh
```

Or use the flag:
```bash
lazyoh --api-url http://localhost:4001/api
```

### Custom Config File

Use a different config file:
```bash
lazyoh --config /path/to/config.yaml
```

## External Editor

The `lazyoh events edit` command uses your `$EDITOR` environment variable. Falls back to `nvim`, `vim`, `nano`, or `vi` in that order.
