// Pure presentation logic shared by the service and the bar.
function iconFor(device) {
    switch (device.kind) {
    case "mouse": return "device-mouse";
    case "keyboard": return "keyboard";
    case "headset":
        return /buds|airpods|earbud/i.test(device.name) ? "device-earbuds" : "device-headset";
    case "gamepad": return "gamepad";
    case "phone": return "device-phone";
    default: return "device-wireless";
    }
}

function sameDevice(a, b) {
    // Never dedupe by kind alone: two mice are two batteries.
    if (a.address && b.address)
        return a.address === b.address;
    return (a.kind === b.kind || a.kind === "other" || b.kind === "other")
        && a.name.trim() !== "" && a.name.trim().toLowerCase() === b.name.trim().toLowerCase();
}

function merge(nativeDevices, hubDevices) {
    var result = nativeDevices.slice();
    var matchedNative = [];
    hubDevices.forEach(function (device) {
        var matches = [];
        nativeDevices.forEach(function (nativeDevice, index) {
            if (matchedNative.indexOf(index) < 0 && sameDevice(nativeDevice, device))
                matches.push(index);
        });
        // Ambiguous identical model names are not enough to identify hardware.
        var index = matches.length === 1 ? matches[0] : -1;
        if (index < 0) {
            result.push(device);
        } else {
            matchedNative.push(index);
            // Prefer fresh kernel telemetry/charging state; enrich generic icons.
            var nativeDevice = result[index];
            if (nativeDevice.percent < 0 && device.percent >= 0 && !device.asleep)
                result[index] = Object.assign({}, device);
            else if (nativeDevice.kind === "other")
                result[index] = Object.assign({}, nativeDevice, {kind: device.kind});
        }
    });
    var order = {headset: 0, mouse: 1, keyboard: 2, gamepad: 3, phone: 4, other: 5};
    return result.filter(function (d) { return d.connected; }).sort(function (a, b) {
        var aLow = a.percent >= 0 && a.percent <= 15 && !a.charging && !a.asleep;
        var bLow = b.percent >= 0 && b.percent <= 15 && !b.charging && !b.asleep;
        return Number(bLow) - Number(aLow) || (order[a.kind] || 0) - (order[b.kind] || 0)
            || a.name.localeCompare(b.name) || a.key.localeCompare(b.key);
    });
}

function tooltip(device) {
    var level = device.percent >= 0 ? device.percent + "%" : "Battery unavailable";
    var states = [];
    if (device.charging) states.push("Charging");
    if (device.asleep) states.push(device.percent >= 0 ? "Asleep · last known level" : "Asleep");
    else if (device.lastKnown) states.push("Last known level");
    if (device.via) states.push(device.via);
    if (device.detail) states.push(device.detail);
    return device.name + " · " + level + (states.length ? "\n" + states.join(" · ") : "");
}

function layout(devices, maxWidth, cellWidth, padding, gap) {
    var available = Math.max(0, maxWidth - padding * 2);
    var count = Math.min(3, devices.length);
    // Reserve an overflow badge whenever devices would otherwise be hidden.
    while (count > 0) {
        var overflow = count < devices.length ? 24 + gap : 0;
        if (count * cellWidth + Math.max(0, count - 1) * gap + overflow <= available)
            break;
        count--;
    }
    if (!devices.length || (count === 0 && available < 24))
        return {shown: [], hidden: [], width: 0};
    var shown = devices.slice(0, count);
    var hidden = devices.slice(count);
    var width = count * cellWidth + Math.max(0, count - 1) * gap + padding * 2;
    if (hidden.length)
        width += 24 + (count > 0 ? gap : 0);
    return {shown: shown, hidden: hidden, width: width};
}

function withLastKnown(devices, previous, now) {
    var cache = {};
    var result = devices.map(function (device) {
        var d = Object.assign({}, device);
        var old = previous[d.key];
        if (!d.asleep && d.percent >= 0) {
            cache[d.key] = {percent: d.percent, time: now};
        } else if (d.asleep) {
            // A one-shot sleeping reading has no timestamp. Only our own
            // previously awake sample may be advertised as last known.
            if (old && now - old.time <= (d.graceSec || 0) * 1000) {
                d.percent = old.percent;
                d.lastKnown = true;
                cache[d.key] = old;
            } else {
                d.percent = -1;
            }
        } else if (old && now - old.time <= (d.graceSec || 0) * 1000) {
            // A connected unknown reading is not fresh telemetry, but it must
            // not destroy history that a subsequent sleeping sample can use.
            cache[d.key] = old;
        }
        return d;
    });
    // Missing/disconnected keys do not survive; no resurrection after reconnect.
    return {devices: result, cache: cache};
}
