// SPDX-License-Identifier: MIT
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

export const BACKEND = '/usr/local/bin/lg-brightness';

// Fixed executable and argument vector, never a shell or synchronous Shell I/O.
export function runCommand(args, executable = BACKEND, timeoutMs = 3000) {
    const process = Gio.Subprocess.new(
        [executable, ...args],
        Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
    let cancelled = false;
    let timedOut = false;
    let finished = false;
    let timeout = 0;
    const kill = () => {
        if (!finished)
            process.force_exit();
    };
    const promise = new Promise((resolve, reject) => {
        timeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, timeoutMs, () => {
            timeout = 0;
            timedOut = true;
            kill();
            return GLib.SOURCE_REMOVE;
        });
        process.communicate_utf8_async(null, null, (source, result) => {
            finished = true;
            if (timeout) {
                GLib.source_remove(timeout);
                timeout = 0;
            }
            try {
                const [, stdout, stderr] = source.communicate_utf8_finish(result);
                if (cancelled)
                    throw new Error('Brightness request cancelled');
                if (timedOut)
                    throw new Error('Brightness command timed out');
                if (!source.get_successful())
                    throw new Error(stderr.trim() || 'Brightness command failed');
                resolve(stdout);
            } catch (error) {
                reject(error);
            }
        });
    });
    return {
        promise,
        cancel() {
            cancelled = true;
            kill();
        },
    };
}
