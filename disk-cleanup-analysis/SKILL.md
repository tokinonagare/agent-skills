---
name: disk-cleanup-analysis
description: 使用 mole、du、lsof、df 等工具分析 macOS 硬盘占用，识别可删除缓存、应用更新残留、僵尸文件、旧版本框架、开发工具缓存和项目构建产物，并在用户确认后安全清理。适用于用户要求分析硬盘空间、找无用文件、优化存储、清理 Mac 磁盘时。
---

# 硬盘清理分析

本 Skill 用于 macOS 用户级硬盘分析与安全清理。核心原则：**先分析、再分级、最后在用户确认后删除**。默认不做 sudo 级破坏性清理，不直接删除系统关键目录。

## 总体原则

1. 全程使用中文回复。
2. 默认只做用户级清理；涉及 `/System`、`/Library/Developer`、`/Library/Updates`、APFS 快照、iOS Simulator Runtime 等系统级目录时，先说明风险和需要 sudo/系统工具，不擅自删除。
   - 例外：APFS 本地快照（Time Machine 本地快照）可用 `diskutil apfs deleteSnapshot` 免 sudo 删除，见 F 节。
3. 删除前必须列出路径、大小、判断依据和预计收益。
4. 删除前后都要 `du -sh` / `df -h` 复核。
5. 对 App 数据优先区分：
   - 可重建缓存：可删。
   - 登录态、数据库、聊天记录、项目源码：谨慎。
   - 应用本体：仅在用户明确表示不用时卸载。
6. 遇到“已删除但仍占用空间”的情况，用 `lsof +L1` 找进程，优先建议重启或结束相关非关键进程。
7. **删了大量数据但 `df` 可用空间不涨**：优先怀疑 Time Machine 本地快照保留了被删数据。此时快照内的旧版本数据仍占容器空间（`diskutil apfs listSnapshots` 输出可能提示 `This snapshot limits the minimum size of APFS Container`）。用 F 节的方法删除快照后，空间往往一次性大幅回升（实测回升量可远超本次删除量，因为快照还保留了更早的历史版本）。

## 初始检查命令

```bash
mole status
mole clean --dry-run
mole purge --dry-run --debug
df -h / /System/Volumes/Data /System/Volumes/Preboot /System/Volumes/VM 2>/dev/null || true
tmutil listlocalsnapshots / 2>/dev/null || true
diskutil apfs listSnapshots /System/Volumes/Data 2>/dev/null || true  # 关键：确认快照占用与 UUID
```

如果 `mole analyze` 在非 TTY 报错，使用 JSON：

```bash
mole analyze -json /System/Volumes/Data
mole analyze -json "$HOME"
mole analyze -json "$HOME/Library"
mole analyze -json "$HOME/Work"
```

补充快速扫描：

```bash
du -h -d 2 "$HOME" 2>/dev/null | sort -hr | head -80
du -h -d 3 "$HOME/Library" 2>/dev/null | sort -hr | head -100
find "$HOME" -xdev -type f -size +100M -print0 2>/dev/null | xargs -0 ls -lhS 2>/dev/null | head -80
```

## 分类判断经验

### A. 低风险高收益，可优先建议清理

这些通常可重建或可重新下载：

```text
~/.cache/mole
~/.npm/_cacache
~/.npm/_npx
~/.cache/uv
~/.yarn/berry/cache
~/Library/Caches/Yarn/v6          # 注意：Yarn v1 的缓存实际在这里（可能高达 5G），而非 ~/.yarn
~/Library/Caches/ms-playwright
~/Library/Caches/ms-playwright-go
~/.agent-browser/browsers/<旧 Chrome for Testing 版本>
~/Library/Caches/<App 更新缓存>
~/Library/Application Support/<App>/Cache、Code Cache、Service Worker CacheStorage
项目中的 node_modules、dist、coverage、.venv
```

推荐优先用：

```bash
mole clean
mole purge
```

**dotslash 缓存权限坑**：`~/Library/Caches/dotslash/bd/<hash>/...app` 内的 Electron/App bundle 文件权限为只读（`dr-xr-xr-x`），直接 `rm -rf` 会报大量 `Permission denied` 且目录删不干净。需先加写权限再删：

```bash
chmod -R u+w "$HOME/Library/Caches/dotslash" 2>/dev/null
rm -rf "$HOME/Library/Caches/dotslash" 2>/dev/null
```

### B. 应用更新后残留/旧版本

查找 App bundle 内多版本 Framework：

```bash
for app in /Applications/*.app "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  find "$app/Contents/Frameworks" -path '*/Versions' -type d 2>/dev/null | while read vdir; do
    cnt=$(find "$vdir" -mindepth 1 -maxdepth 1 ! -name Current 2>/dev/null | wc -l | tr -d ' ')
    if [ "${cnt:-0}" -gt 1 ]; then
      echo "--- $vdir ($cnt versions)"
      du -sh "$vdir"/* 2>/dev/null | sort -hr | head -20
      readlink "$vdir/Current" 2>/dev/null || true
    fi
  done
done
```

经验：Chrome App 可能在：

```text
/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions
```

若 `Current -> 最新版本`，旧版本通常可在退出 Chrome 后删除。

查找 Sparkle / ShipIt / update 残留：

```bash
find "$HOME/Library/Caches" "$HOME/Library/Application Support" "$HOME/Library/Containers" \
  -type d \( -iname '*ShipIt*' -o -iname '*Sparkle*' -o -iname '*PersistentDownloads*' -o -iname '*update*' -o -iname '*UpdatePackages*' -o -iname 'update.noindex' -o -iname 'update_downloading' \) \
  -prune -print 2>/dev/null | while read d; do du -sh "$d" 2>/dev/null; done | sort -hr | head -80
```

查找 dmg/pkg/zip 更新包：

```bash
find "$HOME/Library/Caches" "$HOME/Library/Application Support" "$HOME/Library/Containers" \
  -type f \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.zip' -o -iname '*.app.zip' \) \
  -size +50M -print0 2>/dev/null | xargs -0 ls -lhS 2>/dev/null | head -80
```

本次经验中确认可清理的例子：

```text
~/Library/Containers/com.tencent.meeting/Data/Library/Global/UpdatePackages
~/Library/Caches/ru.keepcoder.Telegram
~/Library/Caches/com.figma.Desktop.ShipIt
```

### C. App 残留 / 孤儿目录

先用 mole：

```bash
mole clean --dry-run | sed -n '/➤ App leftovers/,/➤ Apple Silicon updates/p'
```

检查失效启动项：

```bash
ls -la "$HOME/Library/LaunchAgents" 2>/dev/null
for f in "$HOME"/Library/LaunchAgents/*.plist; do
  [ -e "$f" ] || continue
  echo "--- $f"
  plutil -p "$f" 2>/dev/null | grep -E 'Program|ProgramArguments' -A3 || true
done
```

删除前可先卸载 launch agent：

```bash
launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/xxx.plist" 2>/dev/null || true
```

常见可疑孤儿目录示例：

```text
~/.appium
~/.biome
~/.bytertc
~/.cc-switch
~/.chelper
~/.gemini.bak
~/.claude-sneakpeek
~/.claudemind
~/.frp
~/.hawtjni
~/.javacpp
~/.ngrok
```

**确认孤儿的标准**（mole clean 输出的 `Potential orphan dotfile` 也要逐项验证后再删）：

```bash
# 1. 是否有进程在引用
lsof 2>/dev/null | grep -iE "frp|ngrok|javacpp|hawtjni|claudemind" | head
# 2. PATH 中是否有对应二进制
for bin in frp frpc frps ngrok javacpp; do which $bin 2>/dev/null || echo "$bin: PATH 中不存在"; done
# 3. 是否注册为 launchd 服务
ls "$HOME/Library/LaunchAgents" 2>/dev/null | grep -iE "frp|ngrok" || echo "无相关 LaunchAgent"
```

三项均无 + 修改时间久远（>2 个月）即可判定孤儿，用户确认后删除。本次实测确认并清理的孤儿：`~/.frp` 43M（frp 0.61.1 下载包+解压目录，PATH 无 frp）、`~/.javacpp` 27M、`~/.ngrok` 8.5M、`~/.claudemind` 24K、`~/.hawtjni` 0B。

只有在用户确认不用对应工具后删除。

### D. 通讯/办公软件缓存

Telegram：

```text
~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/.../postbox/media
~/Library/Caches/ru.keepcoder.Telegram
```

可删媒体缓存、通话缓存、日志；**保留 `postbox/db`**，避免破坏聊天索引和登录状态。

微信：

```text
~/Library/Containers/com.tencent.xinWeChat/Data/Documents/app_data/xplugin/plugins
```

同一插件多个版本时，通常可删旧版本。例如保留新 `Magicdy/175`，删除旧 `Magicdy/143`。

Lark/飞书：

```text
~/Library/Application Support/LarkShell
```

优先提示用户在应用内清缓存。手动清理时区分日志/缓存和用户数据，不轻易删除整个 LarkShell。

本次实测经验：`LarkShell` 可能主要由以下项占用：

```text
LarkShell/aha/.../profile_explorer/Service Worker/CacheStorage
LarkShell/iron/.../profile_main/Service Worker/CacheStorage
LarkShell/sdk_storage/log
LarkShell/CodeCache
~/Library/Caches/LarkShell
```

这些是相对低风险的缓存/日志。保守清理流程：先退出 Lark/飞书，再删除上述 CacheStorage、log、CodeCache 和 `~/Library/Caches/LarkShell`，最后重建基础目录。不要删除整个 `LarkShell`，也不要默认删除 `sdk_storage/.../resources/seed`，该目录可能是离线资源包，删后可能重新下载或影响体验。

可用模板：

```bash
LARK="$HOME/Library/Application Support/LarkShell"
TARGETS=(
"$LARK/sdk_storage/log"
"$LARK/CodeCache"
"$HOME/Library/Caches/LarkShell"
)
while IFS= read -r d; do TARGETS+=("$d"); done < <(find "$LARK/aha" "$LARK/iron" -type d -path '*/Service Worker/CacheStorage' 2>/dev/null || true)

osascript -e 'tell application "Lark" to quit' 2>/dev/null || true
osascript -e 'tell application "Feishu" to quit' 2>/dev/null || true
sleep 5
pkill -f '/Applications/Lark.app' 2>/dev/null || true

for t in "${TARGETS[@]}"; do [ -e "$t" ] && rm -rf "$t"; done
mkdir -p "$LARK/sdk_storage/log" "$LARK/CodeCache" "$HOME/Library/Caches/LarkShell"
```

实测清理效果示例：`LarkShell` 从约 `3.2G` 降到 `695M`，释放约 `2.5G`。

Figma：

```text
~/Library/Application Support/Figma/DesktopProfile
~/Library/Caches/com.figma.Desktop.ShipIt
```

ShipIt 更新缓存可删；DesktopProfile 会影响本地缓存/登录体验，需确认。

### E. 开发工具缓存和旧版本

检查：

```bash
for d in "$HOME/.nvm" "$HOME/.yarn" "$HOME/.claude" "$HOME/.codex" "$HOME/.local" "$HOME/.hermes" "$HOME/.pi" "$HOME/.agent-browser" "$HOME/.gradle" "$HOME/.m2" "$HOME/.rbenv" "$HOME/.npm" "$HOME/.kimi" "$HOME/.codegraph" "$HOME/.lldb"; do
  [ -e "$d" ] && du -sh "$d"
done
```

NVM 旧版本：

```bash
du -sh "$HOME/.nvm/versions/node"/* 2>/dev/null | sort -hr
```

只在用户确认项目不依赖后删除旧 Node 版本。建议至少保留当前常用版本。

AI 工具历史：

```text
~/.claude/projects
~/.claude/file-history
~/.codex/sessions
~/.kimi/sessions
```

这些可以释放空间，但会丢历史上下文，必须先确认。

**活跃进程会阻止删除**：实测删除 `~/.claude/projects` 时报 `Directory not empty`，因为仍有多个 Claude Code 会话进程（`ps aux | grep -i claude`，形如 `claude --session-id`）在持续写入新会话。此时不要强杀进程，剩余部分是活跃会话数据，保留即可；待所有会话结束后再补删。可用 `lsof +D <目录>` 确认是否有进程持有。

### F. 僵尸文件 / 已删除仍占用 / Time Machine 快照占用

**已删除仍被进程占用**：

```bash
lsof +L1 2>/dev/null | awk 'NR==1 || $7>52428800 {print}' | head -80
```

若有大文件 `NLINK 0`，说明文件已删除但进程仍占用空间。处理策略：

1. 判断进程是否可安全结束。
2. 能退出 App 就优雅退出。
3. 必要时 `kill <pid>`。
4. 系统进程优先建议重启。

实例：`~/.local/share/claude/versions/<旧版本>` 被正在运行的 Claude Code 进程（`claude --session-id`）占用，文件已删但空间不释放，重启 Claude 后自动释放。注意可能同时有多个 Claude 会话进程，不要误杀正在使用的会话。

**Time Machine 本地快照（系统级大头，但可免 sudo 清理）**：

症状：删了十几 G 数据但 `df` 可用空间不变；`diskutil apfs listSnapshots /System/Volumes/Data` 显示大量 `com.apple.TimeMachine.*.local` 快照，且第一个可能标注 `This snapshot limits the minimum size of APFS Container`。

```bash
# 列出快照 UUID
# 输出格式："+-- <UUID>" 紧邻 "|   Name: <快照名>"
diskutil apfs listSnapshots /System/Volumes/Data 2>/dev/null | grep -E '^\+--' | awk '{print $2}'

# 逐个删除（免 sudo！实测 tmutil 在 macOS 26 会报 Invalid argument / is not a valid disk，
# thinlocalsnapshots 也不生效，而 diskutil 直接可用）
diskutil apfs listSnapshots /System/Volumes/Data 2>/dev/null | grep -E '^\+--' | awk '{print $2}' | while read uuid; do
  diskutil apfs deleteSnapshot /System/Volumes/Data -uuid "$uuid" 2>&1 | grep -E "Finished|Error" | head -1
done

# 验证：数量应归零，df 可用空间大幅回升
```

注意：`tmutil deletelocalsnapshots <名称>` 报 `Invalid argument`、`sudo tmutil thinlocalsnapshots` 需密码时，优先用上述 diskutil 方案（无需 sudo）。删除后空间释放可能有延迟，稍等或 `sync` 后再 `df`。

### G. 系统级大头，默认只报告

这些通常很大，但不要在无 sudo/无明确确认下删除：

```text
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime
/System/Volumes/Data/macOS Install Data
/Library/Developer/CoreSimulator
/System/Volumes/Preboot
/System/Volumes/VM
```

报告时说明：

- iOS Simulator Runtime 可通过 Xcode/simctl 或 sudo 清理。
- macOS Install Data 需确认没有更新进行中，最好重启后再处理。
- VM/sleep/swap 常可通过重启释放。
- Time Machine 本地快照：已不在本清单，改用 F 节的 `diskutil apfs deleteSnapshot` 免 sudo 方案。

补充实测：`~/Library/Developer/Xcode/iOS DeviceSupport/<设备>` 可能异常大（如 5.7G），但若对应设备仍在用则不建议删（删除后需重连设备重新生成）。CoreSimulator 大设备（`~/Library/Developer/CoreSimulator/Devices/<UUID>/data` 达 2.3G）在模拟器未运行时可用 `xcrun simctl delete <UUID>` 删除，但会丢失该设备上的已安装 App 数据，需确认。

## 删除模板

**推荐分批执行**（先易后难，每批向用户确认）：

1. 第一批：可重建缓存（Yarn/npm/CocoaPods/Playwright/Puppeteer/Homebrew 等，低风险高收益）。
2. 第二批：项目构建产物（`mole purge`，node_modules/dist/target）。
3. 第三批：应用缓存（`mole clean`，含 Chrome Service Worker、Xcode 失效模拟器等）。
4. 第四批：需单独确认项（AI 历史会话、Figma DesktopProfile、TM 快照等，涉及数据或登录态）。

删除前后使用这种模板，避免误删：

```bash
set -e
TARGETS=(
"$HOME/path/to/cache1"
"$HOME/path/to/cache2"
)

printf '清理前磁盘空间：\n'
df -h /System/Volumes/Data /
printf '\n清理前目标大小：\n'
for t in "${TARGETS[@]}"; do [ -e "$t" ] && du -sh "$t" || echo "不存在: $t"; done

printf '\n开始删除...\n'
for t in "${TARGETS[@]}"; do
  if [ -e "$t" ]; then
    echo "删除: $t"
    rm -rf "$t"
  fi
done

sync
sleep 2
printf '\n清理后目标大小：\n'
for t in "${TARGETS[@]}"; do [ -e "$t" ] && du -sh "$t" || echo "不存在: $t"; done
printf '\n清理后磁盘空间：\n'
df -h /System/Volumes/Data /
```

对于缓存目录，删除后可重建空目录，降低应用报错概率：

```bash
mkdir -p "$HOME/Library/Caches/some-app"
```

## 结果汇报格式

最终汇报包含：

1. 已清理路径和释放空间。
2. 当前 `df -h` 可用空间。
3. 目录级变化，例如 `~/.yarn 3.7G -> 166M`。
4. 仍未处理的大头及原因（需要 sudo、需要用户确认、可能影响数据）。
5. 如果 `df` 没有立刻上涨，说明可能是 APFS 快照、purgeable 空间或进程占用，继续用 `lsof +L1` 和重启建议排查。
