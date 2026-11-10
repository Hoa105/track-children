{{flutter_js}}
{{flutter_build_config}}

// Element embedding uses the host's observed dimensions, avoiding the full-page
// engine's stale physical-height / keyboard-inset calculation on keyboard close.
const host = document.getElementById('flutter-host');
window.trackChildrenViewport.attach(host);
_flutter.loader.load({config: {hostElement: host}});
