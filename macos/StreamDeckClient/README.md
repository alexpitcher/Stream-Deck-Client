# Stream Deck Mac Client

This is the Mac client for Phase 1 of the Stream Deck control-plane system. It connects to the Windows host over WebSocket, authenticates, registers actions, and handles physical key presses.

## Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later

## Building

To build the client, run the following command in this directory:

```bash
swift build
```

## Running

Run the built executable using `swift run`:

```bash
swift run StreamDeckClient --host <host-ip> --port <port> --token <psk>
```

### Arguments

- `--host`: The IP address of the Windows Host (default: `127.0.0.1`)
- `--port`: The WebSocket port of the Windows Host (default: `8765`)
- `--token`: The pre-shared key for authentication

### Example

```bash
swift run StreamDeckClient --host 192.168.1.100 --port 8765 --token mySecretToken
```

## Behavior

1. The client connects to the provided WebSocket host.
2. It sends an `Identify` message for authentication.
3. Upon receiving an `IdentifyAck` ok, it registers three actions: `btn_mute`, `btn_rec`, and `btn_stop`.
4. It listens for `AssignmentUpdate` to log the slots.
5. It handles `ActionTriggered` events when you press a key on the Stream Deck.
6. On the first `btn_mute` trigger, it will send a `StateUpdate` to change the physical button's label to "**MUTED**".
