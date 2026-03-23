# HaloWebUI LazyCat 应用

将 HaloWebUI 转换为 LazyCat 云平台应用。

## 应用信息

| 项目 | 值 |
|------|-----|
| 名称 | HaloWebUI |
| 版本 | 1.0.0 |
| 包名 | cloud.lazycat.app.halowebui |
| 原始镜像 | ghcr.io/ztx888/halowebui:main |

## 快速开始

### 1. 准备图标

需要准备一个 **512x512 PNG** 格式的应用图标，保存为 `icon.png`。

### 2. 本地测试

```bash
# 添加执行权限
chmod +x build.sh

# 运行脚本
./build.sh

# 选择 1 - 构建应用
# 选择 5 - 查看应用信息

# 安装到本地 LazyCat
lzc-cli app install halowebui-1.0.0.lpk
```

### 3. 发布到应用商店

```bash
# 首次登录
lzc-cli appstore login

# 运行脚本
./build.sh

# 选择 4 - 一键发布
```

## 文件结构

```
halowebui-lzcapp/
├── lzc-manifest.yml    # 应用配置
├── lzc-build.yml       # 构建配置
├── build.sh            # 发布脚本
├── README.md           # 本文档
└── icon.png            # 应用图标 (需要您提供)
```

## 配置说明

### 存储映射

| 容器路径 | LazyCat 路径 | 说明 |
|----------|--------------|------|
| /app/backend/data | /lzcapp/var/open-webui | 应用数据 |

### 特殊配置

应用使用 `compose_override` 配置了 `host.docker.internal` 主机映射，允许容器访问宿主机服务。

### 端口

- HTTP: 8080 (通过 `upstreams` 配置)

## 发布流程

```
阶段 1: 初始构建（原始镜像）
   ↓
阶段 2: 复制镜像到懒猫仓库
   ↓
阶段 3: 重新构建（新镜像）
   ↓
阶段 4: 发布到应用商店
```

## 相关文档

- [LazyCat 开发者文档](https://developer.lazycat.cloud)
- [应用发布指南](https://developer.lazycat.cloud/docs/publish-app.html)# halowebui-lzcapp
