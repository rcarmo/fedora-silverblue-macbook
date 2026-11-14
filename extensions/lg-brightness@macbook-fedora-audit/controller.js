// SPDX-License-Identifier: MIT
// Shell-independent asynchronous state machine; exercised with GJS unit tests.
export function parsePercentage(output) {
    if (!/^\s*\d+(?:\.\d+)?%\s*$/.test(output))
        throw new Error('Invalid brightness response');
    const value = Number(output.trim().slice(0, -1));
    if (!Number.isFinite(value) || value < 0 || value > 100)
        throw new Error('Brightness response outside 0..100');
    return value;
}

export class BrightnessController {
    constructor({run, onValue, onError}) {
        this._run = run;
        this._onValue = onValue;
        this._onError = onError;
        this._active = true;
        this._busy = false;
        this._readPending = false;
        this._writePending = null;
        this._generation = 0;
        this._operation = null;
    }

    read() {
        if (!this._active)
            return;
        this._readPending = true;
        this._drain();
    }

    write(value) {
        if (!Number.isFinite(value) || value < 0 || value > 100)
            throw new Error('Brightness must be within 0..100');
        if (!this._active)
            return;
        this._writePending = Math.round(value);
        this._drain();
    }

    reset() {
        // Drop queued writes on monitor reconfiguration; don't apply an old
        // slider gesture to a newly attached monitor. Ignore stale callbacks.
        this._generation++;
        this._writePending = null;
        this._readPending = false;
        this._operation?.cancel();
        if (this._active)
            this._drain();
    }

    stop() {
        this._active = false;
        this._generation++;
        this._writePending = null;
        this._readPending = false;
        this._operation?.cancel();
    }

    async _drain() {
        if (!this._active || this._busy)
            return;
        let args;
        if (this._writePending !== null) {
            args = ['set', String(this._writePending)];
            this._writePending = null;
            this._readPending = false; // set already returns verified readback
        } else if (this._readPending) {
            args = ['get'];
            this._readPending = false;
        } else {
            return;
        }
        this._busy = true;
        const generation = this._generation;
        try {
            this._operation = this._run(args);
            const output = await this._operation.promise;
            if (this._active && generation === this._generation &&
                this._writePending === null)
                this._onValue(parsePercentage(output));
        } catch (error) {
            if (this._active && generation === this._generation)
                this._onError(error, args[0]);
        } finally {
            this._operation = null;
            this._busy = false;
            this._drain();
        }
    }
}
