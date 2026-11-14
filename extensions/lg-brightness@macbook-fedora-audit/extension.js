// SPDX-License-Identifier: MIT
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {QuickSlider, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

import {BrightnessController} from './controller.js';
import {runCommand} from './subprocess.js';

export default class LGBrightnessExtension extends Extension {
    enable() {
        this._enabled = true;
        this._timers = new Set();
        this._writeTimer = 0;
        this._pollTimer = 0;
        this._syncing = false;
        this._dragging = false;
        this._lastError = null;
        this._indicator = new SystemIndicator();
        this._item = new QuickSlider({
            iconName: 'display-brightness-symbolic',
            iconLabel: 'LG Brightness',
            visible: false,
        });
        this._item.slider.accessible_name = 'LG Brightness';
        this._label = new St.Label({
            text: 'LG',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'lg-brightness-label',
        });
        this._item.get_child().add_child(this._label);
        this._indicator.quickSettingsItems.push(this._item);
        // Full-width row. No panel icon, no overrides of the laptop slider.
        this._quickSettings = Main.panel.statusArea.quickSettings;
        this._quickSettings.addExternalIndicator(this._indicator, 2);
        this._controller = new BrightnessController({
            run: args => runCommand(args),
            onValue: value => this._sync(value),
            onError: (error, command) => this._error(error, command),
        });
        this._item.slider.connect('notify::value', () => this._sliderChanged());
        this._item.slider.connect('drag-begin', () => {
            this._dragging = true;
        });
        this._item.slider.connect('drag-end', () => {
            this._dragging = false;
        });
        this._monitorSignal = Main.layoutManager.connect('monitors-changed',
            () => this._monitorsChanged());
        this._menuSignal = this._quickSettings.menu.connect('open-state-changed',
            (_menu, open) => this._menuChanged(open));
        this._controller.read();
        // USB HID registration / seat ACL application can lag video hotplug.
        this._refreshLater(1500);
        this._refreshLater(5000);
        if (this._quickSettings.menu.isOpen)
            this._menuChanged(true);
    }

    _later(milliseconds, callback) {
        const id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, milliseconds, () => {
            this._timers.delete(id);
            if (this._enabled)
                callback();
            return GLib.SOURCE_REMOVE;
        });
        this._timers.add(id);
        return id;
    }

    _removeTimer(id) {
        if (id && this._timers.delete(id))
            GLib.source_remove(id);
    }

    _refreshLater(milliseconds) {
        this._later(milliseconds, () => this._controller.read());
    }

    _sync(value) {
        this._lastError = null;
        this._item.visible = true;
        // Don't overwrite an in-progress keyboard/scroll/drag gesture with a
        // stale read or the readback from an earlier position of the slider.
        if (this._writeTimer || this._dragging)
            return;
        this._syncing = true;
        this._item.slider.value = value / 100;
        this._label.text = `LG · ${Math.round(value)}%`;
        this._syncing = false;
    }

    _sliderChanged() {
        if (this._syncing || !this._enabled)
            return;
        const percent = Math.round(this._item.slider.value * 100);
        this._label.text = `LG · ${percent}%`;
        this._removeTimer(this._writeTimer);
        this._writeTimer = this._later(200, () => {
            this._writeTimer = 0;
            this._controller.write(percent);
        });
    }

    _error(error, command) {
        this._item.visible = false;
        const message = error.message ?? String(error);
        // No LG attached is expected; other failures are logged once per state.
        if (!message.includes('No supported LG UltraFine') && message !== this._lastError) {
            console.warn(`LG Brightness: ${message}`);
            if (command === 'set')
                Main.notifyError('LG Brightness', message);
        }
        this._lastError = message;
    }

    _monitorsChanged() {
        for (const id of this._timers)
            GLib.source_remove(id);
        this._timers.clear();
        this._writeTimer = 0;
        this._pollTimer = 0;
        this._dragging = false;
        this._item.visible = false;
        this._controller.reset();
        this._refreshLater(1000);
        this._refreshLater(4000);
        if (this._quickSettings.menu.isOpen)
            this._schedulePoll();
    }

    _menuChanged(open) {
        this._removeTimer(this._pollTimer);
        this._pollTimer = 0;
        if (open) {
            this._controller.read();
            this._schedulePoll();
        }
    }

    _schedulePoll() {
        // Refresh external CLI changes only while Quick Settings is open.
        // There is no permanent polling process and no brightness write on load.
        this._pollTimer = this._later(5000, () => {
            this._pollTimer = 0;
            if (this._quickSettings.menu.isOpen) {
                if (!this._writeTimer && !this._dragging)
                    this._controller.read();
                this._schedulePoll();
            }
        });
    }

    disable() {
        this._enabled = false;
        for (const id of this._timers ?? [])
            GLib.source_remove(id);
        this._timers?.clear();
        this._controller?.stop();
        if (this._monitorSignal)
            Main.layoutManager.disconnect(this._monitorSignal);
        if (this._menuSignal)
            this._quickSettings.menu.disconnect(this._menuSignal);
        this._monitorSignal = 0;
        this._menuSignal = 0;
        this._item?.destroy();
        this._indicator?.destroy();
        this._item = null;
        this._indicator = null;
        this._label = null;
        this._controller = null;
        this._quickSettings = null;
        this._writeTimer = 0;
        this._pollTimer = 0;
    }
}
