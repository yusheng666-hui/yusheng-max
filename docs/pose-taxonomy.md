# 姿势知识库设计 (Pose Taxonomy & Knowledge Base)

> 本文档定义姿势的分类体系、数据结构、数据来源管线，是整个推荐系统的核心资产。

---

## 一、设计原则

1. **结构化优先**: 每个姿势必须有完备的元数据，支持多维度检索和过滤
2. **可演化**: 分类体系和字段可以持续扩展，不破坏已有数据
3. **人机共读**: 数据结构同时面向 AI（向量检索/规则匹配）和人类（姿势库维护/审核）
4. **质量可控**: 每个入库姿势必须经过审核流程（自动 + 人工）

---

## 二、姿势分类体系 (Taxonomy)

### 2.1 一级分类：按人数

```
拍照人数
├── 单人 (single)
├── 双人 (duo)
│   ├── 情侣 (couple)
│   ├── 闺蜜 (bestie)
│   ├── 亲子 (parent-child)
│   └── 普通合照 (friends)
└── 多人 (group, 3+人)
    ├── 家庭 (family)
    ├── 朋友团 (squad)
    └── 大合照 (large-group, 7+人)
```

### 2.2 二级分类：按身体姿态

```
单人身体姿态
├── 站姿 (standing)
│   ├── 正对镜头
│   ├── 侧对镜头 / 回眸
│   ├── 交叉腿站
│   ├── 单腿微弯
│   └── 靠墙/靠栏杆
├── 坐姿 (sitting)
│   ├── 正坐
│   ├── 侧坐
│   ├── 二郎腿
│   ├── 抱膝坐
│   └── 靠坐
├── 蹲姿 (squatting)
│   ├── 全蹲
│   └── 半蹲/微蹲
├── 动态 (dynamic)
│   ├── 走路/回眸一笑
│   ├── 跳起
│   ├── 旋转（裙摆飞扬）
│   ├── 撩头发
│   └── 奔跑
├── 躺姿 (lying)
│   ├── 仰躺
│   └── 侧躺
└── 特殊 (special)
    ├── 剪影
    ├── 背影
    ├── 对镜自拍
    └── 局部特写（手/脚/侧脸）
```

### 2.3 三级分类：按风格

```
风格标签 (style)
├── 酷飒 (cool)
├── 甜美 (sweet)
├── 清新/日系 (fresh)
├── 复古/港风 (retro)
├── 优雅/气质 (elegant)
├── 慵懒/随性 (casual)
├── 性感/氛围感 (sensual)
├── 活泼/元气 (energetic)
├── 高级/时尚 (high-fashion)
└── 自然/生活感 (natural)
```

### 2.4 四级分类：按场景适配

```
场景类型 (scene_type)
├── 自然户外 (outdoor-nature)
│   ├── 海滩/海边
│   ├── 山巅/草地
│   ├── 花田/花海
│   ├── 森林/树林
│   ├── 沙漠/戈壁
│   └── 雪地
├── 城市街拍 (urban-street)
│   ├── 斑马线/马路中间
│   ├── 咖啡厅门口/露天座位
│   ├── 涂鸦墙/艺术墙
│   ├── 建筑/地标
│   ├── 天桥/楼梯
│   └── 闹市/夜市
├── 室内 (indoor)
│   ├── 酒店/民宿
│   ├── 餐厅/咖啡厅内
│   ├── 美术馆/展览
│   ├── 居家
│   └── 商场
├── 特殊场景 (special-scene)
│   ├── 夜景/霓虹灯
│   ├── 雨雪天
│   ├── 逆光/剪影
│   ├── 水中/泳池
│   └── 交通工具内
└── 其他 (other)
```

### 2.5 辅助标签维度

| 标签维度 | 可选值 | 说明 |
|----------|--------|------|
| **难度** | `beginner` / `intermediate` / `advanced` | 对身体协调性的要求 |
| **镜头焦段** | `wide` / `standard` / `telephoto` / `portrait-mode` | 推荐使用的焦段 |
| **构图方式** | `center` / `rule-of-thirds` / `leading-lines` / `frame-within-frame` / `negative-space` | 推荐构图法则 |
| **光线偏好** | `front-light` / `side-light` / `backlight` / `golden-hour` / `overcast` / `any` | 最适合的光线条件 |
| **最佳拍摄时间** | `morning` / `noon` / `afternoon` / `golden-hour` / `night` / `any` | 一天中最佳时段 |
| **景别** | `full-body` / `three-quarter` / `half-body` / `close-up` / `detail` | 全身/大半身/半身/特写 |
| **适合体型** | `petite` / `average` / `tall` / `plus-size` / `any` | 身材适配（避免推荐不合适姿势） |
| **适合服装** | `dress-skirt` / `pants` / `shorts` / `traditional` / `formal` / `casual` | 服装配合 |
| **适合发型** | `long` / `short` / `tied` / `any` | 发型影响姿势效果 |

---

## 三、姿势数据结构

### 3.1 完整 Schema

```json
{
  "pose_id": "beach-standing-crossleg-001",
  "version": 1,
  "status": "published",

  // === 基础信息 ===
  "name": {
    "zh": "海边交叉腿回眸",
    "en": "Beach Cross-Leg Lookback"
  },
  "description": {
    "zh": "重心放后腿，前腿微弯脚尖点地，上半身微侧，回头看向镜头",
    "en": "Weight on back leg, front leg slightly bent, turn upper body and look back at camera"
  },

  // === 分类标签 ===
  "taxonomy": {
    "person_count": "single",
    "body_position": "standing",
    "sub_position": "cross-leg-lookback",
    "style": ["fresh", "natural"],
    "scene_type": ["outdoor-nature"],
    "scene_subtype": ["beach", "grassland"],
    "difficulty": "beginner"
  },

  // === 3D 骨骼数据 (用于 AR 渲染) ===
  "skeleton_3d": {
    "format": "mediapipe_33",
    "keypoints": [
      {"id": 0,  "name": "nose",            "x": 0.50, "y": 0.08, "z": 0.0, "visibility": 1.0},
      {"id": 11, "name": "left_shoulder",   "x": 0.45, "y": 0.18, "z": 0.1, "visibility": 1.0},
      {"id": 12, "name": "right_shoulder",  "x": 0.55, "y": 0.18, "z": 0.1, "visibility": 1.0},
      {"id": 13, "name": "left_elbow",      "x": 0.38, "y": 0.30, "z": 0.2, "visibility": 1.0},
      {"id": 14, "name": "right_elbow",     "x": 0.60, "y": 0.28, "z": 0.2, "visibility": 1.0},
      {"id": 15, "name": "left_wrist",      "x": 0.32, "y": 0.42, "z": 0.3, "visibility": 1.0},
      {"id": 16, "name": "right_wrist",     "x": 0.65, "y": 0.38, "z": 0.3, "visibility": 1.0},
      {"id": 23, "name": "left_hip",        "x": 0.47, "y": 0.50, "z": 0.0, "visibility": 1.0},
      {"id": 24, "name": "right_hip",       "x": 0.53, "y": 0.50, "z": 0.0, "visibility": 1.0},
      {"id": 25, "name": "left_knee",       "x": 0.44, "y": 0.72, "z": 0.2, "visibility": 1.0},
      {"id": 26, "name": "right_knee",      "x": 0.56, "y": 0.70, "z": 0.0, "visibility": 1.0},
      {"id": 27, "name": "left_ankle",      "x": 0.42, "y": 0.92, "z": 0.2, "visibility": 1.0},
      {"id": 28, "name": "right_ankle",     "x": 0.58, "y": 0.90, "z": 0.0, "visibility": 1.0}
    ],
    "normalization": "body_height_relative",
    "anchor_point": "mid_hip"
  },

  // === 参考图片 ===
  "reference_images": [
    {
      "url": "https://cdn.example.com/poses/beach-crossleg-001-ref1.jpg",
      "source": "photographer_portfolio",
      "photographer": "张三",
      "license": "licensed",
      "width": 1080,
      "height": 1350
    }
  ],

  // === 拍摄指导 ===
  "guidance": {
    "photographer_tips": {
      "zh": "使用人像模式，从腰部高度仰拍，显得腿更长",
      "en": "Use portrait mode, shoot from waist height for longer leg effect"
    },
    "model_tips": {
      "zh": "重心放后腿，前腿微弯脚尖点地，手自然下垂或轻插口袋，回头看镜头时下巴微收",
      "en": "Weight on back leg, front toe tap, hands natural, chin slightly down when looking back"
    },
    "step_by_step": [
      "侧身站立，重心放在后腿",
      "前腿微弯，脚尖轻轻点地",
      "上半身微微转向镜头方向",
      "一手自然下垂，另一手轻插口袋（或拿道具）",
      "头转回看向镜头，下巴微收，眼神放松",
      "拍照者从略低角度拍摄"
    ],
    "voice_guidance": [
      "侧身站好，重心放后脚",
      "前脚脚尖点地，膝盖微弯",
      "好，现在回头看镜头",
      "下巴收一点点，眼神放松",
      "保持住！"
    ],
    "common_mistakes": [
      "驼背耸肩",
      "下巴抬太高",
      "前腿弯曲太多导致比例奇怪",
      "回眸时身体转太多变成正对镜头"
    ],
    "key_muscles": ["relax_shoulders", "straight_back", "soft_gaze"]
  },

  // === 适配条件 ===
  "suitability": {
    "body_types": ["petite", "average", "tall"],
    "height_ratio": "any",
    "clothing": ["dress-skirt", "pants", "shorts"],
    "hair": "any",
    "accessories_recommended": ["hat", "sunglasses"],
    "lighting": ["front-light", "side-light", "golden-hour"],
    "time_of_day": ["golden-hour", "afternoon"],
    "focal_length": ["portrait-mode", "standard"]
  },

  // === 元数据 ===
  "metadata": {
    "created_at": "2026-05-25T00:00:00Z",
    "updated_at": "2026-05-25T00:00:00Z",
    "created_by": "pose_curator_team",
    "reviewed_by": "senior_photographer_01",
    "quality_score": 4.5,
    "popularity_score": 0,
    "usage_count": 0,
    "source": "photographer_portfolio",
    "tags": ["beach", "cross-leg", "look-back", "beginner-friendly", "lengthen-legs"]
  }
}
```

### 3.2 数据字段说明

| 字段组 | 用途 | 使用方 |
|--------|------|--------|
| `pose_id` | 全局唯一标识，格式: `{scene}-{position}-{feature}-{seq}` | 所有系统 |
| `taxonomy` | 多维度分类标签，用于检索和过滤 | 推荐引擎、搜索 |
| `skeleton_3d` | 标准化的 33 点人体骨骼坐标（MediaPipe 格式） | AR 渲染引擎 |
| `reference_images` | 姿势的参考照片 | UI 展示、用户浏览 |
| `guidance` | 分角色的拍摄指导（摄影师 + 模特文案 + 步骤序列 + 语音文本） | 文字提示、TTS 语音 |
| `suitability` | 姿势的适配条件范围 | 推荐引擎过滤（避免给矮个子推荐显矮的姿势） |
| `metadata` | 数据溯源和质量控制信息 | 内容审核、质量监控 |

---

## 四、数据来源管线

### 4.1 来源一览

```
数据来源优先级（质量 高→低）：
┌─────────────────────────────────────────────┐
│ L1: 专业摄影师投稿（付费授权）                │  ← 质量最高，有真人模特+专业布光
│     审核: 人工                              │
├─────────────────────────────────────────────┤
│ L2: 社交媒体热门姿势（爬虫+骨骼提取）         │  ← 量大，质量有保证（已经被社交验证）
│     审核: AI 初筛 + 人工抽检                 │
├─────────────────────────────────────────────┤
│ L3: AI 生成姿势（LLM + 骨骼生成模型）        │  ← 快速扩充，需人工验证合理性
│     审核: AI 合理性检查 + 人工抽检           │
├─────────────────────────────────────────────┤
│ L4: UGC 用户上传                             │  ← V2 阶段，需完整审核管线
│     审核: NSFW 自动检测 + 社区举报           │
└─────────────────────────────────────────────┘
```

### 4.2 L2 管线：社交媒体抓取 → 入库

```
Instagram/Xiaohongshu/Douyin
     │
     ▼ 关键词爬取（#拍照姿势 #拍照技巧 #拍照教学）
┌────────────┐
│ 原始图片收集 │
└──────┬─────┘
       ▼ 去重（pHash 感知哈希）
┌────────────┐
│ 图片去重     │
└──────┬─────┘
       ▼ MediaPipe Pose → 提取骨骼坐标
┌────────────┐
│ 骨骼提取     │ ← 过滤：骨骼点置信度 < 0.7 的丢弃
└──────┬─────┘
       ▼ Qwen-VL → 场景分析 + 风格打标 + 质量评估
┌────────────┐
│ AI 自动标注  │
└──────┬─────┘
       ▼ AI 打分 < 阈值 → 丢弃
┌────────────┐
│ 质量过滤     │
└──────┬─────┘
       ▼ 人工抽检（每批次抽 5%）
┌────────────┐
│ 入库         │ → Milvus (向量) + PostgreSQL (元数据)
└────────────┘
```

### 4.3 L3 管线：AI 姿势生成

```
已有姿势库（种子集）
     │
     ▼
┌────────────────┐
│ 姿势变异生成     │ ← DeepSeek: "基于这个海边站姿，生成5个变体：
│                │     1.换手位置  2.换腿姿态  3.换头部角度  4.加道具  5.改全身/半身"
└───────┬────────┘
        ▼ 骨骼合理性检查（关节角度不超出人体范围）
┌────────────────┐
│ 生物力学验证     │
└───────┬────────┘
        ▼ Qwen-VL: "这个姿势看起来自然吗？能否保持？适合拍照吗？"
┌────────────────┐
│ 自然度评估       │
└───────┬────────┘
        ▼
┌────────────────┐
│ 入库（标记来源=AI）│
└────────────────┘
```

---

## 五、姿势检索策略

### 5.1 向量检索（语义相似度）

用于 "用户场景自由匹配" 场景。向量由多维度特征拼接：

```
姿势向量 embedding = concat([
    骨骼形状向量 (128d),      ← MediaPipe 坐标 → PCA 降维
    场景适配向量 (64d),       ← 场景类型 one-hot → MLP
    风格向量 (32d),          ← 风格标签 one-hot → MLP
    动作特征向量 (64d),       ← 身体姿态描述文本 → text-embedding
    视觉特征向量 (256d)       ← 参考图 → CLIP image embedding
]) → 544 维
```

### 5.2 规则检索（精确匹配）

用于"用户明确指定条件"场景：
- "给我看所有街拍 + 单人 + 站立 + 酷飒风格"
- "适合身高 160cm 以下 + 穿裙子的姿势"

### 5.3 混合检索（推荐引擎主策略）

```
用户场景特征 → 规则过滤（排除不适合的姿势）
           → 向量检索（语义相似度 Top 50）
           → 多样性重排（避免 5 个姿势太相似）
           → 个性化排序（用户画像加权）
           → 返回 Top 5
```

---

## 六、Phase 1 姿势清单（MVP 100 姿势）

| 场景 | 站姿 | 坐姿 | 动态 | 特殊 | 小计 |
|------|------|------|------|------|------|
| 户外自然 | 8 | 4 | 4 | 4（背影/剪影/躺/局部） | 20 |
| 街拍 | 8 | 4 | 4 | 4（对镜/靠墙/背影/楼梯） | 20 |
| 室内 | 6 | 6 | 2 | 6（对镜/靠墙/躺/窗边/局部） | 20 |
| 海滩 | 6 | 4 | 6 | 4（踏浪/剪影/躺/背影） | 20 |
| 夜景 | 6 | 4 | 2 | 8（霓虹灯下/剪影/背影/车流前） | 20 |
| **合计** | **34** | **22** | **18** | **26** | **100** |

---

## 七、后续演进方向

- **姿势 A/B 测试**: 同一场景投放两组姿势，追踪哪组被采用率更高，数据驱动姿势质量提升
- **姿势时序关系**: 连续姿势之间的自然过渡（用于视频/连拍）
- **区域性姿势差异**: 中日韩 vs 欧美拍照姿势偏好不同，建立区域化的姿势库
- **实时热点**: 从社交媒体实时抓取病毒式传播的拍照姿势，快速入库
