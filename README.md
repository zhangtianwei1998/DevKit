# DevKit

三个 macOS 小工具合到一个应用里：改 hosts、截图钉图、鼠标滚动调节。

用命令行工具链构建，不需要 Xcode。灵感来自 SwitchHosts、Shottr 和 Mos，
但只做自己常用的那部分，代码尽量少。

## 快速开始

```bash
git clone https://github.com/zhangtianwei1998/DevKit.git
cd DevKit
./build.sh run
```

首次跑起来后建议看一下下面的「签名」一节，否则每次重新构建都要重新授权。

## 功能

**Hosts** — 多套 hosts 方案，开关切换，写入 `/etc/hosts` 时弹一次系统授权。
首次启动会自动导入 SwitchHosts 的方案（读 `~/.SwitchHosts`）。
用标记块管理，块外手写的内容不会被动，反复开关也不会越写越长。

**截图** — 调系统 `screencapture` 选区，截完的图钉在屏幕最上层。
默认快捷键 ⌘⇧2，可以改。图上鼠标移过去左上角出现关闭按钮，拖动移动，滚轮缩放，双击或 Esc 关闭，⌘C 复制。

**滚动** — 反转滚轮方向 + 平滑滚动。可调滚动距离和滑动持续感。
默认只作用于鼠标滚轮，不改触控板手感（触控板本身就是连续滚动，再插值只会更糊）。

## 构建

```bash
./build.sh        # 出包到 dist/DevKit.app
./build.sh run    # 出包并启动
./test.sh         # 跑自检
./Icon/make.sh    # 单独重新生成图标
```

图标是用 AppKit 手工画的（`Icon/icon.swift`），`build.sh` 会自动生成并缓存，
改了绘图代码才会重算。

需要 macOS 13+ 和 Command Line Tools（`xcode-select --install`）。

## 签名（重要）

macOS 的权限授权绑定代码签名指纹。用 ad-hoc 签名的话，**每次改代码重新构建，之前授权的屏幕录制和辅助功能权限都会失效**，得反复重新勾选。

解决办法是建一张自签名证书，让应用有固定身份：

```bash
# 1. 生成证书
cat > /tmp/devkit-cert.cnf <<'EOF'
[req]
distinguished_name=dn
x509_extensions=v3
prompt=no
[dn]
CN=DevKit Local Dev
[v3]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
cd /tmp && openssl req -x509 -newkey rsa:2048 -keyout devkit-key.pem \
  -out devkit-cert.pem -days 3650 -nodes -config devkit-cert.cnf

# 2. 装进登录钥匙串
openssl pkcs12 -export -inkey devkit-key.pem -in devkit-cert.pem \
  -out devkit.p12 -passout pass:devkit -name "DevKit Local Dev" -legacy
security import devkit.p12 -k ~/Library/Keychains/login.keychain-db \
  -P devkit -T /usr/bin/codesign -A

# 3. 设为受信任（用户级，不需要管理员密码）
security add-trusted-cert -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db devkit-cert.pem

# 4. 确认
security find-identity -v -p codesigning | grep "DevKit Local Dev"
```

`build.sh` 会自动找这张证书。找不到就退回 ad-hoc 并打印警告。

不想装证书也能跑，只是每次重新构建都要重新授权一次。

## 权限

- **Hosts** 写 `/etc/hosts` 时弹密码框。想免密要装特权 helper，目前没做。
- **截图** 需要「屏幕录制与系统录音」。
- **滚动** 需要「辅助功能」。面板里有按钮直接跳转到系统设置，授权后会自动感知。

授权对象是 **DevKit**，不是你的终端。

## 已知限制

- 滚动只处理纵向，横向不管。
- 滚动没有按应用白名单，是全局生效的。
- 别同时开着 SwitchHosts，两个应用会互相覆盖 hosts。
- 界面布局没有自动化测试，靠截图人眼确认（SwiftUI 的 `NavigationSplitView` 是异步布局，离屏渲染复现不出问题）。

## 结构

```
Sources/
  App.swift          入口 + 菜单栏
  RootView.swift     左侧三模块导航
  HostsFile.swift    /etc/hosts 拼接与剥离（纯函数）
  HostsStore.swift   方案存取、导入、授权写盘
  HostsView.swift    方案列表 + 编辑器
  Snip.swift         截图与钉图列表
  PinWindow.swift    无边框浮动图片窗口
  PinGeometry.swift  尺寸位置计算（纯函数）
  SnipView.swift     截图面板
  HotKeySpec.swift   快捷键数据与显示
  HotKey.swift       全局热键注册（Carbon，不需要授权）
  HotKeyField.swift  快捷键录制控件
  ScrollCore.swift   滚动过滤与平滑积分（纯函数）
  ScrollTap.swift    事件拦截与分帧重发
  ScrollView2.swift  滚动面板
  Settings.swift     配置持久化
Icon/
  icon.swift         图标绘制，输出 1024 PNG
  make.sh            生成 icns（10 档尺寸）
Tests/
  main.swift         纯逻辑断言
  ui/main.swift      需要 AppKit 的检查
```

配置存在 `~/Library/Application Support/DevKit/`。

## 许可

MIT，随便用。
