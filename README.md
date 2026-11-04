# Installation
Add https://github.com/flax2000/home-assistant-addons to the addon store repositories
Install the VNC Web Browser addon
Configure the addon as described below
Start the addon



# Home Assistant Kiosk Browser Add-on

This add-on is based on the original POC: [MindFreeze/vnc-web](https://github.com/MindFreeze/ha-vnc-web-browser).

An optimized, resource-light kiosk add-on built on Debian Bookworm that runs Chromium and TigerVNC. It allows you to display your Home Assistant dashboards seamlessly on older Android tablets or any device supporting VNC viewers, even in multi-display setups.

## Features

- **Chromium Kiosk Mode:** Launches directly into fullscreen kiosk mode targeting your customized URLs.
- **Multi-Display VNC Server Support:** Runs isolated Xvnc servers for multiple displays (defaulting to ports `5901` through `5904`), complete with configurable color depths, frame rates, and resolutions.
- **Advanced Control HTTP API:** Exposes an API on port `8080` to remotely restart, redraw, pause, resume, or click specific coordinates on individual or all displays.
- **Resource Optimization:** Automatically purges temporary browser caches and temporary data files to prevent memory bloat during 24/7 operation on resource-constrained hardware.
- **Automated Interaction via `xdotool`:** Executes custom startup sequences to handle UI navigation or bypass blank loading glitches automatically.

---

## Configuration (`config.yaml`)

Here is an example configuration showing all available options:

```yaml
displays:
  - url: "http://192.168.1.226:8123/lovelace-test2/tablet"
    resolution: "1280x800"
    port: 5901
    depth: 24
    view_only: false
    browser_args: "--disable-site-isolation-trials --enable-low-end-device-mode"
    startup_commands: "key Escape mousemove 150 40 sleep 0.5 click 1 sleep 0.5 click 1"
frame_rate: 2
vnc_password: "******"
```

### Parameter Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `displays` | List | Required | Array of display configurations (URL, resolution, port, depth, etc.). |
| `url` | String | Required | The web address (URL) the browser should open. |
| `resolution` | String | Required | Screen resolution in `WIDTHxHEIGHT` format (e.g., `1280x800`). |
| `port` | Integer | Required | VNC port number (e.g., `5901` for display 1, corresponding to VNC display `:1`). |
| `depth` | Integer | `24` | Color depth for the Xvnc server (supports `8` to `32`, e.g., `16` or `24`). |
| `view_only` | Boolean | `false` | When set to `true`, VNC connections are restricted to view-only mode (inputs disabled). |
| `browser_args` | String | `""` | Extra command-line arguments passed to Chromium to optimize performance or save RAM. |
| `startup_commands` | String | `key Escape mousemove ...` | Commands executed via `xdotool` immediately after the browser launches and stabilizes. |
| `frame_rate` | Integer | `5` | Global cap on VNC screen updates per second to conserve CPU usage. |
| `vnc_password` | String | `""` | Optional password required to authenticate VNC viewer connections. |

---

## Why Use Startup Commands & a Sacrificial Dashboard?

Home Assistant frontends running on older tablets or embedded systems can occasionally load a blank page or fail to render all dashboard buttons and Lovelace cards upon initial startup. 

To guarantee a reliable display every single time, this add-on uses a clever workaround involving a **"sacrificial dashboard"** and automated `startup_commands`:

1. **The Sacrificial URL:** You point the browser `url` to an initial dashboard page. It does not matter if this specific page occasionally loads blank or fails to render fully, because it is only a landing pad.
2. **Automated Navigation:** Once the browser finishes loading, `startup_commands` automatically execute a sequence of actions using `xdotool`:
   - `key Escape`: Dismisses any lingering tooltips, modals, or splash screens.
   - `mousemove 150 40`: Moves the mouse cursor to specific coordinates (e.g., your navigation menu or sidebar toggle tab).
   - `click 1`: Clicks to switch over to a stable, fully functioning target dashboard.
   - Because the browser immediately transitions to a fresh dashboard view, it forces Home Assistant to render all buttons and UI elements correctly every single time.

---

## HTTP Control API

The add-on runs an internal control server on port `8080`, allowing you to automate or remotely manage displays using simple HTTP requests (e.g., via Home Assistant REST commands, automation webhooks, or shell scripts).

### Global Endpoints
- **Pause All Chromium Instances:**  
  `GET http://<ha-ip>:8080/pause`
- **Resume All Chromium Instances:**  
  `GET http://<ha-ip>:8080/resume`

### Per-Display Endpoints (`<display_num>` corresponds to the display index, e.g., `1` for port 5901)
- **Restart Browser for Display:**  
  `GET http://<ha-ip>:8080/restart_1`
- **Pause Browser for Display:**  
  `GET http://<ha-ip>:8080/pause_1`
- **Resume Browser for Display:**  
  `GET http://<ha-ip>:8080/resume_1`
- **Redraw / Force Refresh Display:**  
  `GET http://<ha-ip>:8080/redraw_1` *(Sends `Ctrl+F5`, waits 3 seconds, and presses `Escape`)*

### Coordinate Click Endpoint
- **Simulate Mouse Click at Coordinates:**  
  `GET http://<ha-ip>:8080/click_<display_num>_<X>x<Y>`  
  *Example:* `http://192.168.1.50:8080/click_1_500x300` clicks at coordinates `500, 300` on display 1.
