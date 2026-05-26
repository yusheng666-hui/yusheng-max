/// Wardrobe and prop recommendation engine.
///
/// Maps scene context (colors, style, weather) to clothing suggestions,
/// color palette recommendations using color harmony rules, and
/// scene-appropriate props with usage tips.

/// A single color suggestion with hex value and reasoning.
class ColorSuggestion {
  final String name;
  final int hexColor;
  final String reason;

  const ColorSuggestion({
    required this.name,
    required this.hexColor,
    required this.reason,
  });

  String toHexString() => '#${hexColor.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Wardrobe recommendation for the current scene + pose.
class WardrobeRecommendation {
  final List<ColorSuggestion> suggestedColors;
  final List<String> styleTags;
  final List<String> clothingItems;
  final List<String> avoidItems;
  final String seasonTip;
  final String pairingTip;

  const WardrobeRecommendation({
    required this.suggestedColors,
    required this.styleTags,
    required this.clothingItems,
    required this.avoidItems,
    required this.seasonTip,
    required this.pairingTip,
  });
}

/// A prop recommendation with name and usage guidance.
class PropRecommendation {
  final String name;
  final String icon;
  final String usageTip;
  final List<String> compatiblePoses;

  const PropRecommendation({
    required this.name,
    required this.icon,
    required this.usageTip,
    required this.compatiblePoses,
  });
}

/// Combined styling recommendation for a scene.
class StylingRecommendation {
  final WardrobeRecommendation wardrobe;
  final List<PropRecommendation> props;

  const StylingRecommendation({
    required this.wardrobe,
    required this.props,
  });
}

/// Color harmony rulebook — maps dominant scene color → complementary clothing colors.
class StylingService {
  // ── Color palette database ──

  static const _sceneColors = <String, List<_NamedColor>>{
    'blue': [      // sky, ocean
      _NamedColor('珊瑚橙', 0xFF6B5B),
      _NamedColor('暖黄色', 0xFFF4A460),
      _NamedColor('白色', 0xFFFFFF),
      _NamedColor('浅粉', 0xFFD4A0A0),
    ],
    'green': [     // forest, grass, park
      _NamedColor('白色', 0xFFFFFF),
      _NamedColor('米色', 0xFFF5E6D3),
      _NamedColor('浅粉', 0xFFD4A0A0),
      _NamedColor('牛仔蓝', 0xFF5B7DB1),
    ],
    'sand': [      // beach
      _NamedColor('白色', 0xFFFFFF),
      _NamedColor('天空蓝', 0xFF87CEEB),
      _NamedColor('珊瑚粉', 0xFFF4845F),
      _NamedColor('亮红', 0xFFC41E3A),
    ],
    'gray': [      // urban, street
      _NamedColor('亮红', 0xFFC41E3A),
      _NamedColor('明黄', 0xFFFFD700),
      _NamedColor('白色', 0xFFFFFF),
      _NamedColor('电光蓝', 0xFF0077B6),
    ],
    'warm-yellow': [ // indoor warm light
      _NamedColor('深绿', 0xFF2D6A4F),
      _NamedColor('海军蓝', 0xFF1B4965),
      _NamedColor('白色', 0xFFFFFF),
      _NamedColor('酒红', 0xFF6B2737),
    ],
    'black': [     // night
      _NamedColor('亮色系', 0xFFFFD700),
      _NamedColor('霓虹粉', 0xFFFF6B6B),
      _NamedColor('银白', 0xFFC0C0C0),
      _NamedColor('电光蓝', 0xFF0077B6),
    ],
    'white': [     // snow, bright backgrounds
      _NamedColor('正红色', 0xFFC41E3A),
      _NamedColor('明黄色', 0xFFFFD700),
      _NamedColor('宝蓝色', 0xFF1E3A5F),
      _NamedColor('亮橙色', 0xFFFF6B35),
    ],
  };

  // ── Scene → style mapping ──

  static const _sceneStyles = <String, List<String>>{
    'beach':       ['休闲', '波西米亚', '飘逸', '度假风'],
    'outdoor':     ['自然', '清新', '田园', '浪漫'],
    'street':      ['酷飒', '街头', '简约', '复古'],
    'indoor':      ['优雅', '知性', '慵懒', '温柔'],
    'night':       ['华丽', '性感', '摩登', '暗黑'],
  };

  // ── Scene → clothing items ──

  static const _sceneClothing = <String, _ClothingAdvice>{
    'beach': _ClothingAdvice(
      recommend: ['长裙', '阔腿裤', '草帽', '墨镜', '丝巾', '比基尼外搭'],
      avoid: ['细高跟鞋', '厚重外套', '深色正装'],
    ),
    'outdoor': _ClothingAdvice(
      recommend: ['连衣裙', '衬衫', '牛仔裤', '帆布鞋', '草帽', '轻便外套'],
      avoid: ['超短裙', '细高跟', '过于正式'],
    ),
    'street': _ClothingAdvice(
      recommend: ['西装外套', '阔腿裤', '马丁靴', '贝雷帽', '金属配饰', '墨镜'],
      avoid: ['运动套装', '过于休闲', '拖鞋'],
    ),
    'indoor': _ClothingAdvice(
      recommend: ['针织衫', '半身裙', '衬衫', '小皮鞋', '简约首饰', '贝雷帽'],
      avoid: ['厚重羽绒服', '滑雪镜', '过于户外'],
    ),
    'night': _ClothingAdvice(
      recommend: ['修身裙', '皮衣', '高跟靴', '亮片配饰', '深色大衣', '锁骨链'],
      avoid: ['运动鞋', '卡通印花', '过于幼稚'],
    ),
  };

  // ── Scene → props ──

  static const _sceneProps = <String, List<PropRecommendation>>{
    'beach': [
      PropRecommendation(name: '草帽', icon: '👒', usageTip: '手持草帽自然垂放身侧，或戴在头上微微低头', compatiblePoses: ['站姿', '坐姿', '回眸']),
      PropRecommendation(name: '墨镜', icon: '🕶️', usageTip: '戴上墨镜看远方，或拿在手里搭在额头上方', compatiblePoses: ['站姿', '半身']),
      PropRecommendation(name: '纱巾', icon: '🧣', usageTip: '让纱巾迎风飘起，抓拍动态瞬间', compatiblePoses: ['动态', '回眸', '奔跑']),
      PropRecommendation(name: '冲浪板', icon: '🏄', usageTip: '抱着冲浪板走向海边，或立在身旁', compatiblePoses: ['站姿', '行走']),
      PropRecommendation(name: '贝壳', icon: '🐚', usageTip: '蹲下捡贝壳，或放在掌心低头看', compatiblePoses: ['蹲姿', '坐姿', '特写']),
    ],
    'outdoor': [
      PropRecommendation(name: '花束', icon: '💐', usageTip: '手持花束微低头闻花，眼神温柔', compatiblePoses: ['站姿', '坐姿', '半身']),
      PropRecommendation(name: '气球', icon: '🎈', usageTip: '手持气球线，仰头看气球或回头微笑', compatiblePoses: ['站姿', '回眸', '仰头']),
      PropRecommendation(name: '草帽', icon: '👒', usageTip: '手扶帽檐微微低头，或拿在手里转圈', compatiblePoses: ['站姿', '坐姿', '动态']),
      PropRecommendation(name: '泡泡机', icon: '🫧', usageTip: '吹泡泡或挥舞泡泡棒，抓拍开心表情', compatiblePoses: ['动态', '表情', '站姿']),
      PropRecommendation(name: '野餐篮', icon: '🧺', usageTip: '坐在野餐垫上，篮子放在身旁', compatiblePoses: ['坐姿', '躺姿']),
    ],
    'street': [
      PropRecommendation(name: '咖啡杯', icon: '☕', usageTip: '手持咖啡杯自然垂放，或举杯假装喝', compatiblePoses: ['站姿', '行走', '坐姿']),
      PropRecommendation(name: '墨镜', icon: '🕶️', usageTip: '墨镜搭在鼻梁上眼神透过镜框看镜头', compatiblePoses: ['半身', '表情']),
      PropRecommendation(name: '报纸/杂志', icon: '📰', usageTip: '手拿报纸假装阅读，眼神看向镜头', compatiblePoses: ['坐姿', '站姿']),
      PropRecommendation(name: '耳机', icon: '🎧', usageTip: '戴上耳机侧头看远方，营造氛围感', compatiblePoses: ['站姿', '侧脸', '半身']),
      PropRecommendation(name: '透明伞', icon: '🌂', usageTip: '透明伞搭在肩上，回眸看向镜头', compatiblePoses: ['回眸', '站姿']),
      PropRecommendation(name: '自行车', icon: '🚲', usageTip: '扶着自行车把手，或坐在车上单脚着地', compatiblePoses: ['站姿', '坐姿']),
    ],
    'indoor': [
      PropRecommendation(name: '书本', icon: '📖', usageTip: '假装翻书页，眼神看向窗外或镜头', compatiblePoses: ['坐姿', '半身', '侧脸']),
      PropRecommendation(name: '花束', icon: '💐', usageTip: '手持小花束放在胸前，微微低头', compatiblePoses: ['站姿', '半身', '特写']),
      PropRecommendation(name: '蛋糕/甜点', icon: '🍰', usageTip: '用叉子假装吃甜点，眼神看食物', compatiblePoses: ['坐姿', '特写']),
      PropRecommendation(name: '电脑', icon: '💻', usageTip: '假装打字，或用电脑挡住半张脸', compatiblePoses: ['坐姿', '半身']),
      PropRecommendation(name: '抱枕', icon: '🛋️', usageTip: '抱着抱枕窝在沙发里，放松自然', compatiblePoses: ['坐姿', '躺姿']),
    ],
    'night': [
      PropRecommendation(name: '仙女棒', icon: '✨', usageTip: '点燃仙女棒画光轨，建议慢门2s拍摄', compatiblePoses: ['站姿', '动态', '特写']),
      PropRecommendation(name: '灯笼', icon: '🏮', usageTip: '手持灯笼照亮下半张脸，氛围感满分', compatiblePoses: ['站姿', '半身', '侧脸']),
      PropRecommendation(name: '透明伞', icon: '🌂', usageTip: '透明伞+霓虹灯倒影，雨天夜景绝配', compatiblePoses: ['站姿', '回眸']),
      PropRecommendation(name: '霓虹灯牌', icon: '💡', usageTip: '站在霓虹灯旁，让彩色光打在脸上', compatiblePoses: ['站姿', '半身', '侧脸']),
    ],
    'snow': [
      PropRecommendation(name: '彩色围巾', icon: '🧣', usageTip: '亮色围巾（红/黄）与白雪形成强烈对比', compatiblePoses: ['站姿', '回眸', '半身']),
      PropRecommendation(name: '热饮杯', icon: '☕', usageTip: '双手捧热饮杯呵气，冬日温暖感', compatiblePoses: ['站姿', '特写', '半身']),
    ],
  };

  // ── Season-aware tips ──

  static const _seasonTips = <int, String>{
    3: '春季早晚温差大，建议叠穿法：薄外套+连衣裙，方便随时调整',
    4: '春季早晚温差大，建议叠穿法：薄外套+连衣裙，方便随时调整',
    5: '初夏阳光好，浅色系+轻薄面料最上镜',
    6: '盛夏注意防晒，浅色+透气面料，避免深色吸热',
    7: '盛夏注意防晒，浅色+透气面料，避免深色吸热',
    8: '盛夏注意防晒，浅色+透气面料，避免深色吸热',
    9: '初秋是最佳拍照季节，暖色系+叠穿层次感',
    10:'秋季金黄光影美，暖色调（焦糖/卡其/砖红）+围巾',
    11:'秋季金黄光影美，暖色调（焦糖/卡其/砖红）+围巾',
    12:'冬季户外拍照注意保暖+时髦兼顾，亮色外套在灰暗背景中更出挑',
    1: '冬季户外拍照注意保暖+时髦兼顾，亮色外套在灰暗背景中更出挑',
    2: '冬季户外拍照注意保暖+时髦兼顾，亮色外套在灰暗背景中更出挑',
  };

  // ── Scene class → internal key mapping ──

  static const _sceneKeyMap = <String, String>{
    'outdoor-nature': 'outdoor',
    'outdoor': 'outdoor',
    'urban-street': 'street',
    'street': 'street',
    'urban': 'street',
    'indoor': 'indoor',
    'indoor-cafe': 'indoor',
    'indoor-home': 'indoor',
    'beach': 'beach',
    'beach-coast': 'beach',
    'night-scene': 'night',
    'night': 'night',
    'night-neon': 'night',
  };

  /// Scene type → dominant color category for palette lookup.
  static const _sceneColorKey = <String, String>{
    'beach': 'sand',
    'outdoor': 'green',
    'street': 'gray',
    'indoor': 'warm-yellow',
    'night': 'black',
    'snow': 'white',
  };

  // ── Public API ──

  /// Generate full styling recommendation for a scene.
  StylingRecommendation recommend({
    required String sceneClass,
    required String timeOfDay,
    int month = 6,
  }) {
    final sceneKey = _sceneKeyMap[sceneClass] ?? 'outdoor';
    final wardrobe = _recommendWardrobe(sceneKey, timeOfDay, month);
    final props = _recommendProps(sceneKey);

    return StylingRecommendation(
      wardrobe: wardrobe,
      props: props,
    );
  }

  WardrobeRecommendation _recommendWardrobe(
    String sceneKey,
    String timeOfDay,
    int month,
  ) {
    // Pick color category from scene type (not from palette order, which is unreliable)
    final colorKey = _sceneColorKey[sceneKey] ?? 'green';
    final colorSuggestions = _sceneColors[colorKey]?.map((c) {
      return ColorSuggestion(
        name: c.name,
        hexColor: c.hex,
        reason: _colorReason(colorKey, c.name),
      );
    }).toList() ?? _defaultColorSuggestions();

    // Style tags from scene
    final styles = _sceneStyles[sceneKey] ?? ['自然', '简约'];

    // Clothing items
    final clothing = _sceneClothing[sceneKey];
    final recommend = clothing?.recommend ?? ['连衣裙', '衬衫', '休闲鞋'];
    final avoid = clothing?.avoid ?? [];

    // Season tip
    final seasonTip = _seasonTips[month] ?? '根据天气选择合适的厚度和面料';

    // Pairing tip based on scene
    final pairingTip = _pairingTip(sceneKey, timeOfDay);

    return WardrobeRecommendation(
      suggestedColors: colorSuggestions,
      styleTags: styles,
      clothingItems: recommend,
      avoidItems: avoid,
      seasonTip: seasonTip,
      pairingTip: pairingTip,
    );
  }

  List<PropRecommendation> _recommendProps(String sceneKey) {
    final props = _sceneProps[sceneKey] ?? _sceneProps['outdoor'] ?? [];
    return props.take(4).toList();
  }

  // ── Helpers ──

  String _colorReason(String scene, String clothingColor) {
    const reasons = {
      'blue-珊瑚橙': '珊瑚橙与蓝天形成互补色，人物瞬间从背景中跳出来',
      'blue-暖黄色': '暖黄与蓝天冷暖对比，温暖又吸睛',
      'blue-白色': '白色与蓝天是最干净的搭配，清新自然',
      'blue-浅粉': '浅粉+蓝天=温柔甜美风，适合日系清新',
      'green-白色': '白色在绿色背景中最纯净，反光板效果自带补光',
      'green-米色': '米色与绿色同属大地色系，和谐高级',
      'green-浅粉': '浅粉+绿植=浪漫花园感',
      'green-牛仔蓝': '牛仔蓝与绿色邻近色搭配，休闲自然',
      'sand-白色': '白色+沙滩=经典海边搭配，清爽干净',
      'sand-天空蓝': '蓝色与沙色冷暖对比，海边氛围拉满',
      'sand-珊瑚粉': '珊瑚粉与沙滩同色系，温柔高级感',
      'sand-亮红': '红色在沙滩/海水背景中极其出挑，气场全开',
      'gray-亮红': '红色打破灰色沉闷，街拍经典配色',
      'gray-明黄': '黄色点亮灰色背景，活力满满',
      'gray-白色': '白色在灰色城市背景中干净利落',
      'gray-电光蓝': '电光蓝+灰色=高冷都市风',
      'warm-yellow-深绿': '深绿在暖光下沉稳有质感',
      'warm-yellow-海军蓝': '海军蓝+暖光=复古胶片感',
      'warm-yellow-白色': '白色在暖光下温柔发光',
      'warm-yellow-酒红': '酒红+暖光=高级电影感',
      'black-亮色系': '夜拍穿亮色，闪光灯一闪你就是焦点',
      'black-霓虹粉': '霓虹粉在暗夜中自带氛围感',
      'black-银白': '银白色反光材质在夜晚闪耀',
      'black-电光蓝': '电光蓝+夜景霓虹=赛博朋克风',
      'white-正红色': '正红色在白雪背景中极其出挑，冬日焦点',
      'white-明黄色': '明黄+白雪=温暖冬日感，照片立刻有了温度',
      'white-宝蓝色': '宝蓝与白雪冷暖对比，高级又清爽',
      'white-亮橙色': '亮橙色在白色背景中活力四射，青春感满分',
    };
    final key = '$scene-$clothingColor';
    return reasons[key] ?? '与场景色彩协调，照片整体更和谐';
  }

  String _pairingTip(String sceneKey, String timeOfDay) {
    if (timeOfDay == 'golden-hour') return '黄金时刻暖光下，白色/米色/浅粉最温柔发光';
    if (timeOfDay == 'night') return '夜拍建议至少一件亮色单品，避免全黑融入背景';
    switch (sceneKey) {
      case 'beach':
        return '海边风大，裙摆飘逸的款式比紧身款更出片';
      case 'street':
        return '配饰是街拍灵魂，墨镜/帽子/包包至少带两件';
      case 'indoor':
        return '室内光线柔和，丝绒/针织等有质感的材质更上镜';
      case 'outdoor':
        return '与自然环境呼应的色系最和谐，避免荧光色';
      default:
        return '选你穿着最自在的衣服，自信是最好的滤镜';
    }
  }

  List<ColorSuggestion> _defaultColorSuggestions() {
    return const [
      ColorSuggestion(name: '白色', hexColor: 0xFFFFFF, reason: '万能搭配色，任何场景都干净清爽'),
      ColorSuggestion(name: '浅蓝', hexColor: 0x87CEEB, reason: '清新自然，与大多数户外场景和谐'),
      ColorSuggestion(name: '米色', hexColor: 0xF5E6D3, reason: '温柔大地色，低调高级感'),
    ];
  }
}

// ── Internal data classes ──

class _NamedColor {
  final String name;
  final int hex;
  const _NamedColor(this.name, this.hex);
}

class _ClothingAdvice {
  final List<String> recommend;
  final List<String> avoid;
  const _ClothingAdvice({required this.recommend, required this.avoid});
}
