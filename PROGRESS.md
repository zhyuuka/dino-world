# 项目进度（跨会话同步）

> 这个文件用于多会话之间的上下文传递。每个会话开始时主 Agent 必须读取本文件来恢复进度。
> 每个会话结束前必须更新本文件。

## 项目基本信息
- **项目名**：dino-world（3D 开放世界恐龙生存游戏）
- **仓库**：https://github.com/zhyuuka/dino-world （Private）
- **目标平台**：Android（最终交付 APK）
- **引擎**：Godot 4.4.1 stable + GDScript
- **当前阶段**：第 1 阶段（小型 3D 场景 + 1 只玩家恐龙 + 几只 AI 恐龙，单机）

## 第 1 阶段目标
- [x] Godot 4.4.1 引擎在沙箱跑通（/workspace/tools/godot）
- [x] Android SDK 安装配置完成（/workspace/tools/android-sdk，build-tools 34.0.0 + platform-34）
- [x] Godot Android 导出模板安装（/root/.local/share/godot/export_templates/4.4.1.stable/）
- [x] 项目骨架（project.godot + 目录结构 + .gitignore + export_presets.cfg）
- [x] GitHub 私有仓库 dino-world 创建
- [x] 首次推送到 GitHub（本次会话完成）
- [x] APK 导出跑通（生成 47MB debug APK）
- [ ] 玩家恐龙场景（CharacterBody3D + 摄像机 + 操控）
- [ ] 小型地形场景（StaticBody3D 地面 + 装饰物）
- [ ] AI 恐龙（简单状态机：游荡/追击/逃跑）
- [ ] HUD（血量、提示）
- [ ] 触屏操控（虚拟摇杆 + 按钮）
- [ ] 第 1 阶段最终 APK 交付

## 当前会话状态（最新更新：2026-07-21）

### 关键突破：APK 导出失败问题已解决
**根因**：Godot 4.4 源码 `platform/android/export/export_plugin.cpp` 第 2784-2786 行：
```cpp
if (!ResourceImporterTextureSettings::should_import_etc2_astc()) {
    valid = false;  // 注意：这里设置 valid=false 但不填充 err！
}
```
`should_import_etc2_astc()` 检查项目设置 `rendering/textures/vram_compression/import_etc2_astc`，
未启用时返回 false（Linux x86_64 不是 ETC2_ASTC 首选格式），导致 `has_valid_project_configuration`
返回 false 但错误信息为空 → 用户看到 "configuration errors:" 后面空白。

**修复**：在 project.godot 的 [rendering] 节加入：
```
textures/vram_compression/import_etc2_astc=true
```

### 已完成
- 项目规则写入 `.trae/rules/project_rules.md`（10 节，含质量优先原则）
- 需求澄清：开放恐龙世界、3D、Android、单人+多人（多人第4阶段）、卡通风、大型开放世界（已劝说分阶段）
- 技术栈决定：Godot 4.4.1 + GDScript
- Godot 4.4.1 Linux x86_64 下载（通过 gh-proxy.com 镜像从 10KB/s 提速到 25-28MB/s）
- Android SDK 安装（platform-tools 37.0.0 + build-tools 34.0.0 + platform android-34）
- Godot Android export templates 4.4.1 安装（android_debug.apk + android_release.apk）
- debug.keystore 生成
- project.godot 配置完成（含输入映射、物理层、mobile 渲染器、ETC2/ASTC 纹理压缩）
- export_presets.cfg 配置完成（Android Debug 预设，arm64-v8a）
- Main.tscn 场景占位（Node3D + DirectionalLight3D + CSGBox3D 地面 + Camera3D）
- Main.gd 占位脚本
- editor_settings-4.4.tres 配置（Java 17 + Android SDK 路径 + keystore）
- GitHub PAT 认证成功（gh CLI 登录 zhyuuka）
- 私有仓库 https://github.com/zhyuuka/dino-world 已创建
- **APK 导出成功**：build/dino-world-debug.apk（47MB，arm64-v8a，已签名）

### 进行中
- 首次 git 提交并推送到 GitHub
- 委托子 Agent 实现第 1 阶段游戏代码

### 待办
- 委托子 Agent 实现第 1 阶段代码（场景 + 玩家恐龙 + AI 恐龙 + 触屏操控 + HUD）
- 子 Agent 完成后重新打包 APK 并交付用户

## 关键技术决定（备忘）
1. **不用 Unity**：Unity Editor 必须图形界面，沙箱跑不了。Godot 4.x 可命令行导出 APK。
2. **第 1 阶段单机**：不做联机，专注核心玩法跑通。
3. **几何体占位美术**：第 1 阶段用 Box/Capsule 代表恐龙，先做玩法。
4. **私有仓库**：用户要求 Private。
5. **GitHub PAT 认证**：沙箱非交互环境，不能用 `gh auth login` 交互式，用 PAT。
6. **Java 17**：与 Android build-tools 34 兼容性更好（虽然 Java 25 也能用，但 17 更稳）。
7. **ETC2/ASTC 纹理压缩**：Android 导出强制要求，必须在 project.godot 启用。
8. **mobile 渲染器**：3D Forward+ 的移动版，适合 Android 设备。
9. **arm64-v8a only**：现代 Android 手机都是 64 位 ARM，减小 APK 体积。
10. **重度任务委托子 Agent**：主会话 200k 上下文宝贵，写代码/调报错一律委托。

## 关键环境变量（导出 APK 时必须设置）
```bash
export JAVA_HOME=/root/.local/share/mise/installs/java/17.0.2
export ANDROID_HOME=/workspace/tools/android-sdk
export ANDROID_SDK_ROOT=/workspace/tools/android-sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:$PATH
```

## 打包 APK 命令
```bash
cd /workspace
./tools/godot --headless --export-debug "Android Debug"
# 产物：build/dino-world-debug.apk
```

## 风险与未决事项
- 沙箱磁盘空间需监控（Android SDK 458MB + Godot templates 1.2GB + Godot binary 123MB）
- 多人联机是第 4 阶段，可能因 Godot 联机能力限制而需要迁移引擎（届时再评估）
- 用户是小白，所有打包/测试由 AI 完成，用户只看 APK 结果
- **用户 GitHub PAT 已暴露在聊天记录，建议用户尽快到 GitHub Settings 撤销重置**

## 跨会话恢复指令（给未来的主 Agent）
1. 先读 `.trae/rules/project_rules.md` 了解所有规则
2. 再读本文件了解进度
3. 检查 Godot 是否已安装：`/workspace/tools/godot --version`
4. 检查 GitHub 认证状态：`gh auth status`
5. 检查 git 远程：`cd /workspace && git remote -v && git log --oneline -5`
6. 拉取最新：`cd /workspace && git pull`
7. 根据上面"第 1 阶段目标"清单继续推进下一个未完成项
8. 重度实现任务用 Task 工具委托给 general_purpose_task 子 Agent
9. 打包 APK 前必须设置上面的环境变量
