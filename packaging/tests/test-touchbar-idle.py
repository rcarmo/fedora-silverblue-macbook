#!/usr/bin/env python3
"""Run the actual driver worker/update functions with mocked hardware and time.

No modules are loaded and no sysfs/PCI writes occur. Requires a C compiler.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "packaging/sources/macbook-t1-touchbar-0.1.20261110/apple-touchbar.c"
source = SOURCE.read_text()


def function(name):
    start = re.search(r"^static [^\n]+ " + name + r"\(", source, re.M).start()
    body = source.index("{", start)
    depth = 1
    end = body + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


constants = "\n".join(re.findall(r"^#define APPLETB_CMD_.*$", source, re.M))
harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
typedef long long s64;
struct work_struct { int unused; };
struct delayed_work { struct work_struct work; };
struct hid_report { void *device; };
struct hid_field { struct hid_report *report; };
struct appletb_device {
    struct delayed_work tb_work;
    struct hid_field *disp_field;
    unsigned char pnd_tb_mode, pnd_tb_disp, cur_tb_mode, cur_tb_disp;
    bool restore_autopm, tb_autopm_off, is_t1;
    int tb_lock, idle_timeout, dim_timeout;
    s64 last_event_time;
};
static s64 now, scheduled;
static bool pressed, fail_mode;
static int modes, displays;
#define container_of(p, type, field) ((type *)((char *)(p) - offsetof(type, field)))
#define spin_lock_irqsave(lock, flags) ((void)(lock), (flags) = 0)
#define spin_unlock_irqrestore(lock, flags) ((void)(lock), (void)(flags))
#define dev_dbg(...) ((void)0)
#define dev_dbg_ratelimited(...) ((void)0)
#define min(a,b) ((a) < (b) ? (a) : (b))
#define max(a,b) ((a) > (b) ? (a) : (b))
#define ktime_get() now
#define ktime_ms_delta(a,b) ((a)-(b))
#define msleep(ms) ((void)(ms))
static int appletb_set_tb_mode(struct appletb_device *d, unsigned char m)
{ (void)d; assert(m != APPLETB_CMD_MODE_NONE); modes++; return fail_mode ? -1 : 0; }
static int appletb_set_tb_disp(struct appletb_device *d, unsigned char m)
{ (void)d; (void)m; displays++; return 0; }
static void appletb_disable_autopm(void *d) { (void)d; }
static bool appletb_any_tb_key_pressed(struct appletb_device *d)
{ (void)d; return pressed; }
static void appletb_schedule_tb_update(struct appletb_device *d, s64 secs)
{ (void)d; scheduled = secs; }
static void cancel_delayed_work(struct delayed_work *w) { (void)w; }
static unsigned char appletb_get_fn_tb_mode(struct appletb_device *d)
{ (void)d; return APPLETB_CMD_MODE_FN; }
'''
tests = r'''
static struct appletb_device initial(bool t1) {
    modes = displays = 0; scheduled = -99; pressed = fail_mode = false;
    now = 30000;
    return (struct appletb_device) {
        .is_t1 = t1, .idle_timeout = 30, .dim_timeout = -2,
        .pnd_tb_mode = APPLETB_CMD_MODE_NONE, .pnd_tb_disp = APPLETB_CMD_DISP_NONE,
        .cur_tb_mode = APPLETB_CMD_MODE_FN, .cur_tb_disp = APPLETB_CMD_DISP_ON,
    };
}
static void run(struct appletb_device *d) { appletb_set_tb_worker(&d->tb_work.work); }
int main(void) {
    struct appletb_device d = initial(true);
    run(&d);
    assert(modes == 1 && displays == 0 && d.cur_tb_mode == APPLETB_CMD_MODE_OFF);
    /* Real input path updates last_event_time then calls this function. */
    d.last_event_time = now;
    appletb_update_touchbar_no_lock(&d, false);
    assert(d.pnd_tb_mode == APPLETB_CMD_MODE_FN && scheduled == 0);
    run(&d);
    assert(d.cur_tb_mode == APPLETB_CMD_MODE_FN && scheduled == 30);

    d = initial(false); run(&d);
    assert(modes == 0 && displays == 1 && d.cur_tb_disp == APPLETB_CMD_DISP_OFF);
    d = initial(true); now = 10000; run(&d);
    assert(modes == 0 && displays == 0 && scheduled == 20);
    d = initial(true); pressed = true; run(&d);
    assert(modes == 0 && scheduled == 30);
    d = initial(true); fail_mode = true; run(&d);
    assert(modes == 1 && d.cur_tb_mode == APPLETB_CMD_MODE_FN);
    d = initial(true); d.idle_timeout = -1; run(&d); assert(modes == 0);
    d = initial(true); d.idle_timeout = 0; run(&d); assert(modes == 0);
    d = initial(true); d.idle_timeout = -2; run(&d); assert(modes == 0);
    d = initial(true); d.dim_timeout = 10; now = 10000; run(&d);
    assert(modes == 0 && displays == 1 && scheduled == 20);
    puts("PASS: T1 blank/restore, non-T1, timeout, held key, command failure, disabled idle, dim");
}
'''
with tempfile.TemporaryDirectory(prefix="touchbar-idle-test-") as temp:
    cfile = Path(temp) / "test.c"
    binary = Path(temp) / "test"
    cfile.write_text("\n".join([
        constants, harness,
        function("appletb_set_tb_worker"),
        function("appletb_get_cur_tb_mode"),
        function("appletb_get_cur_tb_disp"),
        function("appletb_update_touchbar_no_lock"), tests,
    ]))
    subprocess.run(["cc", "-std=gnu11", "-Wall", "-Wextra", "-Werror", str(cfile), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
