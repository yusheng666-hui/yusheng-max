# 后期预设引擎设计 (Post-Processing Preset Engine)

> 本文档定义后期预设的分类体系、LUT 数据结构、成片分析→预设匹配管线、预设市场设计及与第三方工具的对接方案。

---

## 一、设计目标

**拍完不是终点。** 自动分析成片风格特征，推荐最合适的后期调色方案，并支持端侧实时预览。从"AI 告诉你拍什么"到"AI 告诉你拍完怎么修"。

---

## 二、预设分类体系

### 2.1 预设风格树

```
预设分类
├── 按基础风格 (Phase 1: 10个)
│   ├── 自然 (Natural) — 保留原色，微调曝光和对比
│   ├── 日系清新 (JP-Fresh) — 低饱和、高亮、冷偏青
│   ├── 胶片感 (Film) — 暖调、微颗粒、暗角、褪色
│   ├── 黑白 (B&W) — 去色、高对比、强调光影
│   ├── 暖调人像 (Warm Portrait) — 肤色优化、暖色氛围
│   ├── 冷调 (Cool Tone) — 蓝灰暗调、情绪感
│   ├── 复古港风 (HK Retro) — 红绿调、柔光、年代感
│   ├── 高级灰 (Moody Gray) — 低保和、灰阶丰富、高级感
│   ├── HDR 强化 (HDR Pop) — 细节锐化、色彩增强
│   └── 素颜白 (Clean White) — 高亮白净、低对比、干净通透
│
├── 按场景适配 (Phase 2: 扩展到30+)
│   ├── 海边专用
│   │   ├── 日系蓝调 (Sea Blue)
│   │   ├── 金色海滩 (Golden Beach)
│   │   └── 褪色胶片海滩 (Faded Beach Film)
│   ├── 街拍专用
│   │   ├── 青橙调 (Teal & Orange)
│   │   ├── 暗调街拍 (Street Dark)
│   │   └── 日系街拍 (JP Street)
│   ├── 夜景专用
│   │   ├── 霓虹赛博 (Cyber Neon)
│   │   ├── 蓝调夜景 (Blue Night)
│   │   └── 暖光氛围 (Warm Night)
│   └── ...
│
└── 按风格达人 (Phase 3: 预设市场)
    ├── 摄影师A联名预设包
    ├── 网红博主B预设包
    └── ...
```

### 2.2 Phase 1 内置 10 预设速查

| 预设ID | 名称 | 特征 | 适用场景 |
|--------|------|------|----------|
| `natural` | 自然 | 原色调、微调曝光对比 | 任何场景的保底选择 |
| `jp-fresh` | 日系清新 | 低饱和、高亮度、冷青调 | 户外自然、花田、白墙 |
| `film-warm` | 暖调胶片 | 暖色调、微颗粒、暗角 | 街拍、咖啡厅、逆光 |
| `bw-high` | 高对比黑白 | 去色、强烈对比、强调光影 | 建筑背景、剪影、情绪人像 |
| `warm-portrait` | 暖调人像 | 肤色平滑、暖色氛围 | 室内、窗光、逆光人像 |
| `cool-mood` | 冷调情绪 | 蓝灰暗调、低饱和 | 阴天、雨天、夜景 |
| `hk-retro` | 复古港风 | 红绿调、柔光、低清晰度 | 街拍、霓虹灯、室内暖光 |
| `moody-gray` | 高级灰 | 低保和、灰阶丰富 | 极简建筑、街拍、工业风 |
| `hdr-pop` | HDR强化 | 细节锐化、色彩增强 | 风景人像、蓝天白云 |
| `clean-white` | 素颜白 | 高亮白净、低对比 | 白墙、白色背景、清新风 |

---

## 三、LUT 数据结构

### 3.1 LUT 格式选择

| 格式 | 优点 | 缺点 | 选择 |
|------|------|------|------|
| `.cube` | 通用标准，Lightroom/DaVinci 都支持 | 文件大（33³=35K 采样点） | ✅ 主格式 |
| `.3dl` | 专业调色标准 | 兼容性一般 | ❌ |
| `.png` (Hald CLUT) | 单张图片即可，跨平台 | 精度略低 | ✅ 端侧轻量预览 |

### 3.2 预设数据模型

```json
{
  "preset_id": "jp-fresh-001",
  "name": {"zh": "日系清新", "en": "Japanese Fresh"},
  "version": 1,
  "status": "published",
  "category": "style",
  "style_tags": ["fresh", "clean", "bright", "low-saturation"],

  "lut_files": {
    "cube_33": "https://cdn.posecraft.example/luts/jp-fresh-33.cube",
    "hald_8": "https://cdn.posecraft.example/luts/jp-fresh-hald-8.png"
  },

  "adjustments": {
    "exposure": 0.15,
    "contrast": -8,
    "highlights": -15,
    "shadows": 10,
    "whites": -5,
    "blacks": 5,
    "saturation": -12,
    "vibrance": -5,
    "temperature": -300,
    "tint": 5,
    "sharpness": 0,
    "noise_reduction": 0,
    "vignette": -8,
    "grain": 3
  },

  "best_for": {
    "scene_types": ["outdoor-nature", "garden", "beach"],
    "lighting": ["front-light", "overcast", "soft-light"],
    "skin_tones": ["fair", "light", "medium"],
    "styles": ["fresh", "sweet", "natural"]
  },

  "preview_image": "https://cdn.posecraft.example/previews/jp-fresh-before-after.jpg",

  "metadata": {
    "author": "posecraft_team",
    "created_at": "2026-05-25T00:00:00Z",
    "usage_count": 0,
    "avg_rating": 0,
    "is_premium": false,
    "price": null
  }
}
```

---

## 四、成片分析→预设匹配管线

### 4.1 端到端流程

```
用户拍完照片
     │
     ▼
┌─────────────────────────────┐
│ 端侧: 图像特征提取           │
│ - 亮度直方图 (256 bins)      │
│ - 色彩分布 (HSV histogram)  │
│ - 饱和度均值/方差           │
│ - 对比度 (RMS contrast)     │
│ - 肤色区域提取 + 肤色类型    │
│ - 场景标签 (复用拍前分析结果) │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ 云端: 美学分析 (Qwen-VL)     │
│ "这张照片的调性是什么？       │
│  冷暖调？高低饱和度？         │
│  明暗调？是否有明显偏色？     │
│  人物肤色呈现如何？"          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ 云端: 预设匹配 (DeepSeek)    │
│ 输入: 场景标签 + 图像特征     │
│       + 美学分析 + 用户偏好   │
│ 输出: Top 3 预设 + 匹配理由   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ 端侧: LUT 实时预览           │
│ - 下载 Top 3 预设的 Hald LUT │
│ - 对缩略图应用 LUT (GPU shader)│
│ - 用户左右滑动对比效果        │
│ - 选中后应用到原图+保存       │
└─────────────────────────────┘
```

### 4.2 预设匹配策略

```python
# 伪代码: 预设推荐排序

def rank_presets(photo_features, scene_labels, user_profile):
    scores = {}

    for preset in preset_db:
        score = 0.0

        # 1. 场景匹配度 (40%权重)
        if scene_labels["type"] in preset.best_for.scene_types:
            score += 0.40
        elif any(s in preset.best_for.scene_types for s in scene_labels["tags"]):
            score += 0.25

        # 2. 图像特征匹配度 (30%)
        score += 0.30 * feature_similarity(photo_features, preset.expected_features)

        # 3. 用户风格偏好 (20%)
        if preset.style_tags & user_profile.preferred_styles:
            score += 0.20

        # 4. 用户历史 (10%)
        if preset.id in user_profile.saved_presets:
            score += 0.10
        if preset.id in user_profile.skipped_presets:
            score -= 0.15

        # 5. 多样性惩罚 (保证 Top 3 不全是同类)
        scores[preset.id] = score

    # MMR (Maximal Marginal Relevance) 重排
    return mmr_rerank(scores, diversity_lambda=0.3)[:3]
```

---

## 五、端侧 LUT 应用方案

### 5.1 GPU Shader 实现 (OpenGL ES / Vulkan)

```
渲染管线:
1. 输入: 原始照片纹理 + Hald CLUT 纹理 (8³=512采样)
2. Fragment Shader:
   - 对于每个像素，查表 Hald CLUT
   - 输入: RGB 颜色 → 映射到 Hald 纹理坐标
   - 输出: LUT 调整后的 RGB
3. 三线性插值（8³精度下需要插值）

性能:
- 全分辨率预览: <5ms (GPU)
- 1080p 照片应用: <20ms
- 支持实时切换预设
```

### 5.2 Modes of Use

| 场景 | 方式 | 说明 |
|------|------|------|
| 拍后浏览 | 左右滑动切换预设 | 即时切换对比，< 50ms 延迟 |
| 详细编辑 | 参数滑块微调 | 曝光/对比/饱和/色温 ± 手动调整 |
| 批量应用 | 选取主照片→风格→同组套用 | 统一一组照片的色调 |
| 原图对比 | 长按预览区域 | 切换到原图，松手回去 |

---

## 六、预设市场设计（Phase 3）

### 6.1 市场模型

```
创作者
  │
  ├── 上传预设包 (.cube + JSON 元数据)
  ├── 上传 Before/After 示例图
  ├── 定价（免费 / ¥1-50 / 订阅包含）
  └── 获得: 70% 收入分成
       │
       ▼
  审核流程 (AI NSFW + 人工)
       │
       ▼
  市场上架
       │
       ▼
  用户购买/下载
       │
       ▼
  平台统计: 使用次数 / 评分 / 留存影响
```

### 6.2 预设质量评分

| 指标 | 权重 | 说明 |
|------|------|------|
| 用户评分 | 30% | 1-5星 |
| 使用次数 | 25% | 购买后实际使用的比例 |
| 留存率 | 20% | 使用该预设后7天内有重复使用 |
| 分享率 | 15% | 用该预设修图后分享到社区 |
| 多样场景适配 | 10% | 在不同场景下的表现一致性 |

---

## 七、与第三方工具对接方案

### 7.1 导出兼容性

| 工具 | 导出格式 | 方式 |
|------|----------|------|
| Lightroom Mobile | `.dng` + `.xmp` (预设数据嵌入) | 分享到 LR |
| VSCO | 引导用户到 VSCO，不直接导出 | 跳转链接 |
| 醒图 | 跳转链接 | — |
| 剪映/CapCut | `.cube` LUT 文件 | 直接导入 |

### 7.2 导入兼容性

| 来源 | 导入格式 | 方式 |
|------|----------|------|
| Lightroom Preset (`.xmp`) | 解析 XMP → 转换 | 解析色调曲线 |
| `.cube` LUT | 直接使用 | — |
| `.png` Hald CLUT | 直接使用 | — |
| 参考照片 | Qwen-VL 色调分析 → 近似预设生成 | AI 仿色 |

---

## 八、Phase 1 交付清单

| 交付物 | 数量 | 说明 |
|--------|------|------|
| 基础预设（LUT + 元数据） | 10 个 | 每个含 .cube 33³ + Hald .png + 元数据 JSON |
| 端侧预设预览引擎 | — | GPU Shader LUT 应用 + 实时切换 |
| 成片特征提取 | — | 亮度/色彩/肤色/对比度 4 维特征向量 |
| 云端预设匹配 API | 1 个 | 特征 → Top 3 预设推荐 |
| 预设参数微调 UI | — | 曝光/对比/饱和/色温 手动调整滑块 |
