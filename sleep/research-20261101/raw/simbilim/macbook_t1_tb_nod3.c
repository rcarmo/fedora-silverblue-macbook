// SPDX-License-Identifier: GPL-2.0
/*
 * Keep the MacBookPro13,3 Alpine Ridge upstream bridges and USB-C xHCIs out
 * of D3 during s2idle.
 *
 * Their ACPI _PS0 (UPSB.PCED and friends) polls a mailbox through the wrong
 * PCI device on Linux and runs into timeouts, costing 8-9 s per controller on
 * every s2idle resume. A device that never leaves D0 skips _PS3/_PS0. In S3
 * the sleep helper removes these trees entirely, so this only affects s2idle
 * and runtime PM. A bus notifier re-applies the flag after the PCI rescan
 * that follows S3.
 *
 * The USB-C xHCIs also miss hot-plug events while runtime-suspended, so
 * runtime PM is forbidden on them once xhci_hcd has bound (the driver
 * allows it during probe, which is why a udev rule on "add" was too early).
 */

#include <linux/dmi.h>
#include <linux/module.h>
#include <linux/notifier.h>
#include <linux/pci.h>
#include <linux/pm_runtime.h>

static const struct dmi_system_id macbook_t1_tb_nod3_dmi[] = {
	{
		.ident = "Apple MacBookPro13,3",
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "Apple Inc."),
			DMI_MATCH(DMI_PRODUCT_NAME, "MacBookPro13,3"),
		},
	},
	{}
};
MODULE_DEVICE_TABLE(dmi, macbook_t1_tb_nod3_dmi);

/* Built-in Alpine Ridge functions only: they sit below PEG1/PEG2 (00:01.1/2). */
static bool macbook_t1_tb_nod3_match(struct pci_dev *dev)
{
	struct pci_dev *root = pcie_find_root_port(dev);

	if (dev->vendor != PCI_VENDOR_ID_INTEL)
		return false;
	if (dev->device != 0x1578 && dev->device != 0x15d4)
		return false;
	return root && root->bus->number == 0 &&
	       (root->devfn == PCI_DEVFN(1, 1) || root->devfn == PCI_DEVFN(1, 2));
}

static void macbook_t1_tb_nod3_apply(struct pci_dev *dev)
{
	if (!macbook_t1_tb_nod3_match(dev) ||
	    (dev->dev_flags & PCI_DEV_FLAGS_NO_D3))
		return;
	dev->dev_flags |= PCI_DEV_FLAGS_NO_D3;
	pci_info(dev, "keeping in D0 across s2idle\n");
}

static void macbook_t1_tb_nod3_keep_xhci_awake(struct pci_dev *dev)
{
	if (dev->device != 0x15d4 || !macbook_t1_tb_nod3_match(dev))
		return;
	pm_runtime_forbid(&dev->dev);
	pci_info(dev, "keeping awake for USB-C hot-plug\n");
}

static int macbook_t1_tb_nod3_notify(struct notifier_block *nb,
				     unsigned long action, void *data)
{
	struct pci_dev *dev = to_pci_dev(data);

	if (action == BUS_NOTIFY_ADD_DEVICE)
		macbook_t1_tb_nod3_apply(dev);
	else if (action == BUS_NOTIFY_BOUND_DRIVER)
		macbook_t1_tb_nod3_keep_xhci_awake(dev);
	return NOTIFY_DONE;
}

static struct notifier_block macbook_t1_tb_nod3_nb = {
	.notifier_call = macbook_t1_tb_nod3_notify,
};

static int __init macbook_t1_tb_nod3_init(void)
{
	struct pci_dev *dev = NULL;
	int ret;

	if (!dmi_check_system(macbook_t1_tb_nod3_dmi))
		return -ENODEV;
	ret = bus_register_notifier(&pci_bus_type, &macbook_t1_tb_nod3_nb);
	if (ret)
		return ret;
	for_each_pci_dev(dev) {
		macbook_t1_tb_nod3_apply(dev);
		if (dev->dev.driver)
			macbook_t1_tb_nod3_keep_xhci_awake(dev);
	}
	return 0;
}

static void __exit macbook_t1_tb_nod3_exit(void)
{
	struct pci_dev *dev = NULL;

	bus_unregister_notifier(&pci_bus_type, &macbook_t1_tb_nod3_nb);
	for_each_pci_dev(dev) {
		if (!macbook_t1_tb_nod3_match(dev))
			continue;
		dev->dev_flags &= ~PCI_DEV_FLAGS_NO_D3;
		if (dev->device == 0x15d4 && dev->dev.driver)
			pm_runtime_allow(&dev->dev);
	}
}

module_init(macbook_t1_tb_nod3_init);
module_exit(macbook_t1_tb_nod3_exit);

MODULE_AUTHOR("MacBookPro13,3 Omarchy support kit");
MODULE_DESCRIPTION("Keep MacBookPro13,3 Alpine Ridge bridges and USB-C xHCIs in D0 across s2idle");
MODULE_LICENSE("GPL");
