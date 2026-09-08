# x86_64 compatibility notes

审计基准为 2026-09-08 的 `coolsnowwolf/lede` master
（`d1ab56eb79387a07705590e6882fdaf873ecaa51`）及其当日默认 feeds。LEDE master
会继续变化；每次 workflow 都会记录实际使用的源码和 feed revision。

## GitHub Actions 和 Ubuntu 24.04

- runner 固定为 `ubuntu-24.04`，避免 `ubuntu-latest` 切换镜像造成突然失败。
- `actions/checkout` 和 `actions/upload-artifact` 使用当前稳定 major `v7`。
- 删除 Docker 镜像、SDK、数据库和语言运行时的 purge 逻辑。x86_64 当前配置没有证据
  表明需要先破坏 runner 环境才能获得足够空间，工作流改为在构建前后输出磁盘用量。
- Ubuntu 24.04 中以 `libgmp-dev`、`libncurses-dev`、`genisoimage` 替代旧名称
  `libgmp3-dev`、`libncurses5-dev`/`libncursesw5-dev`、`mkisofs`；删除 Python 2、
  `fastjar`、重复的 `qemu-img`，并补充当前构建会使用的 `file`、`scdoc`、`zstd`。
- feeds 只执行一次 update 和一次 install。
- firmware artifact 只上传 `bin/targets/x86/64`；配置、revision 和符号诊断独立上传。

## Feed 和外部包

当前 LEDE 的 `feeds.conf.default` 已包含：

- `coolsnowwolf/luci` 的 `luci-app-passwall`；
- `fw876/helloworld` 的 `luci-app-ssr-plus`；
- `coolsnowwolf/packages` 和 `helloworld` 中两者所需的代理核心。

旧 workflow 在 `feeds install` 后又把 `openwrt-passwall` clone 到 `package/lienol`，会与
LuCI feed 中的 Passwall 形成两个来源，而且没有配套的 Passwall packages feed。该步骤已
删除。现在完全沿用 LEDE 维护者组合好的默认 feed 顺序：`packages` 是共享代理核心的优先
来源，`helloworld` 提供 SSR Plus 及其特有依赖，`luci` 提供 LEDE 当前的 Passwall。

## Kconfig 迁移

下表列出为了匹配当前树而进行的兼容迁移。未列出的有效选项保持原值。

rootfs 分区大小已从旧配置的 300 MiB 调整为当前固件常用的 1024 MiB（1 GiB）；
kernel 分区仍保持 16 MiB。

| 旧符号 | 当前处理 | 原因 |
| --- | --- | --- |
| `TARGET_x86_64_Generic` | `TARGET_x86_64_DEVICE_generic` | profile 名称大小写/格式早已改变；旧符号不存在。 |
| `EFI_IMAGES` | `GRUB_EFI_IMAGES` | 当前 x86 UEFI 镜像开关名称。 |
| `luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust` | `..._INCLUDE_Shadowsocks_Rust_Client` | SSR Plus 现在分别配置 client/server。 |
| `luci-app-ssr-plus_INCLUDE_V2ray_plugin` | `..._INCLUDE_Shadowsocks_V2ray_Plugin` | 当前插件符号名称。 |
| `luci-app-ssr-plus_INCLUDE_ShadowsocksR_Server` | `..._INCLUDE_ShadowsocksR_Libev_Server` | 当前实现明确为 libev server。 |
| 六个旧 `ddns-scripts_*` provider 名称 | `ddns-scripts-cloudflare`、`-freedns`、`-godaddy`、`-noip`、`-nsupdate`、`-route53` | 旧名称现在只是 `PROVIDES` 别名，不是可选 Kconfig package。 |
| `PACKAGE_wget` | `PACKAGE_wget-ssl` | `wget` 现在是虚拟 provider；显式保留带 TLS 的 GNU wget。 |

以下符号在当前源码中没有等价的独立开关，已删除：

- SSR Plus：`INCLUDE_Shadowsocks`、`INCLUDE_Trojan`、`INCLUDE_Redsocks2`。Shadowsocks
  客户端由 Rust 选项保留；Trojan 协议由仍启用的 Xray 提供；当前 SSR Plus 已不提供
  Redsocks2 选项。
- Passwall：`INCLUDE_ChinaDNS_NG`、`INCLUDE_PDNSD` 以及旧的、原本未启用的 core
  选择项。ChinaDNS-NG 已成为 Passwall 的普通依赖；PDNSD 和旧 core 开关已移除。
- LuCI：`luci-app-mwan3helper`、对应翻译、`luci-app-webadmin`、对应翻译。这些包不在
  当前 LEDE feeds，且没有引入不相关的替代包。
- OpenSSL：`OPENSSL_ENGINE_CRYPTO`、`OPENSSL_ENGINE_DIGEST`、`OPENSSL_WITH_GOST`。
  当前保留统一的 `OPENSSL_ENGINE` 开关；另外三个符号不再存在。
- OpenVPN：`ENABLE_DEF_AUTH`、`ENABLE_MULTIHOME`、`ENABLE_PF`、`ENABLE_SERVER`。
  当前 OpenVPN package 不再暴露这些编译选项；仍存在的 LZO、LZ4、fragment、
  port-share 和 small 选项保持启用。当前 LEDE 不再默认选择其父包，因此显式加入
  `openvpn-openssl`，避免这些有效子选项在 `make defconfig` 时全部被丢弃。

## 固件默认值保护

`customize.sh` 当前只修改两项内容并验证一项上游默认：

1. 把 `config_generate` 的 LAN fallback 从 `192.168.1.1` 改为 `192.168.5.1`；
2. 清除 `zzz-default-settings` 注入的 LEDE root 密码 hash，产生空密码；
3. 验证通用网络脚本仍将 `eth0` 设为 LAN，并在 `eth1` 存在时设为 WAN，不修改它。

路径不存在、匹配次数异常或替换后内容不正确都会使 workflow 失败。

## `make defconfig` 诊断

workflow 保存 requested/resolved 两份配置并比较已启用符号。若某个请求符号在
`make defconfig` 后消失，Actions 日志会产生 warning，具体列表保存在
`dropped-symbols.txt`。随后还会硬性确认 x86、x86_64、generic profile 和 UEFI
四个关键符号仍为 `y`。
