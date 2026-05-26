/// Camera movement technique knowledge base.
///
/// 30+ camera movement techniques across 9 categories, used for
/// short-video shooting guidance. Data is static const — no external JSON.

class CameraMovement {
  final String id;
  final String nameZh;
  final String category; // 推/拉/摇/移/跟/升/降/旋转/复合
  final String difficulty; // beginner/intermediate/advanced
  final String description;
  final List<String> steps;
  final List<String> suitableScenes;
  final String tipText;
  final String iconSymbol;

  const CameraMovement({
    required this.id,
    required this.nameZh,
    required this.category,
    required this.difficulty,
    required this.description,
    required this.steps,
    required this.suitableScenes,
    required this.tipText,
    required this.iconSymbol,
  });
}

class CameraMovements {
  CameraMovements._();

  static const List<String> categories = [
    '推', '拉', '摇', '移', '跟', '升', '降', '旋转', '复合',
  ];

  static const all = <CameraMovement>[
    // ── 推 Push ──────────────────────────────────────────────
    CameraMovement(
      id: 'push-slow',
      nameZh: '慢推近',
      category: '推',
      difficulty: 'beginner',
      description: '相机缓慢向前推进，逐渐靠近被摄主体，营造紧张感或强调主体细节。最基础也最常用的运镜手法。',
      steps: ['双手握稳手机，肘部夹紧身体', '以每秒一步的速度匀速向前迈步', '保持主体始终在画面中央', '推进过程中呼吸平稳避免抖动'],
      suitableScenes: ['人像特写', '产品展示', '情感高潮'],
      tipText: '缓慢匀速向前，保持主体居中',
      iconSymbol: '→·',
    ),
    CameraMovement(
      id: 'push-fast',
      nameZh: '快推近',
      category: '推',
      difficulty: 'intermediate',
      description: '快速向前推进，制造强烈的视觉冲击力，常用于转场或强调突发情绪。',
      steps: ['确认前方地面平整无障碍', '快速向前迈出 2-3 步', '接近主体时逐渐减速缓冲', '保持手机角度不变'],
      suitableScenes: ['舞蹈动作', '情绪爆发', '转场特效'],
      tipText: '快速向前，近身减速',
      iconSymbol: '→→',
    ),
    CameraMovement(
      id: 'push-reveal',
      nameZh: '缓推揭示',
      category: '推',
      difficulty: 'beginner',
      description: '从遮挡物（树/墙/门框）后方缓慢推出，由暗到亮揭开场景全貌，营造探索感。',
      steps: ['从墙壁或门框后方开始', '手机从遮挡物边缘缓慢平移出来', '推进同时画面逐步展现完整场景', '保持曝光锁定避免明暗跳动'],
      suitableScenes: ['旅行风景', '建筑空间', '开篇引入'],
      tipText: '从遮挡物后缓慢推出',
      iconSymbol: '⊳',
    ),

    // ── 拉 Pull ──────────────────────────────────────────────
    CameraMovement(
      id: 'pull-slow',
      nameZh: '慢拉远',
      category: '拉',
      difficulty: 'beginner',
      description: '从主体特写缓慢后退拉开，逐渐展现环境全貌。用来表达人物与环境的关系，或片尾收束情绪。',
      steps: ['先对准主体（人脸或物体）拍 2 秒', '缓慢向后倒退，每一步观察画面', '退到预想位置后停留 3 秒收尾', '后退时注意脚后跟安全'],
      suitableScenes: ['人物出场', '片尾收束', '场景介绍'],
      tipText: '从特写缓慢后退，展现环境',
      iconSymbol: '←·',
    ),
    CameraMovement(
      id: 'pull-fast',
      nameZh: '快拉远',
      category: '拉',
      difficulty: 'intermediate',
      description: '快速后退拉开距离，形成"抽离感"，常用于表达震惊、失落等情绪转折。',
      steps: ['主体占画面 1/3', '确认后退路线安全', '快速平稳后退 4-5 步', '后退到位后稳住 2 秒'],
      suitableScenes: ['情绪转折', '剧情高潮', '结尾冲击'],
      tipText: '快速后退拉开距离',
      iconSymbol: '←←',
    ),
    CameraMovement(
      id: 'pull-ending',
      nameZh: '拉远收尾',
      category: '拉',
      difficulty: 'beginner',
      description: '缓慢后退同时主体转身离开或挥手告别，经典短视频结尾手法。',
      steps: ['正面拍摄人物', '人物开始转身或后退', '拍摄者同步缓慢后退', '画面留给环境来收尾'],
      suitableScenes: ['vlog结尾', '旅行打卡', '日常记录'],
      tipText: '人物离开，镜头缓慢后退',
      iconSymbol: '←✧',
    ),

    // ── 摇 Pan ───────────────────────────────────────────────
    CameraMovement(
      id: 'pan-left',
      nameZh: '左摇',
      category: '摇',
      difficulty: 'beginner',
      description: '手机在原地从左向右水平转动，模拟人眼扫视场景，常用于展现宽阔风景。',
      steps: ['双脚站稳，腰部为轴', '双手握机，肘部夹紧', '从左侧开始匀速转到右侧', '速度保持每 3 秒转 90 度'],
      suitableScenes: ['风景大全景', '房间展示', '人群扫视'],
      tipText: '腰部转动，匀速水平扫视',
      iconSymbol: '↻',
    ),
    CameraMovement(
      id: 'pan-right',
      nameZh: '右摇',
      category: '摇',
      difficulty: 'beginner',
      description: '从右向左水平转动，与左摇方向相反，根据场景选择起始方向。',
      steps: ['从右侧场景开始', '以腰部为轴平稳转动', '从左到右匀速扫过', '结尾停留 2 秒'],
      suitableScenes: ['风景大全景', '城市天际线', '桌面展示'],
      tipText: '从右到左匀速扫视',
      iconSymbol: '↺',
    ),
    CameraMovement(
      id: 'pan-tilt',
      nameZh: '上下摇',
      category: '摇',
      difficulty: 'beginner',
      description: '手机在垂直方向上下转动，从上到下展示高楼/瀑布，或从下到上展现人物全身。',
      steps: ['从顶部（天空/楼顶）开始', '以手腕为轴缓慢向下转动', '保持水平不发生歪斜', '落幅在主体上停留 2 秒'],
      suitableScenes: ['高楼建筑', '瀑布流水', '人物全身穿搭'],
      tipText: '从上到下或从下到上匀速转动',
      iconSymbol: '↕',
    ),
    CameraMovement(
      id: 'whip-pan',
      nameZh: '快速甩摇',
      category: '摇',
      difficulty: 'advanced',
      description: '极快速地水平甩动手机，画面形成运动模糊，用于炫酷转场。两段素材需在模糊处拼接。',
      steps: ['第一段结尾快速右甩至模糊', '第二段开头从右快速甩入', '两段剪辑时在模糊帧处拼接', '甩动速度要快，画面完全模糊'],
      suitableScenes: ['转场特效', '快节奏vlog', '卡点视频'],
      tipText: '快速甩动制造模糊转场',
      iconSymbol: '↝',
    ),

    // ── 移 Truck ─────────────────────────────────────────────
    CameraMovement(
      id: 'truck-left',
      nameZh: '左平移',
      category: '移',
      difficulty: 'intermediate',
      description: '手机保持与被摄主体平行，向左侧横向移动，产生环绕观察的立体感。',
      steps: ['与被摄主体保持固定距离', '向左侧横向迈步，蟹步行走', '手机始终垂直对准主体', '每一步保持相同步幅和速度'],
      suitableScenes: ['产品展示', '人物走姿', '建筑立面'],
      tipText: '保持距离，横向蟹步移动',
      iconSymbol: '⇐',
    ),
    CameraMovement(
      id: 'truck-right',
      nameZh: '右平移',
      category: '移',
      difficulty: 'intermediate',
      description: '向右横向移动，与左平移互补，提供反向视角。',
      steps: ['保持与被摄主体的距离', '向右侧横向蟹步行走', '手机始终对准主体不偏移', '步伐均匀，避免上下颠簸'],
      suitableScenes: ['街道跟拍', '车展展示', '空间导览'],
      tipText: '保持距离向右横向移动',
      iconSymbol: '⇒',
    ),
    CameraMovement(
      id: 'truck-orbit',
      nameZh: '平移环绕',
      category: '移',
      difficulty: 'advanced',
      description: '以被摄主体为圆心，弧形横向移动半圈或一圈，展现主体的立体感和环境关系。',
      steps: ['以主体为圆心，半径 2-3 米', '弧形步伐，始终面向主体', '每一步调整手机角度对准中心', '走半圈至一圈，保持速度均匀'],
      suitableScenes: ['人物大片', '雕塑/展品', '汽车展示'],
      tipText: '以主体为圆心弧线移动',
      iconSymbol: '⊙',
    ),

    // ── 跟 Follow ────────────────────────────────────────────
    CameraMovement(
      id: 'follow-front',
      nameZh: '正面跟拍',
      category: '跟',
      difficulty: 'intermediate',
      description: '在人物前方后退跟拍，保持人物在画面中的位置和大小不变，让观众有"一起走"的代入感。',
      steps: ['站在人物前方 2 米', '与人物保持相同的行走速度', '后退时余光注意脚下安全', '保持人物在画面中央 1/2 高度'],
      suitableScenes: ['人物出场', '旅行行走', '对话场景'],
      tipText: '前方后退跟拍，同步速度',
      iconSymbol: '⇤',
    ),
    CameraMovement(
      id: 'follow-side',
      nameZh: '侧面跟随',
      category: '跟',
      difficulty: 'intermediate',
      description: '在人物侧面平行行走跟拍，捕捉人物行走时的侧脸和动作轮廓。',
      steps: ['与人物平行，相距 2 米左右', '与人物保持同步速度行走', '手机水平对准人物侧面', '可利用前景（树叶/栏杆）增加层次'],
      suitableScenes: ['街拍穿搭', '跑步运动', '旅行随拍'],
      tipText: '侧面平行跟拍，同步行走',
      iconSymbol: '⇋',
    ),
    CameraMovement(
      id: 'follow-back',
      nameZh: '背影跟拍',
      category: '跟',
      difficulty: 'beginner',
      description: '在人物后方跟随拍摄背影，营造"跟随视角"的沉浸感和故事感。',
      steps: ['跟在人物后方 2-3 米', '镜头对准人物背部，留出前方空间', '保持稳定步伐跟随', '可适当降低机位到腰部高度'],
      suitableScenes: ['旅行vlog', '故事开头', '日常记录'],
      tipText: '后方跟随，展现人物视角',
      iconSymbol: '⇥',
    ),

    // ── 升 Boom-up ───────────────────────────────────────────
    CameraMovement(
      id: 'boom-up-slow',
      nameZh: '缓慢升起',
      category: '升',
      difficulty: 'intermediate',
      description: '手机从低角度缓缓升起至高角度，展现从局部到全局的视觉变化。可借助身体下蹲再站起实现。',
      steps: ['下蹲或弯膝，手机置于膝盖高度', '缓慢站起，手机随身体匀速上升', '升到最高处后稳住 2 秒', '保持手机角度随高度微调，始终对准主体'],
      suitableScenes: ['建筑空间', '人物登场', '场景揭示'],
      tipText: '从低处缓慢站起升高',
      iconSymbol: '↑',
    ),
    CameraMovement(
      id: 'boom-up-reveal',
      nameZh: '升起揭示',
      category: '升',
      difficulty: 'intermediate',
      description: '从遮挡物下方升起，逐步揭示后方的主体或场景，制造"惊喜感"。',
      steps: ['手机从桌面/围栏下方开始', '缓慢匀速升起', '越过遮挡物后继续上升至构图完美', '配合主体动作同步揭示更佳'],
      suitableScenes: ['美食上桌', '产品揭幕', '人物亮相'],
      tipText: '从遮挡物下方升起揭示',
      iconSymbol: '↑✧',
    ),

    // ── 降 Boom-down ─────────────────────────────────────────
    CameraMovement(
      id: 'boom-down-slow',
      nameZh: '缓慢下降',
      category: '降',
      difficulty: 'beginner',
      description: '手机从高处缓慢下降至低角度，从全局过渡到局部细节，或表达"坠落""失落"情绪。',
      steps: ['双手举高手机至头顶', '缓慢下蹲或放下手臂', '下降速度均匀，画面平稳', '落幅在低角度停稳 2 秒'],
      suitableScenes: ['高大建筑', '情绪低落', '片尾收束'],
      tipText: '从高处缓慢下降至低处',
      iconSymbol: '↓',
    ),
    CameraMovement(
      id: 'boom-down-dive',
      nameZh: '俯冲式下降',
      category: '降',
      difficulty: 'advanced',
      description: '快速从高角度俯冲到低角度，配合加速剪辑，制造"跌落"或"冲击"的视觉张力。',
      steps: ['将手机举至最高点', '快速下蹲同时保持画面稳定', '下降过程中可略微前倾增加速度感', '落幅稳在膝盖高度'],
      suitableScenes: ['动作场面', '节奏卡点', '情绪爆发'],
      tipText: '快速下降，制造冲击感',
      iconSymbol: '↓↓',
    ),

    // ── 旋转 Roll ────────────────────────────────────────────
    CameraMovement(
      id: 'dutch-angle',
      nameZh: '荷兰角倾斜',
      category: '旋转',
      difficulty: 'intermediate',
      description: '手机倾斜 15-45 度拍摄，打破水平线产生不安定感，常用于表达紧张/混乱/个性风格。',
      steps: ['确定倾斜角度（15° 微妙，30° 明显）', '倾斜手机后稳定握持', '可配合推/拉运镜增强效果', '不宜长时间使用，10 秒内切换回水平'],
      suitableScenes: ['悬疑氛围', '叛逆风格', '舞蹈卡点'],
      tipText: '倾斜手机 15-30 度制造张力',
      iconSymbol: '↗',
    ),
    CameraMovement(
      id: 'orbit-360',
      nameZh: '360°环绕',
      category: '旋转',
      difficulty: 'advanced',
      description: '围绕主体走一整圈，全方位展示主体与周围环境的关系，视觉冲击力极强。',
      steps: ['以主体为圆心，半径 2 米左右', '保持手机始终对准主体中心', '缓慢匀速走圈', '可配合主体自身旋转动作', '走完一圈后稳住 2 秒'],
      suitableScenes: ['人物大片', '风景打卡', '舞蹈高潮'],
      tipText: '围绕主体匀速走一整圈',
      iconSymbol: '⊙↻',
    ),

    // ── 复合 Combo ────────────────────────────────────────────
    CameraMovement(
      id: 'push-tilt-up',
      nameZh: '推近+上摇',
      category: '复合',
      difficulty: 'advanced',
      description: '同时向前推进并向上摇起，常用于从脚到头展示人物全身穿搭，或从细节到全景展示建筑。',
      steps: ['从低角度开始（腰部以下）', '向前迈步的同时缓慢抬起手机', '推进和上摇的速度要协调一致', '结束时机位在头顶高度'],
      suitableScenes: ['穿搭展示', '高大建筑', '人物登场'],
      tipText: '向前推同时向上摇起',
      iconSymbol: '→↑',
    ),
    CameraMovement(
      id: 'pull-boom-up',
      nameZh: '拉远+升起',
      category: '复合',
      difficulty: 'advanced',
      description: '后退拉远的同时升高机位，从特写过渡到大全景俯瞰，常用于片尾或场景转换。',
      steps: ['从主体特写开始', '向后迈步的同时向上站起', '后退和上升的速度同步', '最终到达高角度大全景停稳'],
      suitableScenes: ['片尾收束', '场景过渡', '航拍替代'],
      tipText: '后退同时升高机位',
      iconSymbol: '←↑',
    ),
    CameraMovement(
      id: 'follow-orbit',
      nameZh: '跟拍+环绕',
      category: '复合',
      difficulty: 'advanced',
      description: '在人物行走时从正面跟拍过渡到侧面环绕，一气呵成增加镜头丰富度。',
      steps: ['先从正面跟拍人物行走', '在合适时机开始向侧面弧形移动', '过渡到侧面跟拍或背面跟拍', '整个过程保持人物在画面中'],
      suitableScenes: ['vlog高潮', '舞蹈跟拍', '旅行记录'],
      tipText: '正面跟拍过渡到弧线环绕',
      iconSymbol: '⇤⊙',
    ),
    CameraMovement(
      id: 'hitchcock-zoom',
      nameZh: '希区柯克变焦',
      category: '复合',
      difficulty: 'advanced',
      description: '后退的同时放大画面（或前进的同时缩小），背景透视剧烈变化而主体大小不变，制造心理眩晕感。经典电影手法。',
      steps: ['对准人物面部或上半身', '开始向后迈步的同时双指放大画面', '后退速度和放大速度精确配合', '主体大小保持不变，背景产生压缩感', '拍摄 5-8 秒即可'],
      suitableScenes: ['惊悚氛围', '心理表现', '高光时刻'],
      tipText: '后退+放大，保持主体大小不变',
      iconSymbol: '←⊕',
    ),
  ];

  /// Filter movements by category (null = all).
  static List<CameraMovement> byCategory(String? category) {
    if (category == null) return all;
    return all.where((m) => m.category == category).toList();
  }

  /// Get a single movement by id.
  static CameraMovement? byId(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}
