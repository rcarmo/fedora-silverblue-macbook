// SPDX-License-Identifier: MIT
// Run with gjs -m tools/tests/lg_brightness_extension_test.js
import GLib from 'gi://GLib';
import {BrightnessController, parsePercentage} from '../../extensions/lg-brightness@macbook-fedora-audit/controller.js';
import {runCommand, BACKEND} from '../../extensions/lg-brightness@macbook-fedora-audit/subprocess.js';

let count = 0;
function assert(condition, message) {
    if (!condition)
        throw new Error(message);
    count++;
}
function equal(actual, expected, message) {
    assert(JSON.stringify(actual) === JSON.stringify(expected),
        `${message}: ${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
}
async function flush() {
    for (let i = 0; i < 5; i++)
        await Promise.resolve();
}
function fixture() {
    const jobs = [];
    const values = [];
    const errors = [];
    const controller = new BrightnessController({
        run(args) {
            let resolve, reject;
            const promise = new Promise((ok, no) => {
                resolve = ok;
                reject = no;
            });
            const job = {args, resolve, reject, cancelled: false};
            jobs.push(job);
            return {promise, cancel() {
                job.cancelled = true;
                reject(new Error('cancelled'));
            }};
        },
        onValue: value => values.push(value),
        onError: (error, command) => errors.push([error.message, command]),
    });
    return {controller, jobs, values, errors};
}

for (const [text, expected] of [['50.0%\n', 50], ['0%', 0], ['100.0%', 100], [' 12.5% ', 12.5]])
    equal(parsePercentage(text), expected, 'parse valid readback');
for (const text of ['NaN%', '-1%', '101%', '50', 'garbage', '50%\n20%', 'Infinity%']) {
    let failed = false;
    try {
        parsePercentage(text);
    } catch {
        failed = true;
    }
    assert(failed, `reject malformed readback: ${text}`);
}
{
    const f = fixture();
    f.controller.read();
    equal(f.jobs[0].args, ['get'], 'startup only reads');
    f.jobs[0].resolve('50.0%\n');
    await flush();
    equal(f.values, [50], 'initial brightness delivered');
    equal(f.jobs.length, 1, 'read does not cause a write');
    f.controller.stop();
}
{
    const f = fixture();
    f.controller.read();
    f.controller.write(60);
    f.controller.write(70);
    f.controller.write(80.4);
    equal(f.jobs.length, 1, 'only one subprocess at a time');
    f.jobs[0].resolve('50%');
    await flush();
    equal(f.values, [], 'stale read does not overwrite new gesture');
    equal(f.jobs[1].args, ['set', '80'], 'latest pending write wins');
    f.jobs[1].resolve('80%');
    await flush();
    equal(f.values, [80], 'verified write readback delivered');
    equal(f.jobs.length, 2, 'set readback avoids redundant get');
    f.controller.stop();
}
{
    const f = fixture();
    f.controller.write(30);
    f.controller.write(40);
    f.controller.write(50);
    f.jobs[0].resolve('30%');
    await flush();
    equal(f.values, [], 'old write does not jump slider backwards');
    equal(f.jobs[1].args, ['set', '50'], 'write queue coalesced');
    f.jobs[1].resolve('50%');
    await flush();
    equal(f.values, [50], 'latest write visible');
    f.controller.stop();
}
{
    const f = fixture();
    f.controller.read();
    f.controller.write(1);
    f.controller.reset();
    assert(f.jobs[0].cancelled, 'monitor change cancels subprocess');
    await flush();
    equal(f.values, [], 'cancelled read has no UI callback');
    equal(f.errors, [], 'hotplug cancellation is not a user error');
    equal(f.jobs.length, 1, 'hotplug drops queued brightness writes');
    f.controller.read();
    equal(f.jobs[1].args, ['get'], 'new topology can be read');
    f.jobs[1].resolve('25%');
    await flush();
    equal(f.values, [25], 'new monitor state accepted');
    f.controller.stop();
}
{
    const f = fixture();
    f.controller.read();
    f.controller.write(50);
    f.controller.stop();
    assert(f.jobs[0].cancelled, 'disable cancels subprocess');
    f.controller.read();
    f.controller.write(60);
    await flush();
    equal(f.jobs.length, 1, 'disabled extension starts no work');
    equal(f.values, [], 'no late updates after disable');
    equal(f.errors, [], 'no late errors after disable');
}
{
    const f = fixture();
    f.controller.read();
    f.jobs[0].reject(new Error('No supported LG UltraFine'));
    await flush();
    equal(f.errors, [['No supported LG UltraFine', 'get']], 'failure reports context');
    f.controller.read();
    f.jobs[1].resolve('50%');
    await flush();
    equal(f.values, [50], 'recovers after reconnect');
    f.controller.read();
    f.jobs[2].resolve('bad data');
    await flush();
    equal(f.errors.length, 2, 'malformed output becomes controlled error');
    f.controller.stop();
}
{
    const f = fixture();
    for (const value of [-1, 101, NaN, Infinity]) {
        let failed = false;
        try {
            f.controller.write(value);
        } catch {
            failed = true;
        }
        assert(failed, 'invalid writes rejected');
    }
    equal(f.jobs.length, 0, 'invalid write never invokes backend');
    f.controller.stop();
}
{
    let errors = 0;
    const c = new BrightnessController({
        run() { throw new Error('executable missing'); },
        onValue() { throw new Error('unexpected update'); },
        onError() { errors++; },
    });
    c.read();
    await flush();
    c.read();
    await flush();
    equal(errors, 2, 'synchronous spawn errors do not wedge controller');
    c.stop();
}

// Real Gio async process tests: no monitor or Shell required.
equal(BACKEND, '/usr/local/bin/lg-brightness', 'fixed production executable');
equal(await runCommand(['%s', '50.0%'], '/usr/bin/printf').promise, '50.0%', 'async capture');
let rejected = false;
try {
    await runCommand([], '/usr/bin/false').promise;
} catch {
    rejected = true;
}
assert(rejected, 'nonzero subprocess fails cleanly');
const cancelled = runCommand(['30'], '/usr/bin/sleep');
cancelled.cancel();
try {
    await cancelled.promise;
    throw new Error('expected cancellation');
} catch (error) {
    assert(error.message.includes('cancelled'), 'cancel kills and reaps child');
}
const start = GLib.get_monotonic_time();
try {
    await runCommand(['30'], '/usr/bin/sleep', 30).promise;
    throw new Error('expected timeout');
} catch (error) {
    assert(error.message.includes('timed out'), 'timeout error is explicit');
}
assert(GLib.get_monotonic_time() - start < 3000000, 'hung child terminated promptly');
print(`LG extension: ${count} assertions passed`);
