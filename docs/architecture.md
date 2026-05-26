# 技术架构设计 (Architecture Design)

> 版本: v1.3 | 日期: 2026-05-26 | 状态: Phase 2 核心功能完成（TTS/光线/表情/拍后评估已集成）

---

## 一、架构概览

### 1.1 关联文档

| 文档 | 说明 |
|------|------|
| `docs/proposal.md` | 产品需求文档 |
| `docs/pose-taxonomy.md` | 姿势知识库设计 |
| `docs/camera-params.md` | 相机参数知识库设计 |
| `docs/styling-guide.md` | 服装道具搭配知识库设计 |
| `docs/preset-engine.md` | 后期预设引擎设计 |

### 1.2 设计原则

1. **端侧优先**: 尽可能多的推理在设备上完成，只把端侧做不了的事情交给云端
2. **隐私设计**: 不上传原始图片到云端，只传输匿名化的特征数据
3. **优雅降级**: 网络不可用时，本地推理 + 本地姿势库仍可提供基础服务
4. **流式体验**: 端侧推理每帧运行，云端推理异步补充，用户无感知
5. **模块化**: Flutter 端按功能模块拆分，后端按领域拆分微服务

### 1.2 系统分层

```
┌─────────────────────────────────────────────────────────────────┐
│                     Presentation Layer                           │
│  ┌───────────┐ ┌────────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ 相机页面   │ │ AR 叠加层   │ │ 姿势浏览  │ │ 设置/个人中心  │  │
│  │ Camera    │ │ AR Overlay │ │ Pose Feed│ │ Profile       │  │
│  └─────┬─────┘ └──────┬─────┘ └────┬─────┘ └───────┬────────┘  │
│        │              │            │               │            │
├────────┼──────────────┼────────────┼───────────────┼────────────┤
│        │     Application Layer      │               │            │
│  ┌─────┴──────────────┴────────────┴───────────────┴──────────┐ │
│  │                    State Management (Riverpod)              │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │ │
│  │  │相机状态   │ │推荐状态   │ │AR 状态    │ │用户状态       │  │ │
│  │  │Camera    │ │Reco      │ │AR State  │ │User State    │  │ │
│  │  │State     │ │State     │ │          │ │              │  │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │ │
│  └──────────────────────────┬─────────────────────────────────┘ │
│                             │                                    │
├─────────────────────────────┼────────────────────────────────────┤
│                             │  Domain Layer                      │
│  ┌──────────────────────────┴─────────────────────────────────┐ │
│  │  ┌────────────┐ ┌──────────────┐ ┌──────────────────────┐  │ │
│  │  │场景分析     │ │推荐引擎       │ │AR 渲染               │  │ │
│  │  │Scene       │ │Recommendation│ │AR Renderer          │  │ │
│  │  │Analyzer    │ │Engine        │ │                     │  │ │
│  │  └─────┬──────┘ └──────┬───────┘ └──────────┬───────────┘  │ │
│  └────────┼───────────────┼───────────────────┼───────────────┘ │
│           │               │                   │                  │
├───────────┼───────────────┼───────────────────┼──────────────────┤
│           │   Data Layer  │                   │                  │
│  ┌────────┴───────────────┴───────────────────┴────────────────┐ │
│  │  ┌──────────────────┐  ┌────────────┐  ┌────────────────┐  │ │
│  │  │ 本地推理引擎      │  │ 本地存储    │  │ 网络层          │  │ │
│  │  │ TFLite/MediaPipe │  │ Drift(SQL) │  │ Dio + gRPC     │  │ │
│  │  │ + 离线规则引擎    │  │ + SharedPref│  │ + WebSocket    │  │ │
│  │  └──────────────────┘  └────────────┘  └────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS / gRPC / WebSocket
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Cloud Backend                                │
│                                                                    │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │ API Gateway   │    │ 推理编排服务       │    │ 数据平台       │  │
│  │ - 认证鉴权    │    │ - 场景深度分析     │    │ - 姿势管理     │  │
│  │ - 限流熔断    │    │ - 姿势推荐排序     │    │ - 用户数据     │  │
│  │ - 日志追踪    │    │ - 美学评分         │    │ - POI 数据     │  │
│  │              │    │ - 多模型编排       │    │ - 内容审核     │  │
│  └──────────────┘    └──────────────────┘    └───────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                     Infrastructure                            │ │
│  │  PostgreSQL │ Milvus │ Redis │ MinIO │ Prometheus │ Grafana  │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## 二、端云分工边界

### 2.1 职责划分

| 层级 | 职责 | 为什么在这里做 |
|------|------|---------------|
| **端侧** | 相机控制、实时人体检测、场景粗分类、深度估计、光线分析、AR 渲染、表情检测、离线姿势推荐 | 低延迟、隐私保护、离线可用 |
| **云端** | 细粒度场景理解、姿势语义匹配与排序、多模态 LLM 推理、美学评分、个性化画像更新、内容审核 | 模型体积大、计算量大、需要访问在线数据 |
| **共享** | 姿势库（云端全量 ↔ 端侧缓存 Top 100）、用户画像（云端主存 ↔ 端侧缓存） | 离线 + 在线协同 |

### 2.2 数据传输协议

```
端侧 → 云端 (一次推荐请求):
{
  "request_id": "uuid",
  "user_id": "user_123",
  "session_id": "session_456",
  "timestamp": 1716638400,
  "device_info": {
    "model": "Xiaomi 14",
    "android_version": "14",
    "arcore_supported": true
  },
  "scene_features": {
    "scene_class": "beach",
    "scene_confidence": 0.92,
    "lighting": {
      "direction": [0.3, 0.7, 0.0],   // 光源方向向量
      "intensity": 0.75,                // 归一化强度
      "color_temp": 5200,               // 色温 K
      "contrast_ratio": 0.4
    },
    "spatial": {
      "dominant_planes": [              // 主要平面（可站位置）
        {"type": "ground", "center": [0, 0, 0], "normal": [0, 1, 0]},
        {"type": "wall", "center": [2.0, 1.5, 0], "normal": [0, 0, 1]}
      ],
      "depth_range": [0.5, 15.0]        // 深度范围(米)
    },
    "color_palette": ["#87CEEB", "#F4A460", "#FFFFFF"],  // 主色调
    "time_of_day": "golden-hour",
    "weather": "sunny",
    "gps": [18.302, 109.175],           // 可选，用于 POI 感知
    "crowd_density": 0.2                // 人流密度 0-1
  },
  "user_context": {
    "mode": "selfie",                   // selfie | photographer
    "person_count": 1,
    "camera_facing": "back",            // front | back
    "selected_style": "fresh",          // 用户偏好的风格（可选）
    "previous_skipped_poses": ["pose_001", "pose_002"]  // 本会话已跳过的姿势
  }
}

云端 → 端侧 (推荐响应):
{
  "request_id": "uuid",
  "recommendations": [
    {
      "pose_id": "beach-crossleg-001",
      "rank": 1,
      "score": 0.94,
      "skeleton_3d": { ... },           // 完整骨骼数据
      "guidance_text": "重心放后腿，前腿微弯，回眸看镜头",
      "voice_guidance": [...],           // 语音引导文本序列
      "standing_position": {             // 推荐站位（相对当前深度图坐标）
        "x": 0.5, "y": 0.0, "z": 1.5
      },
      "photographer_angle": {
        "pitch": 0.2,                    // 仰角（弧度）
        "yaw": 0.0,
        "height": "waist"               // 拍摄高度
      },
      "composition_hints": {             // 构图提示线
        "rule_of_thirds_grid": true,
        "alignment": "center"
      },
      "lighting_tip": "面向光源方向，让脸获得均匀光",
      "reference_image_url": "https://cdn.example.com/poses/ref1.jpg"
    }
    // ... 共 5 个
  ],
  "session_id": "session_456"
}
```

---

## 三、Flutter 端详细设计

### 3.1 项目结构（实际代码，2026-05-25）

```
src/flutter_app/
├── lib/
│   ├── main.dart                               # 入口
│   ├── app.dart                                # MaterialApp 配置
│   │
│   ├── core/                                   # 核心基础设施
│   │   ├── api_client.dart                     # Dio HTTP 客户端
│   │   ├── connectivity_checker.dart           # 在线/离线检测
│   │   ├── tts_service.dart                    # TTS 语音引导（防抖/静音/分场景）
│   │   └── constants.dart                      # API/MlModels/StorageKeys 常量
│   │
│   ├── features/                               # 功能模块 (feature-first)
│   │   ├── camera/                             # 相机模块
│   │   │   ├── presentation/
│   │   │   │   ├── camera_page.dart            # 主相机页面 (ConsumerStatefulWidget)
│   │   │   │   └── widgets/
│   │   │   │       ├── camera_preview.dart     # 相机预览
│   │   │   │       ├── capture_button.dart     # 拍照按钮
│   │   │   │       ├── mode_switcher.dart      # 前后摄切换
│   │   │   │       ├── camera_params_card.dart # 参数建议卡片 (右)
│   │   │   │       ├── styling_card.dart       # 服装道具卡片 (左)
│   │   │   │       ├── photographer_guide_bar.dart  # 构图引导栏
│   │   │   │       └── expression_guide_overlay.dart # 表情引导文字叠加
│   │   │   └── domain/
│   │   │       ├── providers.dart              # 所有 Riverpod providers
│   │   │       └── services/
│   │   │           ├── pose_detector.dart       # MediaPipe 33点骨骼检测
│   │   │           ├── scene_analyzer.dart      # 规则场景分类器 (Phase 1)
│   │   │           ├── hybrid_scene_analyzer.dart # TFLite+规则混合分析器
│   │   │           ├── tflite_scene_classifier.dart # MobileNetV3 TFLite 封装
│   │   │           ├── tflite_depth_estimator.dart  # MiDaS 深度估计 TFLite
│   │   │           ├── lighting_analyzer.dart   # 光质/逆光/方向分析（NV21 Y平面）
│   │   │           ├── expression_detector.dart # ML Kit 6分类表情检测
│   │   │           └── camera_params_service.dart   # 相机参数推荐 (小白+进阶)
│   │   │
│   │   ├── ar/                                 # AR 叠加模块
│   │   │   ├── presentation/widgets/
│   │   │   │   └── ar_overlay.dart             # 骨骼叠加 + 评分环 + 纠正提示
│   │   │   └── domain/services/
│   │   │       └── alignment_scorer.dart       # 33关节点对齐度评分 (0-100)
│   │   │
│   │   ├── recommendation/                     # 推荐模块
│   │   │   ├── presentation/widgets/
│   │   │   │   └── recommendation_panel.dart   # 姿势推荐轮播面板
│   │   │   └── domain/services/
│   │   │       ├── recommendation_service.dart      # 推荐状态管理
│   │   │       ├── local_pose_loader.dart           # 本地300姿势加载
│   │   │       ├── local_recommendation_engine.dart # 离线推荐引擎
│   │   │       ├── styling_service.dart             # 服装道具推荐
│   │   │       └── photographer_guidance_service.dart # 摄影师构图指导
│   │   │
│   │   ├── evaluation/                         # 拍后修图模块
│   │   │   ├── presentation/
│   │   │   │   ├── review_edit_page.dart       # 全屏修图页 (GPU Shader)
│   │   │   │   └── widgets/
│   │   │   │       ├── evaluation_result_sheet.dart # 评分底部弹窗
│   │   │   │       ├── preset_panel.dart            # 预设轮播选择
│   │   │   │       └── adjustment_sliders.dart      # 8参数手动滑块
│   │   │   └── domain/
│   │   │       ├── providers.dart              # preset 相关 providers
│   │   │       └── services/
│   │   │           ├── preset_loader.dart       # 预设加载与索引
│   │   │           ├── hald_clut_engine.dart    # CPU Hald CLUT (缩略图)
│   │   │           ├── gpu_lut_engine.dart      # GPU Shader LUT (实时预览)
│   │   │           └── local_evaluation_engine.dart # 本地四维评分引擎
│   │   │
│   │   └── profile/                            # 用户模块
│   │       └── presentation/
│   │           └── profile_page.dart
│   │
│   └── shared/                                 # 共享层
│       └── models/
│           ├── pose.dart                       # Skeleton3D / Keypoint
│           ├── recommendation.dart             # PoseRecommendation / CameraParams
│           ├── scene_features.dart             # SceneFeatures / LightingInfo / SpatialInfo
│           ├── preset.dart                     # Preset / PresetBundle / PresetAdjustments
│           ├── evaluation.dart                 # EvaluationResult / DimensionScore
│           └── user_profile.dart               # UserProfile / StylePreferences
│
├── shaders/
│   └── hald_clut.frag                          # GPU Hald CLUT fragment shader
│
├── assets/
│   ├── models/                                 # TFLite 模型 (.tflite 占位)
│   ├── poses/                                  # 本地姿势库 JSON
│   ├── presets/                                # 10个预设 (.cube + .json + _hald.png)
│   ├── images/
│   └── fonts/
│
├── pubspec.yaml
└── analysis_options.yaml
```

### 3.2 已实现的 Provider 树（实际代码）

```
cameraControllerProvider        — CameraController
├── detectedPoseProvider        — DetectedPose? (MediaPipe 33点)
├── sceneAnalysisResultProvider — SceneAnalysisResult? (规则/TFLite)
│   └── hybridSceneAnalyzerProvider — HybridSceneAnalyzer (TFLite+规则混合)
│       └── richSceneResultProvider  — RichSceneResult? (含深度+光照)
│
├── currentRecommendationsProvider — RecommendationResponse?
│   ├── activeRecommendationIndexProvider — int
│   ├── recommendationServiceProvider   — RecommendationService
│   ├── localEngineProvider             — LocalRecommendationEngine (离线)
│   └── cameraParamsRecommendationProvider — CameraParamsRecommendation? (姿势联动)
│
├── stylingServiceProvider      — StylingService
│   └── stylingRecommendationProvider — StylingRecommendation? (服装+道具)
│
├── photographerGuidanceServiceProvider — PhotographerGuidanceService
│   └── photographerGuidanceProvider    — PhotographerGuidance? (构图+角度)
│
├── apiClientProvider           — ApiClient (http://10.0.2.2:8080)
├── connectivityCheckerProvider — ConnectivityChecker
│   └── isOnlineProvider        — bool
│
├── lightingAnalyzerProvider     — LightingAnalyzer (光质/逆光/方向)
│   └── lightingAnalysisResultProvider — LightingAnalysisResult?
│
├── expressionDetectorProvider   — ExpressionDetector (ML Kit 6分类)
│   └── expressionResultProvider — ExpressionResult?
│
├── ttsServiceProvider           — TtsService (防抖语音引导)
├── ttsMutedProvider             — bool (静音状态)
│
├── alignmentResultProvider      — AlignmentResult? (共享对齐评分)
│
├── presetLoaderProvider        — PresetLoader (10预设)
├── gpuLutEngineProvider        — GpuLutEngine (GPU Shader)
├── activePresetProvider        — Preset? (当前选中预设)
└── sliderOverridesProvider     — Map<String, double> (参数覆盖)
    └── effectiveAdjustmentsProvider — Map<String, double> (合并值)
```

---

## 四、云端后端设计

### 4.1 技术栈

| 组件 | 选型 | 理由 |
|------|------|------|
| 语言 | Python 3.12 | AI/ML 生态最完善 |
| 框架 | FastAPI | 异步、性能好、自动生成 OpenAPI |
| 异步任务 | Celery + Redis | 姿势数据管线、离线分析 |
| API 网关 | Nginx + 自研网关 | 认证、限流、日志 |
| 数据库 | PostgreSQL 16 | 用户/姿势/POI 结构化数据 |
| 向量数据库 | Milvus | 姿势语义检索 |
| 缓存 | Redis | 热门推荐缓存、会话状态 |
| 对象存储 | MinIO (自建) / 阿里云 OSS | 参考图、模型文件 |
| 监控 | Prometheus + Grafana | 推理延迟、QPS、错误率 |

### 4.2 后端项目结构

```
src/backend/
├── app/
│   ├── main.py                    # FastAPI 入口
│   ├── config.py                  # 配置管理
│   │
│   ├── api/                       # API 路由
│   │   ├── v1/
│   │   │   ├── router.py
│   │   │   ├── recommend.py       # POST /api/v1/recommend
│   │   │   ├── poses.py           # GET /api/v1/poses
│   │   │   ├── evaluate.py        # POST /api/v1/evaluate
│   │   │   ├── users.py           # 用户 CRUD
│   │   │   └── health.py          # GET /health
│   │   └── deps.py                # 依赖注入
│   │
│   ├── domain/                    # 领域服务
│   │   ├── recommendation/
│   │   │   ├── engine.py          # 推荐引擎编排
│   │   │   ├── retriever.py       # 向量检索
│   │   │   ├── ranker.py          # 排序逻辑
│   │   │   └── scorer.py          # 美学评分
│   │   ├── scene/
│   │   │   └── analyzer.py        # 云端场景深度分析
│   │   ├── pose/
│   │   │   ├── manager.py         # 姿势 CRUD
│   │   │   └── generator.py       # AI 姿势生成
│   │   ├── evaluation/
│   │   │   └── evaluator.py       # 拍后评估
│   │   └── user/
│   │       └── profiler.py        # 用户画像更新
│   │
│   ├── infrastructure/            # 基础设施
│   │   ├── db/
│   │   │   ├── postgres.py
│   │   │   └── milvus.py
│   │   ├── cache/
│   │   │   └── redis.py
│   │   ├── storage/
│   │   │   └── minio.py
│   │   └── llm/
│   │       ├── qwen_client.py     # 通义千问 API
│   │       ├── deepseek_client.py # DeepSeek API
│   │       └── model_router.py    # 多模型路由/fallback
│   │
│   ├── models/                    # 数据模型 (SQLAlchemy)
│   │   ├── user.py
│   │   ├── pose.py
│   │   ├── recommendation_log.py
│   │   └── poi.py
│   │
│   └── schemas/                   # Pydantic 请求/响应 schema
│       ├── recommend.py
│       ├── pose.py
│       └── user.py
│
├── workers/                       # Celery 异步任务
│   ├── pose_pipeline.py           # 姿势数据管线
│   ├── user_profile_updater.py    # 用户画像更新
│   └── content_moderation.py      # 内容审核
│
├── migrations/                    # Alembic 数据库迁移
├── tests/
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

### 4.3 API 设计

| 方法 | 路径 | 说明 | 调用频率 |
|------|------|------|----------|
| `POST` | `/api/v1/recommend` | 姿势推荐（核心接口，返回姿势+参数+服装+道具+预设） | 每 1-2 秒 |
| `GET` | `/api/v1/poses/{pose_id}` | 获取单个姿势详情 | 按需 |
| `GET` | `/api/v1/poses?scene=X&style=Y` | 姿势搜索/过滤 | 按需 |
| `POST` | `/api/v1/evaluate` | 拍后照片评估 | 每张照片 |
| `POST` | `/api/v1/presets/recommend` | 后期预设推荐（新增） | 每张照片 |
| `GET` | `/api/v1/presets` | 获取预设列表 | 按需 |
| `POST` | `/api/v1/feedback` | 推荐反馈（用户选择了哪个姿势/预设） | 每次选择 |
| `GET` | `/api/v1/users/me` | 获取用户画像 | 启动时 |
| `PATCH` | `/api/v1/users/me/preferences` | 更新偏好 | 按需 |
| `GET` | `/api/v1/device/capability?model=X` | 查询设备相机能力（新增） | 启动时 |
| `POST` | `/api/v1/poses/clone` | 姿势克隆（从照片提取姿势） | Phase 3 |
| `GET` | `/api/v1/poi/nearby?lat=X&lng=Y` | 附近拍照点 | Phase 3 |

### 4.4 多模型编排策略

```
推荐请求
     │
     ▼
┌────────────┐
│ 模型路由器   │ ← 根据请求类型 + 模型可用性选择模型
└─────┬──────┘
      │
      ├── 场景深度分析 → Qwen-VL-Max（主）/ GLM-4V（备）
      │   输入: 场景特征向量 + 环境描述文本
      │   输出: 细粒度场景标签 + 氛围描述 + 拍摄建议
      │
      ├── 姿势匹配排序 → Milvus 向量检索 + DeepSeek 策略推理
      │   输入: 场景embedding + 用户画像
      │   输出: Top 5 姿势ID + 排序理由
      │
      ├── 美学评分 → 自有微调模型
      │   输入: 场景特征 + 候选姿势骨骼
      │   输出: 每个候选姿势的美学分数
      │
      └── 个性化调整 → DeepSeek
          输入: 用户历史行为 + Top 5 候选
          输出: 重排序后的 Top 5 + 个性化理由
```

---

## 五、数据模型

### 5.1 核心表结构 (PostgreSQL)

```sql
-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY,
    nickname VARCHAR(50),
    gender VARCHAR(10),
    height_cm INTEGER,
    body_type VARCHAR(20),
    face_shape VARCHAR(20),
    skin_tone VARCHAR(20),
    style_preferences JSONB,          -- ["sweet", "fresh", "elegant"]
    skill_level VARCHAR(20),          -- beginner/intermediate/pro
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 姿势表
CREATE TABLE poses (
    id VARCHAR(64) PRIMARY KEY,       -- pose_id
    name_zh VARCHAR(100),
    name_en VARCHAR(100),
    description_zh TEXT,
    description_en TEXT,
    taxonomy JSONB NOT NULL,          -- 分类标签
    skeleton_3d JSONB NOT NULL,       -- 3D 骨骼数据
    guidance JSONB,                    -- 拍摄指导
    suitability JSONB,                 -- 适配条件
    quality_score FLOAT DEFAULT 0,
    popularity_score FLOAT DEFAULT 0,
    usage_count INTEGER DEFAULT 0,
    source VARCHAR(30),               -- photographer / social_crawl / ai_generated / ugc
    status VARCHAR(20) DEFAULT 'pending',  -- pending/reviewed/published/rejected
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 推荐日志
CREATE TABLE recommendation_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    session_id UUID,
    scene_features JSONB,             -- 场景特征
    recommended_poses JSONB,          -- 推荐的姿势ID列表
    selected_pose_id VARCHAR(64),     -- 用户选择的姿势（可为null=未选择）
    feedback_score INTEGER,           -- 用户评分(1-5)
    created_at TIMESTAMP DEFAULT NOW()
);

-- POI 打卡点（V2）
CREATE TABLE pois (
    id BIGSERIAL PRIMARY KEY,
    name_zh VARCHAR(200),
    location GEOGRAPHY(POINT),
    best_poses JSONB,                 -- 该地点最佳姿势ID列表
    best_time VARCHAR(50),            -- 最佳拍摄时间
    best_angle JSONB,                 -- 最佳拍摄角度
    photo_count INTEGER DEFAULT 0,
    avg_rating FLOAT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_poses_taxonomy ON poses USING GIN (taxonomy);
CREATE INDEX idx_poses_status ON poses (status);
CREATE INDEX idx_poses_popularity ON poses (popularity_score DESC);
CREATE INDEX idx_pois_location ON pois USING GIST (location);
```

### 5.2 向量存储 (Milvus)

```
Collection: pose_vectors
  - pose_id: VARCHAR (primary key)
  - embedding: FLOAT_VECTOR (544维)
  - scene_type: VARCHAR (分区键)
  - style: VARCHAR (分区键)
  - difficulty: VARCHAR

索引: IVF_FLAT + 欧氏距离
分区: 按 scene_type 分区加速检索
```

---

## 六、部署方案

### 6.1 Phase 1 部署拓扑

```
┌────────────────────────────────────────────┐
│             阿里云 ECS (或类似)              │
│                                              │
│  ┌────────────────┐  ┌───────────────────┐  │
│  │ Nginx (HTTPS)   │  │ Prometheus        │  │
│  │ + Let's Encrypt │  │ + Grafana         │  │
│  └───────┬────────┘  └───────────────────┘  │
│          │                                    │
│  ┌───────┴────────┐                          │
│  │ FastAPI × 4    │  (Gunicorn + Uvicorn)    │
│  └───────┬────────┘                          │
│          │                                    │
│  ┌───────┴──────────────────────────────┐   │
│  │ PostgreSQL │ Milvus │ Redis │ MinIO   │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  外部 API 调用：                               │
│  - 阿里云百炼 (Qwen-VL)                       │
│  - DeepSeek API                              │
└──────────────────────────────────────────────┘
```

### 6.2 资源配置建议

| 服务 | Phase 1 (MVP) | Phase 3 (规模化) |
|------|--------------|------------------|
| ECS 实例 | 2 台 4C8G | 4 台 8C16G + 自动伸缩 |
| PostgreSQL | 1 台 2C4G (RDS) | 2C8G + 只读副本 |
| Milvus | 单节点 4C16G | 集群模式 |
| Redis | 1 台 2C4G | 主从 + Sentinel |
| MinIO | ECS 本地磁盘 | 对象存储 OSS |
| 带宽 | 5 Mbps | 100 Mbps + CDN |

---

## 七、关键技术决策

| # | 决策 | 选择 | 理由 |
|---|------|------|------|
| 1 | AR 实现方式 | ARCore Platform Channel (非纯 Flutter 插件) | 国产手机 ARCore 兼容性参差不齐，需要原生层面的 fallback 逻辑 |
| 2 | 端侧模型推理 | TFLite GPU Delegate | Android 上最成熟的端侧推理方案 |
| 3 | 人体检测 | MediaPipe Pose (非 MLKit) | 更好的实时性能，33 个关键点 vs 17 个 |
| 4 | 网络协议 | HTTPS (推荐) + WebSocket (实时反馈) | 推荐请求不需要流式，但 AR 对齐度反馈可考虑 WebSocket |
| 5 | 状态管理 | Riverpod (非 BLoC) | 更适合 Provider 嵌套（相机流 → 分析 → 推荐 → AR） |
| 6 | 后端框架 | FastAPI (非 Django) | 异步原生的 LLM API 代理场景更合适 |
| 7 | LLM 多模型策略 | 主备双路 + 降级 | 国产模型 API 稳定性不如 OpenAI，必须有 fallback |
| 8 | LUT 应用 | GPU Shader (Hald CLUT) | 性能最优，<5ms 全分辨率预览 |
| 9 | 服装颜色匹配 | HSV 色彩空间 + 互补色规则 | 计算量小，可在端侧完成基础匹配 |

---

## 八、后续待细化

- [ ] 端侧模型的具体训练计划和数据集需求
- [ ] ARCore 在主流国产手机上的兼容性测试清单
- [ ] 云端推理成本预估（按 Qwen-VL API 定价 × 预估调用量）
- [ ] 主流手机专业模式能力真机测试（相机参数知识库的数据来源）
- [ ] 服装/道具知识库种子数据采集（6 场景 × 5 道具）
- [ ] 10 个基础 LUT 的制作与调校
- [ ] 安全审计清单（数据加密、传输安全、存储安全）
- [ ] CI/CD 流水线设计
- [ ] Firebase/Google Play 上架准备清单
