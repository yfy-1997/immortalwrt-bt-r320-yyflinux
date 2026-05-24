# 定义名为 bt_r320 的设备配置块（支持usb接口使用usb上网卡）
define Device/bt_r320
  # 设备制造商名称，会显示在固件信息和 LuCI 界面中
  DEVICE_VENDOR := Globitel
  # 设备具体型号名称
  DEVICE_MODEL := BT-R320
  
  # 指定该设备对应的设备树（DTS）文件名（不带 .dts 后缀）
  DEVICE_DTS := mt7981b-bt-r320
  # 指定设备树文件所在的目录路径（相对于当前 Makefile 的路径）
  DEVICE_DTS_DIR := ../dts
  
  # 定义该设备固件中预装的软件包（驱动、工具、插件等）
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware \	# WiFi 6 核心驱动、闭源固件以及降低 CPU 占用的无线流量分流(Offload)固件
           kmod-usb-serial-option kmod-usb-net-cdc-ether kmod-usb-net-qmi-wwan \	# 4G/5G 上网卡的底层串口、标准网卡模拟及高性能 QMI 协议驱动
           kmod-usb3 kmod-mmc kmod-fs-f2fs blockdev automount \	# USB 3.0 接口驱动、eMMC 存储控制器、F2FS 闪存文件系统、块设备工具及自动挂载
           luci-proto-qmi luci-proto-ncm	# LuCI 网页后台的 QMI 和 NCM 蜂窝网络协议配置界面插件

  # --- 以下是 eMMC 引导文件生成配置 ---
  # 声明编译后需要输出的 eMMC 引导相关文件
  ARTIFACTS := emmc-gpt.bin emmc-preloader.bin emmc-bl31-uboot.fip
  # 生成 eMMC 分区表文件 (GPT)
  ARTIFACT/emmc-gpt.bin := mt798x-gpt emmc
  # 生成 eMMC 硬件预加载程序 (BL2)，注意这里要根据你路由器的实际内存颗粒填写（如 emmc-ddr3 或 emmc-ddr4）
  ARTIFACT/emmc-preloader.bin := mt7981-bl2 emmc-ddr3
  # 生成 eMMC 版本的 U-Boot 引导程序，设备名必须与 TARGET_DEVICES 里的名字一致
  ARTIFACT/emmc-bl31-uboot.fip := mt7981-bl31-uboot bt_r320
  # -----------------------------------

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
# 设备定义结束
endef

# 将 bt_r320 这个设备加入到最终的编译目标列表中
# 只有这样，在执行 make menuconfig 时才能在 Target Images 中找到并勾选这台设备
TARGET_DEVICES += bt_r320
