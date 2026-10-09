// SPDX-License-Identifier: GPL-2.0
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/utsname.h>

static int version_proc_show(struct seq_file *m, void *v)
{
#ifdef CONFIG_SPOOF_KERNEL_VERSION
#ifdef CONFIG_SPOOF_KERNEL_VERSION_STRING
#define UTS_RELEASE_SPOOFED CONFIG_SPOOF_KERNEL_VERSION_STRING
#else
#define UTS_RELEASE_SPOOFED "5.15.222-Morphite"
#endif
#else
#define UTS_RELEASE_SPOOFED utsname()->release
#endif
	seq_printf(m, linux_proc_banner,
		utsname()->sysname,
		UTS_RELEASE_SPOOFED,
		utsname()->version);
	return 0;
}

static int __init proc_version_init(void)
{
	proc_create_single("version", 0, NULL, version_proc_show);
	return 0;
}
fs_initcall(proc_version_init);
