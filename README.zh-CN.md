# synology-auto-mount

简体中文 | [English](README.md)

**把群晖（或任意 SMB）NAS 共享在 macOS 上稳定挂载成本地盘——重启、睡眠唤醒、断网后自动重连。**

挂载好的共享出现在访达和终端的 `/Volumes/<共享名>`，与本地盘体验一致；一个轻量 launchd 守护在掉线后 60 秒内自动重挂。全程零 sudo，密码只存 macOS 钥匙串（由系统自己保存），不写入任何文件。

## 为什么需要它

macOS 上自动挂载 SMB 共享的每种"标准"做法都有坑：

| 方案 | 失效原因 |
| --- | --- |
| 访达"登录时打开" | 睡眠唤醒/断网后不会重连；开机网络未就绪时连接失败 |
| `/etc/fstab` | 开机时网络未就绪直接失败，之后不再重试 |
| `autofs` | macOS 已知 bug（重启后以 root 挂载、唤醒后不重挂） |
| `mount_smbfs` + CLI 钥匙串条目 | **新版 macOS 上静默失败**——Apple 的分区校验让 `mount_smbfs` 读不到 `security add-internet-password` 建的条目，它自己也不会存 |
| Synology Drive | 是同步客户端不是挂载，数据会重复占用本地磁盘 |

本项目用的是唯一在无人值守下可靠工作的通道：**`osascript mount volume`**（访达认证栈）。密码由 macOS 在安装时的一次带凭据挂载中自己存进钥匙串；挂载点 `/Volumes/<共享名>` 由系统自动创建（免 sudo）；LaunchAgent 每 60 秒检查一次，掉线即重挂。

## 安装

```sh
git clone https://github.com/mahingbun-dev/synology-auto-mount.git
cd synology-auto-mount
./install.sh                          # 交互式
./install.sh HOST SHARE USER 'PASS'   # 非交互
```

示例：

```sh
./install.sh 192.0.2.1 MyShare nasuser '你的密码'
```

`SHARE` 是 DSM 控制面板 → 共享文件夹里配置的名称（不是 `/volume2/...` 路径）。要挂共享下的子目录，写成 `SHARE/子目录`。

安装器依次完成：

1. 预检：NAS 的 445 端口（SMB）可达。
2. 带凭据连接一次——macOS 把密码存入**登录钥匙串**。
3. 生成巡检脚本 `~/.local/bin/synology-automount.sh`。
4. 卸载后**免密**重挂一次，验证钥匙串链路可用。
5. 安装并加载 `~/Library/LaunchAgents/dev.mahingbun.synology-automount.plist`（`RunAtLoad` + `StartInterval=60`）。

安装前想预览？`DRY_RUN=1 ./install.sh ...` 只打印不写盘。

## 验证

```sh
mount | grep smbfs                                # 能看到 (smbfs, ...)
diskutil unmount /Volumes/<共享名>                 # 手动推出…
# …60 秒内自动回来：
mount | grep smbfs
tail -n 20 ~/Library/Logs/synology-automount.log  # 守护做了什么
```

重启 Mac 后登录即自动挂载，无任何弹窗。

## 它如何避免打扰你

- **已挂载** → 脚本瞬间退出。
- **NAS 不可达**（不在局域网/NAS 休眠）→ 2 秒 TCP 探测先行退出，不会卡 Apple event、不会弹密码框。
- 不可达/掉线/重挂都会记录到 `~/Library/Logs/synology-automount.log`。

## 故障排查

| 症状 | 处理 |
| --- | --- |
| "First mount failed" | 账号/密码错误，或 DSM 未开 SMB 服务。先在访达 `Cmd+K` 连 `smb://主机` 验证 |
| 免密重挂失败 | 访达 `Cmd+K` 连接共享并勾选「在我的钥匙串中记住此密码」，重跑 `install.sh` |
| 挂载在但访问卡死（睡眠后僵尸挂载） | `diskutil unmount force /Volumes/<共享名>`——巡检会自动重挂 |
| 想暂停自动重连 | `launchctl unload ~/Library/LaunchAgents/dev.mahingbun.synology-automount.plist`（恢复用 `load`） |
| Time Machine 老想用它 | 共享里有 `.sparsebundle` 时系统可能提议作为备份目标，拒绝即可 |

## 卸载

```sh
./uninstall.sh
```

移除 LaunchAgent 与巡检脚本；可选卸载卷、删除钥匙串条目。

## 安全说明

- 密码**只**存在于你的登录钥匙串，由 macOS 自己写入；任何配置文件、点文件、仓库中都不含密码。
- 安装脚本支持把密码作为参数（`./install.sh … 'PASS'`）以便 agent/CI 使用——密码仅在安装期间短暂出现在进程列表里。
- 所有安装产物归当前用户所有，没有任何组件以 root 运行。

## 环境要求

- macOS——无第三方依赖（开发与实测环境：macOS 26/27）
- 开启 SMB 服务的群晖 NAS（或任意 SMB 服务器）——实测 DSM 7.4

## License

[MIT](LICENSE.md)
