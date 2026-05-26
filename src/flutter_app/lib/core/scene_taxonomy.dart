/// Scene taxonomy — 120+ fine-grained photography scenes.
///
/// Each scene maps to one of the 6 internal pose-DB keys (outdoor, street,
/// indoor, beach, night, mountain) used by the recommendation engine.
/// The fine-grained label is displayed to the user; the internal key is
/// used for pose matching.
///
/// Scenes are organized hierarchically: category → subcategory → scene.

/// A single fine-grained scene definition.
class SceneDef {
  /// Unique scene ID (e.g. "garden-cherry-blossom-spring")
  final String id;

  /// Human-readable Chinese label
  final String label;

  /// Internal pose-DB key for recommendation matching
  final String poseDbKey;

  /// Parent category for UI grouping
  final String category;

  /// Typical time-of-day associations (empty = any)
  final List<String> timeOfDay;

  /// TFLite class this scene falls under (for classifier mapping)
  final String tfliteClass;

  /// Months when this scene is most likely (1-12, empty = any)
  final List<int> peakMonths;

  /// Whether this is an outdoor scene
  final bool isOutdoor;

  const SceneDef({
    required this.id,
    required this.label,
    required this.poseDbKey,
    required this.category,
    this.timeOfDay = const [],
    this.tfliteClass = 'outdoor-nature',
    this.peakMonths = const [],
    this.isOutdoor = true,
  });
}

/// Complete taxonomy of 120+ photography scenes.
class SceneTaxonomy {
  SceneTaxonomy._();

  /// All defined scenes.
  static const List<SceneDef> all = [
    // ═══════════════════════════════════════════════════════════
    // 户外自然 — Outdoor Nature (30+ scenes)
    // ═══════════════════════════════════════════════════════════

    // ── 花园/公园 ──
    SceneDef(id: 'garden-flower', label: '花园花海', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [4, 5, 6]),
    SceneDef(id: 'garden-cherry-blossom', label: '樱花树下', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [3, 4]),
    SceneDef(id: 'garden-rose', label: '玫瑰园', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [5, 6]),
    SceneDef(id: 'garden-lavender', label: '薰衣草田', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [6, 7, 8]),
    SceneDef(id: 'garden-botanical', label: '植物园', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park'),
    SceneDef(id: 'garden-park-bench', label: '公园长椅', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park'),
    SceneDef(id: 'garden-lawn', label: '草地野餐', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [4, 5, 9, 10]),
    SceneDef(id: 'garden-greenhouse', label: '温室花房', poseDbKey: 'indoor', category: '户外自然', tfliteClass: 'garden-park'),

    // ── 森林/树林 ──
    SceneDef(id: 'forest-deep', label: '密林深处', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'forest'),
    SceneDef(id: 'forest-bamboo', label: '竹林', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'forest'),
    SceneDef(id: 'forest-pine', label: '松树林', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'forest'),
    SceneDef(id: 'forest-autumn', label: '秋色枫林', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'forest', peakMonths: [10, 11]),
    SceneDef(id: 'forest-path', label: '林间小路', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'forest'),
    SceneDef(id: 'forest-ginkgo', label: '银杏大道', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'forest', peakMonths: [10, 11]),

    // ── 山地 ──
    SceneDef(id: 'mountain-peak', label: '山顶远眺', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'mountain'),
    SceneDef(id: 'mountain-grassland', label: '高山草甸', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'mountain', peakMonths: [6, 7, 8]),
    SceneDef(id: 'mountain-cliff', label: '悬崖观景台', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'mountain'),
    SceneDef(id: 'mountain-snow', label: '雪山', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'snow', peakMonths: [12, 1, 2]),
    SceneDef(id: 'mountain-sunrise', label: '山顶日出', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'sunset-sunrise', timeOfDay: ['dawn']),

    // ── 水边 ──
    SceneDef(id: 'lake-still', label: '平静湖面', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river'),
    SceneDef(id: 'lake-boat', label: '湖边小船', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river'),
    SceneDef(id: 'lake-dock', label: '湖中栈道', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river'),
    SceneDef(id: 'river-bridge', label: '河畔小桥', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river'),
    SceneDef(id: 'river-rock', label: '溪流石涧', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river'),
    SceneDef(id: 'waterfall', label: '瀑布', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river'),
    SceneDef(id: 'wetland-reed', label: '芦苇荡', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'lake-river', peakMonths: [9, 10, 11]),

    // ── 田野/乡村 ──
    SceneDef(id: 'field-rapeseed', label: '油菜花田', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [3, 4]),
    SceneDef(id: 'field-wheat', label: '金色麦田', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [5, 6, 9, 10]),
    SceneDef(id: 'field-sunflower', label: '向日葵田', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [7, 8]),
    SceneDef(id: 'field-tea', label: '茶园梯田', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park'),
    SceneDef(id: 'field-lavender', label: '薰衣草庄园', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park', peakMonths: [6, 7]),
    SceneDef(id: 'village-ancient', label: '古村落', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'garden-park'),

    // ── 沙漠/戈壁 ──
    SceneDef(id: 'desert-dune', label: '沙漠沙丘', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'outdoor-nature'),
    SceneDef(id: 'gobi-highway', label: '戈壁公路', poseDbKey: 'outdoor', category: '户外自然', tfliteClass: 'outdoor-nature'),

    // ═══════════════════════════════════════════════════════════
    // 城市街拍 — Urban Street (25+ scenes)
    // ═══════════════════════════════════════════════════════════

    // ── 街道/建筑 ──
    SceneDef(id: 'street-fashion', label: '时尚街区', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-old-town', label: '老城古街', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-alley', label: '文艺小巷', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-boulevard', label: '林荫大道', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-graffiti', label: '涂鸦墙前', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-stairs', label: '城市阶梯', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-bridge', label: '天桥', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'street-square', label: '城市广场', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),

    // ── 建筑/地标 ──
    SceneDef(id: 'arch-modern', label: '现代建筑', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'arch-historic', label: '历史建筑', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'arch-temple', label: '寺庙古刹', poseDbKey: 'outdoor', category: '城市街拍', tfliteClass: 'garden-park'),
    SceneDef(id: 'arch-church', label: '教堂', poseDbKey: 'indoor', category: '城市街拍', tfliteClass: 'indoor'),
    SceneDef(id: 'arch-campus', label: '大学校园', poseDbKey: 'outdoor', category: '城市街拍', tfliteClass: 'garden-park'),
    SceneDef(id: 'arch-skyline', label: '城市天际线', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),
    SceneDef(id: 'arch-rooftop', label: '天台/屋顶', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),

    // ── 交通/出行 ──
    SceneDef(id: 'transit-subway', label: '地铁站', poseDbKey: 'indoor', category: '城市街拍', tfliteClass: 'indoor'),
    SceneDef(id: 'transit-train', label: '火车站', poseDbKey: 'indoor', category: '城市街拍', tfliteClass: 'indoor'),
    SceneDef(id: 'transit-airport', label: '机场', poseDbKey: 'indoor', category: '城市街拍', tfliteClass: 'indoor'),
    SceneDef(id: 'transit-bike', label: '单车骑行', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'urban-street'),

    // ── 市场/商业 ──
    SceneDef(id: 'market-bazaar', label: '市集/菜市场', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'market-bazaar'),
    SceneDef(id: 'market-night', label: '夜市', poseDbKey: 'night', category: '城市街拍', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'market-flower', label: '花市', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'market-bazaar'),
    SceneDef(id: 'market-antique', label: '古玩市场', poseDbKey: 'street', category: '城市街拍', tfliteClass: 'market-bazaar'),
    SceneDef(id: 'shopping-mall', label: '购物中心', poseDbKey: 'indoor', category: '城市街拍', tfliteClass: 'indoor'),

    // ═══════════════════════════════════════════════════════════
    // 室内空间 — Indoor (20+ scenes)
    // ═══════════════════════════════════════════════════════════

    SceneDef(id: 'indoor-cozy', label: '温馨客厅', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor-home'),
    SceneDef(id: 'indoor-bedroom', label: '舒适卧室', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor-home'),
    SceneDef(id: 'indoor-kitchen', label: '厨房', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor-home'),
    SceneDef(id: 'indoor-bathroom', label: '浴室/镜前', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor-home'),
    SceneDef(id: 'indoor-window', label: '窗边光影', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor-home'),
    SceneDef(id: 'indoor-staircase', label: '室内楼梯', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-corridor', label: '走廊/过道', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-hotel', label: '酒店房间', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-cafe', label: '咖啡馆', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor-cafe'),
    SceneDef(id: 'indoor-restaurant', label: '餐厅', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'restaurant'),
    SceneDef(id: 'indoor-bar', label: '酒吧', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-library', label: '图书馆', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'library'),
    SceneDef(id: 'indoor-bookstore', label: '书店', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'library'),
    SceneDef(id: 'indoor-museum', label: '博物馆/美术馆', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-gym', label: '健身房', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'gym-fitness'),
    SceneDef(id: 'indoor-yoga', label: '瑜伽室', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'gym-fitness'),
    SceneDef(id: 'indoor-dance', label: '舞蹈室', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'gym-fitness'),
    SceneDef(id: 'indoor-studio', label: '摄影棚', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-office', label: '办公室', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),
    SceneDef(id: 'indoor-classroom', label: '教室', poseDbKey: 'indoor', category: '室内空间', tfliteClass: 'indoor'),

    // ═══════════════════════════════════════════════════════════
    // 海滩/水边 — Beach & Water (12 scenes)
    // ═══════════════════════════════════════════════════════════

    SceneDef(id: 'beach-sand', label: '沙滩', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-sunset', label: '海滩日落', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'sunset-sunrise', timeOfDay: ['golden-hour', 'dusk']),
    SceneDef(id: 'beach-sunrise', label: '海滩日出', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'sunset-sunrise', timeOfDay: ['dawn']),
    SceneDef(id: 'beach-rock', label: '礁石海岸', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-pool', label: '泳池边', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-pier', label: '栈桥/码头', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-lighthouse', label: '灯塔', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-boardwalk', label: '海滨步道', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-palm', label: '椰林海岸', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-surf', label: '冲浪海滩', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'beach-cliff', label: '海边悬崖', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),
    SceneDef(id: 'boat-deck', label: '游艇甲板', poseDbKey: 'beach', category: '海滩水边', tfliteClass: 'beach'),

    // ═══════════════════════════════════════════════════════════
    // 夜景/暗光 — Night Scenes (15 scenes)
    // ═══════════════════════════════════════════════════════════

    SceneDef(id: 'night-city', label: '城市夜景', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-neon', label: '霓虹灯街', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'neon-light', timeOfDay: ['night']),
    SceneDef(id: 'night-bridge', label: '夜景桥梁', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-market', label: '夜市排档', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-ferris-wheel', label: '摩天轮夜景', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-fireworks', label: '烟花', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-sparkler', label: '仙女棒/光绘', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-car-trail', label: '车流光轨', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-candle', label: '烛光', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'indoor', timeOfDay: ['night']),
    SceneDef(id: 'night-campfire', label: '篝火', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-rooftop', label: '天台夜景', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-rain', label: '雨夜街景', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'rainy-street', timeOfDay: ['night']),
    SceneDef(id: 'night-concert', label: '演唱会', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-lantern', label: '灯笼/灯会', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['night']),
    SceneDef(id: 'night-blue-hour', label: '蓝调时刻', poseDbKey: 'night', category: '夜景暗光', tfliteClass: 'night-scene', timeOfDay: ['dusk']),

    // ═══════════════════════════════════════════════════════════
    // 天气/季节特色 — Weather & Seasonal (12 scenes)
    // ═══════════════════════════════════════════════════════════

    SceneDef(id: 'weather-snow', label: '雪景', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'snow', peakMonths: [12, 1, 2]),
    SceneDef(id: 'weather-snow-night', label: '雪夜', poseDbKey: 'night', category: '天气季节', tfliteClass: 'snow', timeOfDay: ['night'], peakMonths: [12, 1, 2]),
    SceneDef(id: 'weather-rain', label: '雨街', poseDbKey: 'street', category: '天气季节', tfliteClass: 'rainy-street'),
    SceneDef(id: 'weather-rain-reflection', label: '雨后倒影', poseDbKey: 'street', category: '天气季节', tfliteClass: 'rainy-street'),
    SceneDef(id: 'weather-fog', label: '雾天', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'outdoor-nature'),
    SceneDef(id: 'weather-cloud-sea', label: '云海', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'mountain'),
    SceneDef(id: 'weather-rainbow', label: '彩虹', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'outdoor-nature'),
    SceneDef(id: 'season-autumn-leaves', label: '秋叶', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'forest', peakMonths: [10, 11]),
    SceneDef(id: 'season-spring-blossom', label: '春花', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'garden-park', peakMonths: [3, 4]),
    SceneDef(id: 'season-summer-green', label: '夏日绿荫', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'forest', peakMonths: [6, 7, 8]),
    SceneDef(id: 'season-winter-bare', label: '冬日枯枝', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'outdoor-nature', peakMonths: [12, 1, 2]),
    SceneDef(id: 'sunset-golden', label: '金色夕阳', poseDbKey: 'outdoor', category: '天气季节', tfliteClass: 'sunset-sunrise', timeOfDay: ['golden-hour']),

    // ═══════════════════════════════════════════════════════════
    // 特色场所 — Special Venues (10 scenes)
    // ═══════════════════════════════════════════════════════════

    SceneDef(id: 'venue-amusement', label: '游乐园', poseDbKey: 'outdoor', category: '特色场所', tfliteClass: 'garden-park'),
    SceneDef(id: 'venue-zoo', label: '动物园', poseDbKey: 'outdoor', category: '特色场所', tfliteClass: 'garden-park'),
    SceneDef(id: 'venue-aquarium', label: '水族馆', poseDbKey: 'indoor', category: '特色场所', tfliteClass: 'indoor'),
    SceneDef(id: 'venue-stadium', label: '体育场', poseDbKey: 'outdoor', category: '特色场所', tfliteClass: 'stadium'),
    SceneDef(id: 'venue-theater', label: '剧院', poseDbKey: 'indoor', category: '特色场所', tfliteClass: 'indoor'),
    SceneDef(id: 'venue-cinema', label: '电影院', poseDbKey: 'indoor', category: '特色场所', tfliteClass: 'indoor'),
    SceneDef(id: 'venue-exhibition', label: '展览/漫展', poseDbKey: 'indoor', category: '特色场所', tfliteClass: 'indoor'),
    SceneDef(id: 'venue-wedding', label: '婚礼现场', poseDbKey: 'indoor', category: '特色场所', tfliteClass: 'indoor'),
    SceneDef(id: 'venue-party', label: '派对/聚会', poseDbKey: 'indoor', category: '特色场所', tfliteClass: 'indoor'),
    SceneDef(id: 'venue-onsen', label: '温泉', poseDbKey: 'outdoor', category: '特色场所', tfliteClass: 'outdoor-nature'),
  ];

  /// Lookup a SceneDef by ID.
  static SceneDef? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Lookup SceneDefs by TFLite class label.
  static List<SceneDef> byTFLiteClass(String tfliteClass) {
    return all.where((s) => s.tfliteClass == tfliteClass).toList();
  }

  /// Lookup SceneDefs by internal pose-DB key.
  static List<SceneDef> byPoseDbKey(String key) {
    return all.where((s) => s.poseDbKey == key).toList();
  }

  /// Find the best-matching SceneDef given context signals.
  ///
  /// [tfliteClass] — the TFLite top-1 prediction.
  /// [timeOfDay] — current time-of-day classification.
  /// [month] — current month (1-12).
  /// [locationHint] — optional GPS-derived hint ('coastal', 'mountain', 'urban').
  static SceneDef match({
    required String tfliteClass,
    required String timeOfDay,
    required int month,
    String? locationHint,
  }) {
    // Collect candidates matching the TFLite class
    var candidates = byTFLiteClass(tfliteClass);
    if (candidates.isEmpty) candidates = all;

    // Score each candidate
    (SceneDef, double)? best;
    for (final c in candidates) {
      double score = 0;

      // Time-of-day match
      if (c.timeOfDay.isEmpty) {
        score += 1;
      } else if (c.timeOfDay.contains(timeOfDay)) {
        score += 20;
      }

      // Month/season match
      if (c.peakMonths.isEmpty) {
        score += 1;
      } else if (c.peakMonths.contains(month)) {
        score += 15;
      }

      // Location hint
      if (locationHint == 'coastal' && c.poseDbKey == 'beach') score += 10;
      if (locationHint == 'mountain' && c.id.startsWith('mountain')) score += 10;
      if (locationHint == 'urban' && (c.poseDbKey == 'street' || c.poseDbKey == 'indoor')) score += 5;

      if (best == null || score > best.$2) {
        best = (c, score);
      }
    }

    // Return best match, or fallback
    if (best != null) return best.$1;

    // Ultimate fallback
    return const SceneDef(
      id: 'outdoor-general',
      label: '户外',
      poseDbKey: 'outdoor',
      category: '户外自然',
    );
  }

  /// Total number of scenes in the taxonomy.
  static int get count => all.length;
}
