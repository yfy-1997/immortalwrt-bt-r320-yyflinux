# 此为演示模版
# 将 MediaTek 的设备树（DTS）目录追加到现有的 DTS 搜索路径中
DTS_DIR := $(DTS_DIR)/mediatek
# 声明 Teltonika 设备支持列表和硬件模块变量，确保这些变量在设备定义间正确传递
DEVICE_VARS += SUPPORTED_TELTONIKA_DEVICES
DEVICE_VARS += SUPPORTED_TELTONIKA_HW_MODS

# 【镜像准备阶段】
# 在构建 UBI 文件系统镜像前，生成一个特殊的标记文件 ubi_mark
define Image/Prepare
	# For UBI we want only one extra block (为 UBI 仅保留一个额外的块)
	rm -f $(KDIR)/ubi_mark
	# 写入特定的魔数（Magic Number）标记
	echo -ne '\xde\xad\xc0\xde' > $(KDIR)/ubi_mark
endef

# 【构建步骤：Netgear 专用 FIT 镜像生成】
# 为 Netgear 设备生成包含顶层 rootfs 节点的 FIT (Flattened Image Tree) 镜像
define Build/fit-with-netgear-top-level-rootfs-node
	# 调用标准宏生成 FIT 的 .its 描述文件
	$(call Build/fit-its,$(1))
	# 使用专用脚本生成 rootfs 节点数据
	$(TOPDIR)/scripts/gen_netgear_rootfs_node.sh $(KERNEL_BUILD_DIR)/root.squashfs$(if $(TARGET_PER_DEVICE_ROOTFS),+pkg=$(ROOTFS_ID/$(DEVICE_NAME))) > $@.rootfs
	# 使用 awk 将生成的 rootfs 节点插入到 .its 文件的 configurations 字段中
	awk '/configurations/ { system("cat $@.rootfs") } 1' $@.its > $@.its.tmp
	@mv -f $@.its.tmp $@.its
	@rm -f $@.rootfs
	# 最终根据修改后的 .its 文件生成 FIT 镜像
	$(call Build/fit-image,$(1))
endef

# ================= MT798x 系列芯片的 BL2 和 BL31 预编译固件拼接 =================
# 以下宏用于将预编译好的 Bootloader (BL2) 和 ARM Trusted Firmware (BL31/U-Boot FIP) 拼接到最终镜像中

# MT7981 芯片的 BL2 和 BL31 拼接
define Build/mt7981-bl2
	cat $(STAGING_DIR_IMAGE)/mt7981-$1-bl2.img >> $@
endef
define Build/mt7981-bl31-uboot
	cat $(STAGING_DIR_IMAGE)/mt7981_$1-u-boot.fip >> $@
endef

# MT7986 芯片的 BL2 和 BL31 拼接
define Build/mt7986-bl2
	cat $(STAGING_DIR_IMAGE)/mt7986-$1-bl2.img >> $@
endef
define Build/mt7986-bl31-uboot
	cat $(STAGING_DIR_IMAGE)/mt7986_$1-u-boot.fip >> $@
endef

# MT7987 芯片的 BL2 和 BL31 拼接
define Build/mt7987-bl2
	cat $(STAGING_DIR_IMAGE)/mt7987-$1-bl2.img >> $@
endef
define Build/mt7987-bl31-uboot
	cat $(STAGING_DIR_IMAGE)/mt7987_$1-u-boot.fip >> $@
endef

# MT7988 芯片的 BL2 和 BL31 拼接
define Build/mt7988-bl2
	cat $(STAGING_DIR_IMAGE)/mt7988-$1-bl2.img >> $@
endef
define Build/mt7988-bl31-uboot
	cat $(STAGING_DIR_IMAGE)/mt7988_$1-u-boot.fip >> $@
endef

# ================= 分区表与 GPT 生成 =================

# 生成简单的 FIT 分区表 (Simple FIT partition table)
define Build/simplefit
	cp $@ $@.tmp 2>/dev/null || true
	# 使用 ptgen 工具生成分区表，包含一个 FIT 分区
	ptgen -g -o $@.tmp -a 1 -l 1024 \
	-t 0x2e -N FIT		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@17k
	cat $@.tmp >> $@
	rm $@.tmp
endef

# 为 MT798x 系列生成标准的 GPT 分区表
# 参数 $1 用于判断存储介质类型（如 sdmmc 或 emmc）
define Build/mt798x-gpt
	cp $@ $@.tmp 2>/dev/null || true
	ptgen -g -o $@.tmp -a 1 -l 1024 \
		$(if $(findstring sdmmc,$1), \
			-H \
			-t 0x83	-N bl2		-r	-p 4079k@17k \
		) \
			-t 0x83	-N ubootenv	-r	-p 512k@4M \
			-t 0x83	-N factory	-r	-p 2M@4608k \
			-t 0xef	-N fip		-r	-p 4M@6656k \
				-N recovery	-r	-p 32M@12M \
		$(if $(findstring sdmmc,$1), \
				-N install	-r	-p 20M@44M \
			-t 0x2e -N production		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M \
		) \
		$(if $(findstring emmc,$1), \
			-t 0x2e -N production		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M \
		)
	cat $@.tmp >> $@
	rm $@.tmp
endef

# ================= 具体设备定义 =================

# 定义名为 xxx_switch 的设备配置块
define Device/xxx_switch
  
  DEVICE_VENDOR := xxx                        # 设备制造商名称
  DEVICE_MODEL := xxx_model                   # 设备型号名称
  
  DEVICE_DTS := mt7981b-xxx_model             # 指定该设备对应的设备树
  DEVICE_DTS_DIR := ../dts                    # 指定设备树文件所在的目录路径
  
  
  DEVICE_PACKAGES := kmod-mt7915e             # DEVICE_PACKAGES 定义以下软件包：
  
  UBINIZE_OPTS := -E 5                        # 生成 UBI 文件系统时的额外参数，-E 5 表示预留 5 个物理块用于坏块处理
  BLOCKSIZE := 128k                           # 定义底层闪存（NAND）的物理块大小为 128KB
  PAGESIZE := 2048                            # 定义底层闪存的物理页大小为 2048 字节
  KERNEL_IN_UBI := 1                          # 标识 Linux 内核（Kernel）需要被打包存储在 UBI 卷中，而非独立分区
  UBOOTENV_IN_UBI := 1                        # 标识 U-Boot 的环境变量也需要存储在 UBI 卷中
  IMAGES := sysupgrade.itb                    # 指定最终生成的标准系统升级固件文件名为 sysupgrade.itb
  # 定义常规内核（Kernel）的生成与打包方式
  # kernel-bin: 提取原始内核 -> lzma: 使用 lzma 算法压缩 -> fit: 生成 FIT 格式镜像并打包对应的 dtb 设备树文件
  KERNEL := kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  
  # 定义 RAMFS（内存版/急救模式）内核的生成方式
  # with-initrd: 在镜像中包含 initramfs（初始内存文件系统），用于不依赖闪存进行刷机或修复
  # pad-to 64k: 将生成的文件按 64KB 进行内存对齐填充，防止某些 Bootloader 加载异常
  KERNEL_INITRAMFS := kernel-bin | lzma | \
  fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  
  # 定义 sysupgrade（系统升级）固件的生成方式
  # sysupgrade-tar: 将固件打包成 tar 压缩包格式
  # append-metadata: 在固件末尾追加元数据（如设备型号、版本等），用于刷机时的合法性校验，防止刷错设备变砖
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata

  # 定义需要额外生成的产物（预加载器和 U-Boot FIP）
  ARTIFACTS := preloader.bin bl31-uboot.fip   # 声明除了主固件外，还需要额外生成预加载器（preloader）和 FIP 包这两个文件
  ARTIFACT/preloader.bin := mt7981-bl2 spim-nand-ddr3  # 调用 mt7981-bl2 构建步骤，生成适用于 SPI-NAND 闪存和 DDR3 内存的预加载器
  ARTIFACT/bl31-uboot.fip := mt7981-bl31-uboot abt_asr3000  # 调用 mt7981-bl31-uboot 构建步骤，生成该设备专属的 U-Boot FIP 包
  
# 设备定义结束
endef
# 将 xxx_switch 这个设备加入到最终的编译目标列表中
# 只有这样，在执行 make menuconfig 时才能在 Target Images 中找到并勾选这台设备
TARGET_DEVICES += xxx_switch

