// SPDX-License-Identifier: GPL-2.0
/*
 * macbook_t1_socw — send the T1 (iBridge) its host sleep/wake message.
 *
 * Adapted from simbilim/omarchy-macbookpro13-3-t1 macbook_t1_socw.c
 * (copy: ../sleep-research-20261101/raw/simbilim/macbook_t1_socw.c).
 *
 * After S3 the T1 keeps the Touch Bar dark until ASOC.SOCW(1) is evaluated
 * (macOS sends SOCW(0) before sleep, SOCW(1) after wake). apple-ibridge skips
 * SOCW entirely (skip_acpi_power=1) because SOCW(1) at PROBE hard-froze T1
 * Macs; this module never runs anything at load.
 *
 * Changes vs upstream copy:
 *  - DMI: MacBookPro13,2 added (13,3 kept).
 *  - No wake_now parameter; nothing is evaluated at load time.
 *  - PM notifier action is opt-in: auto_resume=1 (default 0) calls SOCW(1)
 *    on PM_POST_SUSPEND. Default use is via the "socw" parameter from the
 *    sleep hook (pre: 0, post: 1).
 *  - auto_resume only acts after S3 (PM_SUSPEND_MEM target); manual writes are
 *    the caller's responsibility (the hook only uses them around deep sleeps).
 *  - Counters exposed read-only (calls_ok, calls_failed, last_value).
 */

#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/acpi.h>
#include <linux/dmi.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/suspend.h>

#define ASOC_SOCW "\\_SB.PCI0.XHC1.RHUB.ASOC.SOCW"

static acpi_handle socw;
static DEFINE_MUTEX(socw_lock);

static unsigned int calls_ok;
module_param(calls_ok, uint, 0444);
MODULE_PARM_DESC(calls_ok, "Successful SOCW evaluations");

static unsigned int calls_failed;
module_param(calls_failed, uint, 0444);
MODULE_PARM_DESC(calls_failed, "Failed SOCW evaluations");

static int last_value = -1;
module_param(last_value, int, 0444);
MODULE_PARM_DESC(last_value, "Last SOCW argument evaluated (-1 = none)");

static bool auto_resume;
module_param(auto_resume, bool, 0644);
MODULE_PARM_DESC(auto_resume, "Evaluate SOCW(1) from the PM notifier after suspend (default off)");

static int macbook_t1_socw_eval(u64 value)
{
	unsigned long long result = 0;
	union acpi_object arg = { .integer = { .type = ACPI_TYPE_INTEGER, .value = value } };
	struct acpi_object_list args = { .count = 1, .pointer = &arg };
	acpi_status status;
	int ret = 0;

	mutex_lock(&socw_lock);
	pr_info("evaluating SOCW(%llu)\n", value);
	status = acpi_evaluate_integer(socw, NULL, &args, &result);
	if (status == AE_BAD_DATA || status == AE_TYPE) {
		/* method may return nothing; retry without result */
		status = acpi_evaluate_object(socw, NULL, &args, NULL);
	}
	if (ACPI_FAILURE(status)) {
		calls_failed++;
		pr_warn("SOCW(%llu) failed: %s\n", value, acpi_format_exception(status));
		ret = -EIO;
	} else {
		calls_ok++;
		last_value = (int)value;
		pr_info("SOCW(%llu) sent T1 %s, result %llu\n", value,
			value ? "wake" : "sleep", result);
	}
	mutex_unlock(&socw_lock);
	return ret;
}

static int socw_param_set(const char *val, const struct kernel_param *kp)
{
	unsigned int v;
	int ret = kstrtouint(val, 0, &v);

	if (ret)
		return ret;
	if (v > 1)
		return -EINVAL;
	if (!socw)
		return -ENODEV;
	return macbook_t1_socw_eval(v);
}

static const struct kernel_param_ops socw_param_ops = {
	.set = socw_param_set,
};
module_param_cb(socw, &socw_param_ops, NULL, 0200);
MODULE_PARM_DESC(socw, "Write 0 or 1 to evaluate ASOC.SOCW(0|1) now");

static const struct dmi_system_id macbook_t1_socw_dmi[] = {
	{
		.ident = "Apple MacBookPro13,2",
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "Apple Inc."),
			DMI_MATCH(DMI_PRODUCT_NAME, "MacBookPro13,2"),
		},
	},
	{
		.ident = "Apple MacBookPro13,3",
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "Apple Inc."),
			DMI_MATCH(DMI_PRODUCT_NAME, "MacBookPro13,3"),
		},
	},
	{}
};
MODULE_DEVICE_TABLE(dmi, macbook_t1_socw_dmi);

static int macbook_t1_socw_pm(struct notifier_block *nb, unsigned long action,
			      void *data)
{
	if (action == PM_POST_SUSPEND && auto_resume &&
	    pm_suspend_target_state == PM_SUSPEND_MEM)
		macbook_t1_socw_eval(1);
	return NOTIFY_DONE;
}

static struct notifier_block macbook_t1_socw_nb = {
	.notifier_call = macbook_t1_socw_pm,
};

static int __init macbook_t1_socw_init(void)
{
	if (!dmi_check_system(macbook_t1_socw_dmi))
		return -ENODEV;
	if (ACPI_FAILURE(acpi_get_handle(NULL, ASOC_SOCW, &socw))) {
		pr_err("%s not found\n", ASOC_SOCW);
		return -ENODEV;
	}
	pr_info("loaded; nothing evaluated (socw param / auto_resume=%d)\n", auto_resume);
	return register_pm_notifier(&macbook_t1_socw_nb);
}

static void __exit macbook_t1_socw_exit(void)
{
	unregister_pm_notifier(&macbook_t1_socw_nb);
}

module_init(macbook_t1_socw_init);
module_exit(macbook_t1_socw_exit);

MODULE_AUTHOR("MacBookPro13,3 Omarchy support kit; adapted for MacBookPro13,2");
MODULE_DESCRIPTION("Send the T1 its host sleep/wake message (ASOC.SOCW)");
MODULE_LICENSE("GPL");
