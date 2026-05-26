# AGENTS.md — 开发 AI 使用说明

> 本文档面向后续接手开发的 AI 助手。**开始任何开发任务前必须先阅读本文件。**

---

## 项目概述

**PoseCraft（相机max）**：基于 AI 视觉分析的智能拍照助手 Android APP。

- 核心功能：根据用户所处环境，通过 AR 实时叠加给出最佳拍照姿势、站位和角度建议
- 端侧推理 + 云端大模型混合架构
- Flutter 跨平台（优先 Android）+ Python FastAPI 后端

---

## 关键文档索引（必读）

| 文档 | 路径 | 何时读 |
|------|------|--------|
| 产品需求文档 | `docs/proposal.md` | 理解产品做什么、用户是谁、MVP 分期 |
| 技术架构设计 | `docs/architecture.md` | 理解端云分工、API 设计、数据模型、部署 |
| 姿势知识库设计 | `docs/pose-taxonomy.md` | 理解姿势分类体系、数据结构、数据管线 |
| Plan 文件 | `.claude/plans/proposal-md-humble-lemur.md` | 理解决策过程和待确认项 |

---

## 项目文件夹结构及用途

| 路径 | 用途 | 规则 |
|------|------|------|
| `docs/` | 产品文档：PRD、架构、姿势知识库、决策记录 | 所有 `.md` 文档统一放这里 |
| `assets/design/` | 设计素材：效果图、UI 参考、AR 交互原型 | 仅设计相关 |
| `assets/bug/` | 测试报错截图、Bug 复现 | 按日期或 Bug ID 命名 |
| `assets/reference/` | 参考图、竞品截图、灵感收集 | 非直接产出素材 |
| `notes/` | 学习笔记：踩坑记录、技术方案、环境备忘 | 逐条标日期 |
| `src/flutter_app/` | Flutter 客户端代码 | 所有 Flutter 代码 |
| `src/backend/` | Python 后端代码 | 所有 Python 代码 |

---

## 开发规则

### 代码区 (`src/`)

1. 所有代码文件必须放在 `src/` 或其子目录下，禁止在根目录创建代码。
2. **代码区内不引用外部文件夹**（`assets/`、`notes/` 等）的图片或资源作为运行时依赖。
3. Flutter 代码在 `src/flutter_app/`，Python 代码在 `src/backend/`，两者互不污染。
4. 新增 Flutter 功能模块遵循 `features/<module>/{presentation, domain, data}/` 三层结构。
5. 新增后端功能遵循 `app/{api, domain, infrastructure}/` 分层。

### 文档区 (`docs/`)

6. 所有文档放入 `docs/`，不要在根目录创建 `.md` 文件。
7. 重要决策文档标注日期和版本号。
8. 需求变更必须在 `proposal.md` 或独立的 changelog 中记录。

### 通用规则

9. **根目录仅保留**：`AGENTS.md`、`README.md`、`.gitignore`。其余文件按分类归入对应文件夹。
10. 不要在根目录创建临时文件或测试文件。
11. 保持文件夹层次不超过 4 层。

---

## 技术栈

| 层 | 技术 | 备注 |
|----|------|------|
| 客户端 | Flutter 3.16+ / Dart 3.2+ | Riverpod 状态管理，Material 3 |
| 端侧 ML | TFLite (GPU Delegate) + MediaPipe | 场景分类 / 骨骼检测 / 深度估计 / 光线分析 |
| AR | ARCore (Platform Channel) | 有 2D fallback 方案 |
| 后端框架 | Python 3.12 / FastAPI | 异步 |
| 数据库 | PostgreSQL 16 + pgvector | 用户/姿势/POI 数据 |
| 向量检索 | Milvus | 姿势语义检索 |
| 缓存 | Redis | 推荐缓存、会话状态 |
| 对象存储 | MinIO (自建) | 参考图、模型文件 |
| LLM | 通义千问 Qwen-VL-Max / DeepSeek / GLM-4V | 国产大模型，多模型主备 |

---

## 开发原则

### 隐私优先

- 人脸识别、人体检测、场景分类**全部端侧完成**，**不上传原始图片**
- 云端只接收特征向量（embedding）、骨骼坐标（匿名化）、光线参数
- 用户照片仅存储在本地设备，云端不持久化

### 离线可用

- 在线：端侧分析 + 云端 LLM 推理 + 在线姿势库
- 弱网：端侧分析 + 规则引擎 + 本地姿势库 (Top 100)
- 离线：纯本地推理 + 本地姿势库 + 规则匹配

### 关键架构决策

- AR 方案：ARCore Platform Channel（国产手机兼容性需考虑 2D fallback）
- 状态管理：Riverpod（适合相机流 → 分析 → 推荐 → AR 的 Provider 嵌套链）
- 网络协议：HTTPS (推荐请求) + WebSocket (实时反馈，V2)
- LLM 策略：多模型主备双路 + 降级（国产模型稳定性考量）

---

## 给 AI 助手的提示

- 开始任务前阅读 `docs/proposal.md` 确认当前处于哪个 MVP 阶段。
- 新增文件时，确认它属于 `docs/`、`assets/`、`notes/` 还是 `src/`。
- 修改 `src/flutter_app/` 时参考 `docs/architecture.md` 第三节的模块结构。
- 修改 `src/backend/` 时参考 `docs/architecture.md` 第四节的 API 设计。
- 涉及姿势数据时参考 `docs/pose-taxonomy.md` 的 Schema 定义。
- **不要硬编码** `assets/` 或 `notes/` 中的文件路径到代码逻辑中。
