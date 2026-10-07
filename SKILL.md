---
name: synology-auto-mount
slug: synology-auto-mount
displayName: Synology Auto Mount
version: 1.0.0
description: 把群晖/Synology（或任意 SMB）NAS 共享在 macOS 上挂载成本地盘：开机自动挂载、断线/睡眠唤醒后 60 秒内自动重连、零 sudo、密码只存钥匙串不落盘。Use when the user wants to mount a NAS/SMB shared folder on macOS with auto-remount after reboot/sleep, 群晖挂载、NAS 自动重连、网络硬盘像本地盘、smb automount、keep smb share mounted.
---

# Skill: synology-auto-mount（macOS NAS 共享稳定挂载）

## 目标

把 NAS 的 SMB 共享挂载到 `/Volumes/<共享名>`，且：

- 开机/登录后自动挂载（LaunchAgent `RunAtLoad`）；
- 掉线、睡眠唤醒、拔网线后 ≤60 秒自动重连（`StartInterval` 巡检）；
- Finder/命令行体验与本地盘一致；
- 密码只存 macOS 钥匙串，不写入任何文件，全程零 sudo。

## 技术要点（为什么这样做）

- **挂载动作走 `osascript -e 'mount volume ...'`（Finder 认证栈），不走 `mount_smbfs` 直连。**
  实测 macOS 26/27 上：`security` CLI 建的钥匙串条目 `mount_smbfs` 读不到（Apple 分区校验拒绝），
  `mount_smbfs` 也不会自动把密码存进钥匙串；而 `mount volume` 会用 Finder 自己存进钥匙串的凭据免密挂载，
  并自动创建 `/Volumes/<共享名>` 挂载点。
- **launchd 巡检脚本先 `nc -z -G 2 <host> 445` 预检**：NAS 不可达时快速退出，避免 Apple event 卡住和弹出密码框。
- **不做 autofs**（重启后 root 权限挂载 bug、睡眠唤醒不重连）、**不做 fstab**（网络未就绪失败后不重试）。

## 安装步骤

仓库地址：https://github.com/mahingbun-dev/synology-auto-mount

1. 克隆或下载仓库，进入目录，运行安装器（支持两种方式）：

   ```sh
   # 交互式：逐项询问
   ./install.sh

   # 非交互（agent 可直接代跑，四个参数：主机 共享名 用户名 密码）
   ./install.sh 192.168.31.165 MacHardDrive Mr.Ma '密码'
   ```

2. 安装器会依次：SMB 端口预检 → 带凭据挂载一次（让系统把密码存进钥匙串）→ 卸载 →
   生成巡检脚本 `~/.local/bin/synology-automount.sh` → 免密重挂验证 →
   安装 LaunchAgent `~/Library/LaunchAgents/dev.mahingbun.synology-automount.plist` 并加载。
3. 验证：

   ```sh
   mount | grep MacHardDrive        # 应看到 (smbfs, ...)
   tail -f ~/Library/Logs/synology-automount.log
   diskutil unmount /Volumes/<共享名>   # 60 秒内应自动重挂
   ```

## 参数说明

安装器四个参数依次是 NAS 主机/IP、共享文件夹名（DSM 控制面板"共享文件夹"里那个名字，不是 `/volume2/...` 路径）、
SMB 账号、密码。密码不能含双引号或反斜杠（v1 限制）。要挂同一个共享下的子目录，共享名可写成 `共享名/子目录`。

## 故障排查

| 症状 | 处理 |
| --- | --- |
| 安装时"First mount failed" | 账号/密码错误，或 DSM 未开 SMB。先在 Finder `Cmd+K` 连 `smb://主机` 验证 |
| 免密重挂失败 | Finder `Cmd+K` 连接一次并勾选「在我的钥匙串中记住此密码」，重跑 install.sh |
| 挂载在但访问卡死（僵尸挂载） | `diskutil unmount force /Volumes/<共享名>`，巡检会自动重挂 |
| 暂时不想自动重连 | `launchctl unload ~/Library/LaunchAgents/dev.mahingbun.synology-automount.plist`，恢复用 `load` |
| 看日志 | `~/Library/Logs/synology-automount.log` |
| Time Machine 注意 | 挂载卷含 .sparsebundle 时，系统可能提示用作 Time Machine 目标，按需忽略 |

## 卸载

```sh
./uninstall.sh   # 移除 LaunchAgent 与脚本，交互决定是否卸载卷/删钥匙串条目
```
