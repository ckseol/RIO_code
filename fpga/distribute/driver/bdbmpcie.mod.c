#include <linux/module.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

MODULE_INFO(vermagic, VERMAGIC_STRING);

__visible struct module __this_module
__attribute__((section(".gnu.linkonce.this_module"))) = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

static const struct modversion_info ____versions[]
__used
__attribute__((section("__versions"))) = {
	{ 0x96cec1da, __VMLINUX_SYMBOL_STR(module_layout) },
	{ 0xe2df5ec3, __VMLINUX_SYMBOL_STR(class_destroy) },
	{ 0xecd5faa7, __VMLINUX_SYMBOL_STR(device_destroy) },
	{ 0xe76fedf3, __VMLINUX_SYMBOL_STR(cdev_del) },
	{ 0xa997e3f1, __VMLINUX_SYMBOL_STR(pci_unregister_driver) },
	{ 0xce17ea11, __VMLINUX_SYMBOL_STR(__free_pages) },
	{ 0x436c2179, __VMLINUX_SYMBOL_STR(iowrite32) },
	{ 0x4c9d28b0, __VMLINUX_SYMBOL_STR(phys_base) },
	{ 0x95344561, __VMLINUX_SYMBOL_STR(alloc_pages_current) },
	{ 0xd2b09ce5, __VMLINUX_SYMBOL_STR(__kmalloc) },
	{ 0x37a0cba, __VMLINUX_SYMBOL_STR(kfree) },
	{ 0x4302d0eb, __VMLINUX_SYMBOL_STR(free_pages) },
	{ 0x1631721, __VMLINUX_SYMBOL_STR(device_create) },
	{ 0x61dd05b8, __VMLINUX_SYMBOL_STR(__class_create) },
	{ 0x7485e15e, __VMLINUX_SYMBOL_STR(unregister_chrdev_region) },
	{ 0xd94c6e2f, __VMLINUX_SYMBOL_STR(cdev_add) },
	{ 0x1b4099ef, __VMLINUX_SYMBOL_STR(cdev_init) },
	{ 0x29537c9e, __VMLINUX_SYMBOL_STR(alloc_chrdev_region) },
	{ 0x13b81555, __VMLINUX_SYMBOL_STR(__pci_register_driver) },
	{ 0x6ce2322d, __VMLINUX_SYMBOL_STR(dma_ops) },
	{ 0xa1c76e0a, __VMLINUX_SYMBOL_STR(_cond_resched) },
	{ 0xe484e35f, __VMLINUX_SYMBOL_STR(ioread32) },
	{ 0x90ded659, __VMLINUX_SYMBOL_STR(pci_set_master) },
	{ 0x2072ee9b, __VMLINUX_SYMBOL_STR(request_threaded_irq) },
	{ 0xf6d780b0, __VMLINUX_SYMBOL_STR(pci_bus_read_config_byte) },
	{ 0xcf6bc653, __VMLINUX_SYMBOL_STR(pci_enable_msi_range) },
	{ 0x4dd278b2, __VMLINUX_SYMBOL_STR(pci_iomap) },
	{ 0x5998e623, __VMLINUX_SYMBOL_STR(pci_request_regions) },
	{ 0xed00471a, __VMLINUX_SYMBOL_STR(pci_bus_read_config_dword) },
	{ 0xe02a1009, __VMLINUX_SYMBOL_STR(pci_bus_write_config_word) },
	{ 0xa098b005, __VMLINUX_SYMBOL_STR(pci_enable_device) },
	{ 0x65ff8006, __VMLINUX_SYMBOL_STR(pci_find_capability) },
	{ 0x8d36dd74, __VMLINUX_SYMBOL_STR(pci_bus_read_config_word) },
	{ 0xa6bbd805, __VMLINUX_SYMBOL_STR(__wake_up) },
	{ 0x1916e38c, __VMLINUX_SYMBOL_STR(_raw_spin_unlock_irqrestore) },
	{ 0x680ec266, __VMLINUX_SYMBOL_STR(_raw_spin_lock_irqsave) },
	{ 0x3637f396, __VMLINUX_SYMBOL_STR(pci_disable_device) },
	{ 0x8fd674, __VMLINUX_SYMBOL_STR(pci_release_regions) },
	{ 0x25f9673f, __VMLINUX_SYMBOL_STR(pci_iounmap) },
	{ 0x38d321c0, __VMLINUX_SYMBOL_STR(pci_disable_msi) },
	{ 0xf20dabd8, __VMLINUX_SYMBOL_STR(free_irq) },
	{ 0x3ce4ca6f, __VMLINUX_SYMBOL_STR(disable_irq) },
	{ 0xc13be14a, __VMLINUX_SYMBOL_STR(pci_clear_master) },
	{ 0x6fef8a97, __VMLINUX_SYMBOL_STR(remap_pfn_range) },
	{ 0x5944d015, __VMLINUX_SYMBOL_STR(__cachemode2pte_tbl) },
	{ 0x4c4f1833, __VMLINUX_SYMBOL_STR(boot_cpu_data) },
	{ 0x27e1a049, __VMLINUX_SYMBOL_STR(printk) },
	{ 0x163175ad, __VMLINUX_SYMBOL_STR(vm_insert_page) },
	{ 0xbdfb6dbb, __VMLINUX_SYMBOL_STR(__fentry__) },
};

static const char __module_depends[]
__used
__attribute__((section(".modinfo"))) =
"depends=";

MODULE_ALIAS("pci:v000010EEd00007028sv*sd*bc*sc*i*");

MODULE_INFO(srcversion, "B3B04B9EC6AF494073295F9");
