# AutoBuild OpenWrt x86_64

使用 GitHub Actions 从当前 [`coolsnowwolf/lede` master](https://github.com/coolsnowwolf/lede)
构建通用 x86_64 固件。本仓库只维护 x86_64/UEFI 构建。

## 固件默认值

- 管理地址：`192.168.5.1`
- 用户名：`root`
- 密码：空
- 通用 x86 网口：`eth0` 为 LAN；存在 `eth1` 时，`eth1` 为 WAN
- 目标：通用 x86_64，生成 gzip 压缩的 UEFI 镜像
- rootfs 分区：1024 MiB（1 GiB）

`customize.sh` 会核对上述地址、密码和网口所依赖的上游源码内容。如果 LEDE
改变了相关实现，工作流会直接报错，避免产出默认值不符合预期的固件。

## 构建

1. 打开仓库的 **Actions** 页面。
2. 选择 **Build x86_64**。
3. 点击 **Run workflow**。
4. 构建成功后下载 `OpenWrt-x86-64-*` artifact。

固件 artifact 只包含 `bin/targets/x86/64`。另一个
`x86-64-build-metadata-*` artifact 保存 LEDE/feed 版本、请求配置、`make defconfig`
后的完整配置、最终选中的软件包以及被丢弃的配置符号，便于定位上游变化。

## 配置和兼容性

- 固件功能选项维护在 `x86_64.config`。
- 当前 LEDE 默认 feeds 已包含 Passwall 和 SSR Plus，不再额外 clone 同名包。
- 并行编译失败时，工作流会自动使用 `make -j1 V=s` 重试并输出真实失败位置。
- 本次现代化涉及的符号迁移和删减见
  [`docs/x86_64-compatibility.md`](docs/x86_64-compatibility.md)。

本地不要求执行完整构建；日常验证以 GitHub Actions 为准。
