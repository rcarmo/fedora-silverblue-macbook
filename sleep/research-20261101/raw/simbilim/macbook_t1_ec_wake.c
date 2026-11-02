// SPDX-License-Identifier: GPL-2.0
/* Mark the embedded-controller GPE as wake-capable on MacBookPro13,3. */

#include <linux/acpi.h>
#include <linux/dmi.h>
#include <linux/errno.h>
#include <linux/init.h>
#include <linux/module.h>

static const struct dmi_system_id macbook_t1_ec_wake_dmi[] = {
	{
		.ident = "Apple MacBookPro13,3",
		.matches = {
			DMI_MATCH(DMI_PRODUCT_NAME, "MacBookPro13,3"),
		},
	},
	{}
};
MODULE_DEVICE_TABLE(dmi, macbook_t1_ec_wake_dmi);

static int __init macbook_t1_ec_wake_init(void)
{
	if (!dmi_check_system(macbook_t1_ec_wake_dmi))
		return -ENODEV;

	acpi_ec_mark_gpe_for_wake();
	pr_info("marked the ACPI embedded-controller GPE as wake-capable\n");
	return 0;
}

static void __exit macbook_t1_ec_wake_exit(void)
{
}

module_init(macbook_t1_ec_wake_init);
module_exit(macbook_t1_ec_wake_exit);

MODULE_AUTHOR("MacBookPro13,3 Omarchy support kit");
MODULE_DESCRIPTION("Enable ACPI EC wake for MacBookPro13,3 lid-open resume");
MODULE_LICENSE("GPL");
