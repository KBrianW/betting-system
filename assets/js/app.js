// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {};

Hooks.ProfileDropdownHook = {
  mounted() {
    document.addEventListener("click", (e) => {
      const dropdown = document.getElementById("profile-dropdown");
      const btn = document.getElementById("profile-btn");
      if (!dropdown || !btn) return;
      // Only close if dropdown is open and the click is outside
      if (
        this.el.classList.contains("opacity-100") &&
        !dropdown.contains(e.target) &&
        !btn.contains(e.target)
      ) {
        this.pushEvent("toggle_profile_dropdown", {});
      }
    });
  }
};

Hooks.BetSlipHook = {
  handleClick: null,
  mounted() {
    this.handleClick = (e) => {
      const slip = document.getElementById("bet-slip");
      if (!slip) return;
      if (
        slip.classList.contains("translate-x-0") &&
        !slip.contains(e.target)
      ) {
        this.pushEvent("toggle_bet_slip", {});
      }
    };
    document.addEventListener("click", this.handleClick);
  },
  destroyed() {
    document.removeEventListener("click", this.handleClick);
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

