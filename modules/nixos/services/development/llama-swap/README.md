# Wake-on-demand inference

Ulmo serves the OpenAI-compatible API at `http://ulmo:5010/v1`. Manwe still runs
llama.cpp and keeps the models on its own disk. The model IDs on ulmo come from
the ids manwe's llama.cpp serves its presets under (`servedModels`), so clients use the same IDs on either endpoint.

On the first inference request, llama-swap starts a local wake helper. If manwe's
`/health` does not answer successfully, the helper sends a Wake-on-LAN packet.
llama-swap holds the request until `/health` answers, for up to `wakeTimeout`
seconds (180 by default), then proxies it, including streaming responses.
Manwe's llama.cpp router loads the requested model on demand.

The helper stays alive until llama-swap stops it after one second without active
requests. This only re-arms the wake check for the next burst of requests: it
does not stop llama.cpp, unload models or suspend manwe. Requests in an active
stream prevent that local idle timeout. Manwe's existing VRAM idle timeout is
unchanged. Suspending manwe while a request is in flight can still fail that
request; the proxy does not replay inference requests.

`GET /v1/models` lists the configured models without waking manwe. Ulmo's own
`/health` only checks llama-swap, not whether manwe is awake. Client timeouts
must allow for both waking manwe and loading the model.

The endpoint has no authentication or public Caddy route. With `openFirewall`
enabled it is available to any client that can reach the listening port; keep
it on the trusted LAN/VPN. The wake packet must reach manwe's wired NIC on the
same broadcast domain.

## Checking after deployment

```sh
curl http://ulmo:5010/v1/models
curl --max-time 300 --no-buffer http://ulmo:5010/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"unsloth/Qwen3.6-35B-A3B-GGUF:IQ4_XS","messages":[{"role":"user","content":"Hello"}],"stream":true}'
```

Test the second request with manwe asleep as well as awake. Inspect
`journalctl -u llama-swap` on ulmo for wake and health-check failures.

The local integration check runs the real llama-swap against a mock backend and
replaces only the magic-packet sender. It covers discovery without waking,
warm requests, concurrent cold requests, streaming, re-arming and wake timeouts:

```sh
nix build --no-link path:.#checks.x86_64-linux.llama-swap
```

## Home Assistant

The pinned Home Assistant (2026.10.4) includes the native
[llama.cpp integration](https://www.home-assistant.io/integrations/llama_cpp/).
It accepts an OpenAI-compatible base URL, supports streamed conversations and
executes Home Assistant tools. No custom integration or additional AI router
is needed.

The integration is included in Home Assistant's `extraComponents`, but its
connection and Assist pipeline are not configured yet. After deploying ulmo:

1. Add the llama.cpp integration in Home Assistant, using
   `http://127.0.0.1:5010/v1` (Home Assistant and llama-swap both run on ulmo).
   No API key is required.
2. Select `unsloth/Qwen3.6-35B-A3B-GGUF:IQ4_XS`, then select its conversation
   agent in an Assist pipeline.
3. Enable the device-control tools and expose only the entities the assistant
   should control. Start with text requests and a small set of lights.

The [pinned integration's client](https://github.com/home-assistant/core/blob/2026.10.4/homeassistant/components/llama_cpp/api.py)
lists models during startup, so Home Assistant can start while manwe is asleep.
Initial configuration also sends test completions, which will wake manwe.
Those tests check API compatibility, not the reliability of actual device
control: structured tool calls, the model's chat template, Dutch responses and
cold-start latency still need testing on the real machines.

For voice, ulmo already has Wyoming and Piper configured with a Dutch voice.
No speech-to-text server is declared yet. Adding a local
[Whisper service through Wyoming](https://www.home-assistant.io/integrations/wyoming/)
would complete the speech pipeline; a microphone/speaker client can initially
be the Home Assistant companion app. Open-ended transcription is needed for
general conversation, rather than a fixed vocabulary of home-control phrases.
