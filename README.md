# 相机max (PoseCraft)

> AI 智能拍照姿势与角度推荐系统 —— 打开相机，AR 告诉你怎样拍最好看

---

## 项目简介

PoseCraft 是一款 Android 智能拍照助手 APP。当你面对一个拍照场景时，APP 会实时分析环境（场景类型、光线、空间结构、色彩、氛围），然后通过 **AR 骨骼姿势线叠加** 告诉你：站在哪里、摆什么姿势、从什么角度拍。

核心差异化：**市面上唯一做到 "分析场景 → AI 推荐姿势 → AR 实时引导 → 拍后反馈" 全链路闭环的产品。**

---

## 项目结构

```
├── docs/
│   ├── proposal.md          # 产品需求文档（功能全景、MVP 分期、竞品分析）
│   ├── architecture.md      # 技术架构详设（端云分工、API 设计、部署方案）
│   └── pose-taxonomy.md     # 姿势知识库设计（分类体系、数据结构、数据管线）
├── assets/
│   ├── design/              # 设计素材（效果图、UI 参考、AR 原型）
│   ├── bug/                 # 测试报错截图
│   └── reference/           # 参考图、竞品截图、灵感收集
├── notes/                   # 学习笔记（踩坑记录、技术方案）
├── src/
│   ├── flutter_app/         # Flutter 客户端
│   │   ├── lib/
│   │   │   ├── features/    # 功能模块（camera / ar / recommendation / evaluation / profile）
│   │   │   ├── shared/      # 共享数据模型与组件
│   │   │   └── core/        # 基础设施（网络 / 存储 / ML 引擎）
│   │   └── assets/          # TFLite 模型、本地姿势库、图标字体
│   └── backend/             # Python FastAPI 后端
│       ├── app/
│       │   ├── api/v1/      # REST API 路由
│       │   ├── domain/      # 领域服务（推荐引擎/场景分析/用户画像）
│       │   └── infrastructure/  # 数据库 / LLM / 缓存 / 存储
│       └── workers/         # Celery 异步任务
├── AGENTS.md                # AI 开发助手使用说明
└── README.md                # 本文件
```

---

## 技术栈

| 层 | 技术 |
|----|------|
| 客户端 | Flutter 3.16+ · Riverpod · Camera · MediaPipe · TFLite |
| 端侧 ML | MediaPipe Pose/Face · MobileNet · MiDaS · YOLOv8-nano |
| AR | ARCore (Platform Channel) + 2D CustomPainter fallback |
| 后端 | Python 3.12 · FastAPI · Celery |
| 数据库 | PostgreSQL 16 + pgvector · Milvus · Redis · MinIO |
| AI 模型 | 通义千问 Qwen-VL-Max · DeepSeek · 智谱 GLM-4V |

---

## 快速开始

### 前置要求

- Flutter SDK 3.16+
- Android Studio + Android SDK (API 29+)
- Python 3.12
- Docker + Docker Compose

### Flutter 客户端

```bash
cd src/flutter_app
flutter pub get
flutter run
```

### 后端服务

```bash
cd src/backend
cp .env.example .env   # 编辑 .env 填入 API Key
docker compose up -d   # 启动 PostgreSQL / Milvus / Redis / MinIO
pip install -r requirements.txt
uvicorn app.main:app --reload
```

---

## MVP 进度

- [x] **Phase 0 — 产品定义**：需求文档、架构设计、姿势知识库设计、项目骨架
- [ ] **Phase 1 — 姿势推荐内核**：5 场景 100 姿势、基础 AR 叠加、端云混合推理
- [ ] **Phase 2 — 全场景 + 全人群**：100+ 场景、500+ 姿势、多人场景、摄影师模式
- [ ] **Phase 3 — 社区 + 商业化**：姿势广场、POI 数据库、姿势克隆、Pro 订阅

---

## 开发约定

- 所有代码放入 `src/`，文档放入 `docs/`，素材放入 `assets/`
- **隐私优先**：不上传原始图片，云端只接收特征向量
- 端侧优先推理，云端做端侧做不了的事
- 国产手机 ARCore 兼容性问题需有 2D 降级方案
- 详细规则见 [AGENTS.md](./AGENTS.md)
