part of 'book_pages.dart';

/// "AM" for "Alex Martin", "N" for "Noah".
String initials(String name) {
  final words = name.trim().split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty).toList();
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// "Family tree": a little tree growing from the baby, with the parents on its branches, then the
/// grandparents and so on (any number of generations, see `family_tree.dart`), each person's
/// brothers and sisters beside them; one side lilac, the other seafoam. Cousins and the rest of
/// the family are a list under it.
class FamilyTreePage extends StatelessWidget {
  const FamilyTreePage({super.key, required this.child});
  final Child child;

  static bool hasText(Child child) => child.book.keys.any(isTreeKey);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final readOnly = s.bookOnly;
    final tree = FamilyTree(child.book, child.bookPhotos.keys.toSet());
    return TapedPaper(
      tilt: -0.006,
      semanticLabel: readOnly ? l10n.pagesTreeTitle : l10n.pagesTapToEdit(l10n.pagesTreeTitle),
      onTap: readOnly ? null : () => editTreePage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesTreeTitle, Icons.account_tree_rounded),
          _TreeView(child: child, tree: tree, edit: !readOnly),
          if (tree.name('tree_others') case final v?) _Block(l10n.pagesTreeOthers, v),
          if (!hasText(child))
            _Prompt(l10n.pagesTreePrompt)
          else if (!readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.treeTapHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.pal.muted),
              ),
            ),
        ],
      ),
    );
  }
}

const _personStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.15);
const _smallStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 11, height: 1.15);
const _captionStyle = TextStyle(fontSize: 11, height: 1.2);

/// Generations shown above the root on the book's page (the great-grandparents, from the baby).
const _pageDepth = 3;

/// A badge's size by generation above the root (the root 64, parents 50…).
double _badgeAt(int level) => const [64.0, 50.0, 40.0, 32.0].elementAtOrNull(level) ?? 28;
TextStyle _nameAt(int level) => level == 0 ? serifStyle(18) : (level <= 2 ? _personStyle : _smallStyle);

/// The side of the family someone is on: the father's line lilac, the mother's seafoam, the baby
/// and their brothers and sisters the book's own color.
Kind _sideOf(int n) => n == 1 ? Kind.milestone : ((n >> (generationOf(n) - 1)) == 2 ? Kind.sleep : Kind.activity);

/// How a spot on the tree looks: someone, a "+" to fill in, or (for book viewers) an empty ring
/// on the way to someone further up.
enum _Look { person, add, gap }

/// One person on the drawn tree, in the tree's own coordinates.
class _Node {
  const _Node({
    required this.id,
    required this.n,
    required this.level,
    required this.center,
    required this.badge,
    required this.width,
    required this.bottom,
    required this.style,
    required this.name,
    required this.caption,
    required this.side,
    required this.look,
    required this.more,
  });

  /// The person's key (`tree_parent_1`, `tree_s1_2`; the baby's `tree_baby`).
  final String id;

  /// An ancestor's number (the baby 1); null for a brother or sister.
  final int? n;

  /// Generations above the root.
  final int level;

  /// The badge's centre.
  final Offset center;
  final double badge;

  /// The width of the name under the badge.
  final double width;

  /// The bottom of the row (under the longest name in it), where branches start.
  final double bottom;
  final TextStyle style;
  final String? name;

  /// The relation line under the name ("Grandmother on Dad's side"), on the root only.
  final String? caption;
  final Kind side;
  final _Look look;

  /// More generations above them than are shown.
  final bool more;

  double get badgeTop => center.dy - badge / 2;

  _Node moved(Offset by) => _Node(
    id: id,
    n: n,
    level: level,
    center: center + by,
    badge: badge,
    width: width,
    bottom: bottom + by.dy,
    style: style,
    name: name,
    caption: caption,
    side: side,
    look: look,
    more: more,
  );

  static _Node lerp(_Node a, _Node b, double t) => _Node(
    id: b.id,
    n: b.n,
    level: b.level,
    center: Offset.lerp(a.center, b.center, t)!,
    badge: lerpDouble(a.badge, b.badge, t)!,
    width: lerpDouble(a.width, b.width, t)!,
    bottom: lerpDouble(a.bottom, b.bottom, t)!,
    style: TextStyle.lerp(a.style, b.style, t)!,
    name: b.name ?? a.name,
    caption: t < 0.5 ? a.caption : b.caption,
    side: b.side,
    look: b.look,
    more: b.more,
  );
}

/// Parents and the children drawn under them: the branches between them.
typedef _Family = ({String id, List<String> parents, List<String> children, int level});

/// The tree laid out from a [root] up: who is where, and its size.
class _TreeLayout {
  _TreeLayout(this.root, this.nodes, this.families, this.size);
  final int root;
  final Map<String, _Node> nodes;
  final List<_Family> families;
  final Size size;

  int get levels => nodes.values.fold(0, (m, n) => math.max(m, n.level));
}

/// Lays the tree out from [root] up to [depth] generations above it: each person under the middle
/// of their parents, each branch as wide as its names need, brothers and sisters beside the
/// person (outside, away from the other side of the family).
_TreeLayout _layoutTree(BuildContext context, FamilyTree tree, {required int root, required int depth, required bool edit, required String babyName}) {
  final base = DefaultTextStyle.of(context).style;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  Size measure(String text, TextStyle style, [double maxWidth = double.infinity]) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: base.merge(style)),
      textDirection: direction,
      textScaler: scaler,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double longestWord(String text, TextStyle style) => [
    0.0,
    for (final w in text.split(RegExp(r'\s+')))
      if (w.isNotEmpty) measure(w, style).width,
  ].reduce(math.max);

  // Which ancestors show, and how.
  final looks = <int, _Look?>{};
  _Look? look(int n, int level) => looks.putIfAbsent(n, () {
    if (level == 0) return _Look.person;
    if (level > depth) return null;
    if (tree.hasAncestor(n)) return _Look.person;
    final above = [look(2 * n, level + 1), look(2 * n + 1, level + 1)].any((l) => l == _Look.person || l == _Look.gap);
    if (above) return edit ? _Look.add : _Look.gap;
    if (edit && (level == 1 || tree.hasAncestor(n >> 1))) return _Look.add;
    return null;
  });

  // Each spot's size.
  const gap = 10.0;
  String keyOf(int n) => n == 1 ? treeBabyPhoto : treeKey(n);
  _Node item(String key, int? n, int level, _Look look, {bool sibling = false}) {
    final badge = sibling ? math.max(24.0, _badgeAt(level) * 0.75) : _badgeAt(level);
    final style = sibling ? (level == 0 ? _personStyle : _smallStyle) : _nameAt(level);
    final name = look != _Look.person ? null : (n == 1 ? babyName : tree.name(key));
    final isRoot = !sibling && level == 0;
    final caption = isRoot && n != 1 ? tree.relation(key) : null;
    var width = math.max(badge, isRoot ? measure(name ?? '', style).width : longestWord(name ?? '', style)) + 4;
    if (caption != null) width = math.max(width, measure(caption, _captionStyle).width + 4);
    if (isRoot && n == 1) width = math.max(width, 150);
    var label = name == null ? 0.0 : 4 + measure(name, style, width).height;
    if (caption != null) label += 2 + measure(caption, _captionStyle, width).height;
    if (isRoot && n == 1) label += 14;
    return _Node(
      id: key,
      n: n,
      level: level,
      center: Offset.zero,
      badge: badge,
      width: width,
      // For now the height under the badge's centre; made the row's bottom below.
      bottom: badge / 2 + label,
      style: style,
      name: name,
      caption: caption,
      side: _sideOf(sibling ? siblingOf(key)!.$1 : n!),
      look: look,
      more: false,
    );
  }

  // A person with their brothers and sisters beside them, left to right.
  List<_Node> block(int n, int level, _Look l) {
    final me = item(keyOf(n), n, level, l);
    if (l != _Look.person) return [me];
    final sibs = [for (final k in tree.siblings(n)) item(k, null, level, _Look.person, sibling: true)];
    if (n != root) return n.isEven ? [...sibs.reversed, me] : [me, ...sibs];
    // The root stays in the middle: the first one on its right, the next on its left…
    return [
      for (var i = sibs.length - 1; i >= 0; i--)
        if (i.isOdd) sibs[i],
      me,
      for (var i = 0; i < sibs.length; i++)
        if (i.isEven) sibs[i],
    ];
  }

  final widths = <int, double>{};
  final blocks = <int, List<_Node>>{};
  double blockWidth(int n) => blocks[n]!.fold(0.0, (w, b) => w + b.width + gap);
  List<int> parentsOf(int n, int level) => [
    for (final p in [2 * n, 2 * n + 1])
      if (look(p, level + 1) != null) p,
  ];
  double widthOf(int n, int level) => widths.putIfAbsent(n, () {
    blocks[n] = block(n, level, look(n, level)!);
    final parents = parentsOf(n, level).fold(0.0, (w, p) => w + widthOf(p, level + 1));
    return math.max(blockWidth(n), parents);
  });

  final placed = <String, (_Node, double)>{};
  final families = <_Family>[];
  void place(int n, int level, double x0) {
    final w = widthOf(n, level);
    var x = x0 + (w - blockWidth(n)) / 2;
    for (final b in blocks[n]!) {
      placed[b.id] = (b, x + (b.width + gap) / 2);
      x += b.width + gap;
    }
    final parents = parentsOf(n, level);
    var px = x0 + (w - parents.fold(0.0, (s, p) => s + widthOf(p, level + 1))) / 2;
    for (final p in parents) {
      place(p, level + 1, px);
      px += widthOf(p, level + 1);
    }
    if (parents.isNotEmpty) {
      families.add((id: 'f$n', parents: [for (final p in parents) keyOf(p)], children: [for (final b in blocks[n]!) b.id], level: level + 1));
    }
  }

  final width = widthOf(root, 0);
  place(root, 0, 0);

  // Rows from the top: each as tall as its tallest spot, with room for branches between them.
  final levels = placed.values.fold(0, (m, p) => math.max(m, p.$1.level));
  bool more(_Node b) => b.n != null && b.look == _Look.person && b.level == depth && tree.hasAncestorsAbove(b.n!);
  var y = placed.values.any((p) => more(p.$1)) ? 20.0 : 2.0;
  final nodes = <String, _Node>{};
  for (var level = levels; level >= 0; level--) {
    final row = [
      for (final p in placed.values)
        if (p.$1.level == level) p,
    ];
    final mid = _badgeAt(level) / 2;
    final height = row.fold(_badgeAt(level), (h, p) => math.max(h, mid + p.$1.bottom));
    for (final (b, x) in row) {
      nodes[b.id] = _Node(
        id: b.id,
        n: b.n,
        level: level,
        center: Offset(x, y + mid),
        badge: b.badge,
        width: b.width,
        bottom: y + height,
        style: b.style,
        name: b.name,
        caption: b.caption,
        side: b.side,
        look: b.look,
        more: more(b),
      );
    }
    y += height + (level > 0 ? 40 : 4);
  }
  return _TreeLayout(root, nodes, families, Size(width.ceilToDouble(), y.ceilToDouble()));
}

/// A camera move the Prezi way (van Wijk and Nuij's smooth zoom): it pulls back as it travels and
/// closes in as it lands, more the further it goes. Returns the camera at each moment (0–1) and how
/// long the move should take.
(Matrix4 Function(double), Duration) _flight(Matrix4 from, Matrix4 to, Size window) {
  final s0 = from.entry(0, 0), s1 = to.entry(0, 0);
  final t0 = from.getTranslation(), t1 = to.getTranslation();
  final mid = window.center(Offset.zero);
  final c0 = Offset((mid.dx - t0.x) / s0, (mid.dy - t0.y) / s0);
  final c1 = Offset((mid.dx - t1.x) / s1, (mid.dy - t1.y) / s1);
  final w0 = window.width / s0, w1 = window.width / s1;
  const rho = 1.3, rho2 = rho * rho, rho4 = rho2 * rho2;
  double cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
  double sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
  double tanh(double x) => sinh(x) / cosh(x);
  final d = c1 - c0, u1 = d.distance;
  final double length;
  final (double, double) Function(double) at;
  if (u1 < 1e-3 * w0) {
    final k = w1 < w0 ? -1 : 1;
    length = (math.log(w1 / w0)).abs() / rho;
    at = (s) => (0, w0 * math.exp(k * rho * s));
  } else {
    final b0 = (w1 * w1 - w0 * w0 + rho4 * u1 * u1) / (2 * w0 * rho2 * u1);
    final b1 = (w1 * w1 - w0 * w0 - rho4 * u1 * u1) / (2 * w1 * rho2 * u1);
    final r0 = math.log(math.sqrt(b0 * b0 + 1) - b0), r1 = math.log(math.sqrt(b1 * b1 + 1) - b1);
    length = (r1 - r0) / rho;
    at = (s) => (w0 / rho2 * (cosh(r0) * tanh(rho * s + r0) - sinh(r0)), w0 * cosh(r0) / cosh(rho * s + r0));
  }
  Matrix4 camera(double t) {
    if (t >= 1 || !length.isFinite || length <= 0) return to.clone();
    final (u, w) = at(t * length);
    final c = u1 < 1e-3 * w0 ? Offset.lerp(c0, c1, t)! : c0 + d * (u / u1);
    final s = window.width / w;
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(mid.dx - c.dx * s, mid.dy - c.dy * s, 0);
  }

  final ms = length.isFinite ? (length * 450).clamp(420, 1100).round() : 420;
  return (camera, Duration(milliseconds: ms));
}

/// The tree in its window. It opens showing the whole tree (shrunk to fit the page when wider).
/// Tapping someone glides the camera onto them, Prezi-style, as their photo grows; then their line
/// becomes the tree: they move to the bottom, everyone else fades out and their own parents,
/// grandparents… unfold above them (or, for a brother or sister, they just stay in focus). A trail
/// over the tree leads back down. A pinch zooms and a drag pans too; the window's edges fade where
/// the tree runs past them. The first time it shows (once per child while the app runs), it grows
/// from the baby up, a generation at a time. A button in its corner opens it [fullScreen]: as many
/// generations as fit the screen at a readable size (the page stops at the great-grandparents).
class _TreeView extends StatefulWidget {
  const _TreeView({required this.child, required this.tree, required this.edit, this.fullScreen = false, this.root = 1});
  final Child child;
  final FamilyTree tree;
  final bool edit;
  final bool fullScreen;
  final int root;

  @override
  State<_TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<_TreeView> with TickerProviderStateMixin {
  /// When each child's tree started growing in (this app run), so a tree built again (the list
  /// rebuilt as the book loads) carries on where it was, and later ones show grown.
  static final _growing = <String, DateTime>{};
  static const _fade = 28.0;
  final _transform = TransformationController();
  late final _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final _fly = AnimationController(vsync: this)..addListener(_flying);
  late final _focus = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Matrix4 Function(double)? _camera;
  late int _root = widget.root;
  String? _focused;

  /// While the tree changes root: the old layout (in the new one's coordinates) and where the
  /// window's canvas starts (both layouts fit on it).
  _TreeLayout? _from;
  Offset _origin = Offset.zero;
  _TreeLayout? _shown;
  Size _window = Size.zero;
  Object? _homed;
  final _layouts = <(int, int), _TreeLayout>{};

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    final since = DateTime.now().difference(_growing.putIfAbsent(widget.child.id, DateTime.now));
    _grow.forward(from: since.inMicroseconds / _grow.duration!.inMicroseconds);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layouts.clear();
    if (_still) _grow.value = 1;
  }

  @override
  void didUpdateWidget(_TreeView old) {
    super.didUpdateWidget(old);
    _layouts.clear();
    // Back to the baby when the person at the root was taken off the tree.
    if (!widget.tree.hasAncestor(_root)) _root = 1;
  }

  @override
  void dispose() {
    _grow.dispose();
    _fly.dispose();
    _focus.dispose();
    _morph.dispose();
    _transform.dispose();
    super.dispose();
  }

  _TreeLayout _layout(int root, int depth) =>
      _layouts.putIfAbsent((root, depth), () => _layoutTree(context, widget.tree, root: root, depth: depth, edit: widget.edit, babyName: widget.child.name));

  /// The generations shown above the root: the page's three, or on a full screen as many as fit
  /// with the smallest photo still about 22 px across and names still readable.
  int _depth(int root) {
    if (!widget.fullScreen || _window.isEmpty) return _pageDepth;
    var best = _pageDepth;
    for (var d = _pageDepth + 1; d <= 16; d++) {
      if (!widget.tree.hasAncestorsAbove(root, past: d - 1)) break;
      final l = _layout(root, d);
      final s = math.min(_window.width / l.size.width, _window.height / l.size.height);
      if (s * _badgeAt(d) < 22 || s * _smallStyle.fontSize! < 8.5) break;
      best = d;
    }
    return best;
  }

  /// The camera that shows a rect of the canvas whole, centred.
  Matrix4 _fit(Rect r) {
    final s = math.min(widget.fullScreen ? 1.6 : 1.0, math.min(_window.width / r.width, _window.height / r.height));
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(_window.width / 2 - r.center.dx * s, _window.height / 2 - r.center.dy * s, 0);
  }

  Matrix4 get _home => _fit((Offset.zero & _shown!.size).shift(-_origin));

  void _flying() => _transform.value = _camera!(Curves.easeInOut.transform(_fly.value));

  /// Moves the camera, the Prezi way; done when it lands.
  Future<void> _flyTo(Matrix4 to, {Duration? duration}) async {
    if (_still) {
      _fly.stop();
      _transform.value = to;
      return;
    }
    final (camera, length) = _flight(_transform.value.clone(), to, _window);
    _camera = camera;
    _fly.duration = duration ?? length;
    await _fly.forward(from: 0).orCancel.catchError((_) {});
  }

  /// Keeps the view where it is while the canvas' origin moves [by].
  void _shiftCamera(Offset by) {
    final m = _transform.value.clone();
    final s = m.entry(0, 0), t = m.getTranslation();
    _transform.value = m..setTranslationRaw(t.x + s * by.dx, t.y + s * by.dy, 0);
  }

  void _toHome() {
    if (_focused != null) {
      _focus.reverse().then((_) => mounted ? setState(() => _focused = null) : null);
    }
    _flyTo(_home);
  }

  void _tap(_Node node) {
    if (_morph.isAnimating) return;
    if (node.look == _Look.gap) return;
    if (node.look == _Look.add) {
      _editPerson(node);
      return;
    }
    if (node.n == _root) {
      if (_root == 1) return _toHome();
      if (widget.edit) {
        _editPerson(node);
        return;
      }
      _reroot(_root >> 1);
      return;
    }
    if (node.id == _focused) return _toHome();
    final n = node.n;
    final up = n != null && (widget.edit || widget.tree.hasAncestorsAbove(n) || widget.tree.siblings(n).isNotEmpty);
    _focusOn(node, then: up ? () => _reroot(n) : null);
  }

  void _longPress(_Node node) {
    if (!widget.edit) return;
    if (node.n == 1) {
      editTreePage(context, widget.child);
    } else {
      _editPerson(node);
    }
  }

  /// Glides onto someone as their photo grows, then [then].
  Future<void> _focusOn(_Node node, {VoidCallback? then}) async {
    setState(() => _focused = node.id);
    if (_still) {
      _focus.value = 1;
      then?.call();
      return;
    }
    final at = node.center - _origin;
    final s = (_window.width * 0.24 / (node.badge * 1.8)).clamp(_transform.value.entry(0, 0), 3.0);
    final target = Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(_window.width / 2 - at.dx * s, _window.height * 0.45 - at.dy * s, 0);
    _focus.forward();
    await _flyTo(target);
    if (then == null || !mounted || _focused != node.id) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted && _focused == node.id) then();
  }

  /// Makes person [to] the tree's root: the people both trees share move to their new places, the
  /// others fade out or grow in, and the camera follows to show the new tree whole.
  Future<void> _reroot(int to) async {
    final a = _shown;
    if (a == null || to == _root) return;
    final b = _layout(to, _depth(to));
    // Anchor the new tree on someone both show (the new root, else the old one).
    final anchor = [
      b.root == 1 ? treeBabyPhoto : treeKey(b.root),
      a.root == 1 ? treeBabyPhoto : treeKey(a.root),
    ].where((k) => a.nodes.containsKey(k) && b.nodes.containsKey(k)).firstOrNull;
    final offset = anchor == null ? a.size.center(Offset.zero) - b.size.center(Offset.zero) : a.nodes[anchor]!.center - b.nodes[anchor]!.center;
    final from = _TreeLayout(a.root, {for (final MapEntry(:key, :value) in a.nodes.entries) key: value.moved(offset - _origin)}, a.families, a.size);
    var frame = Offset.zero & b.size;
    for (final n in from.nodes.values) {
      frame = frame
          .expandToInclude(Rect.fromCenter(center: n.center, width: n.width + 10, height: n.badge))
          .expandToInclude(Rect.fromLTRB(n.center.dx, n.center.dy, n.center.dx, n.bottom));
    }
    // The canvas now starts at the frame's corner: the view stays put.
    _shiftCamera(frame.topLeft - offset + _origin);
    setState(() {
      _from = from;
      _origin = frame.topLeft;
      _root = to;
      _shown = b;
    });
    if (_still) return _settle();
    final focus = _focus.reverse();
    final fly = _flyTo(_fit((Offset.zero & b.size).shift(-_origin)), duration: _morph.duration);
    await _morph.forward(from: 0).orCancel.catchError((_) {});
    await Future.wait([focus, fly]);
    if (mounted) _settle();
  }

  /// After a change of root: back to the new tree alone.
  void _settle() {
    _shiftCamera(-_origin);
    setState(() {
      _from = null;
      _origin = Offset.zero;
      _focused = null;
      _morph.value = 0;
      _focus.value = 0;
      _homed = null;
    });
  }

  Future<void> _editPerson(_Node node) async {
    var key = node.id;
    while (true) {
      if (!mounted) return;
      final child = context.read<AppState>().children.where((c) => c.id == widget.child.id).firstOrNull ?? widget.child;
      final done = await _editTreePerson(context, child, key);
      if (!mounted || done == null) return;
      switch (done) {
        case (next: final String next, parents: _):
          key = next;
        case (next: null, parents: true):
          if (node.n case final n? when n != _root) await _reroot(n);
          return;
        default:
          return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final page = box.maxWidth;
      if (widget.fullScreen) {
        _window = box.biggest;
      } else {
        // The window: the baby's whole tree, fitted to the page's width.
        final home = _layout(1, _pageDepth);
        _window = Size(page, math.max(page * 0.6, home.size.height * math.min(1, page / home.size.width)).ceilToDouble());
      }
      if (_from == null) _shown = _layout(_root, _depth(_root));
      final shown = _shown!;
      // Back to the whole tree whenever the window or the tree changes size.
      final homed = (_window, shown.size, _root);
      if (_homed != homed && _from == null && !_fly.isAnimating) {
        _homed = homed;
        _fly.stop();
        _transform.value = _home;
      }
      final viewer = SizedBox.fromSize(
        size: _window,
        child: _fadeEdges(
          InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            boundaryMargin: EdgeInsets.all(_window.longestSide),
            minScale: math.min(0.1, _transform.value.entry(0, 0)),
            maxScale: 4,
            onInteractionStart: (_) => _fly.stop(),
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toHome, child: _canvas()),
          ),
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _root == 1 ? const SizedBox(width: double.infinity) : _trail(),
          ),
          if (widget.fullScreen)
            Expanded(child: viewer)
          else
            Stack(
              children: [
                viewer,
                // In the bottom corner, beside the baby, where the tree has nobody.
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: l10n.pagesTreeFullScreen,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: context.pal.surface.withValues(alpha: 0.85), foregroundColor: context.pal.muted),
                    icon: const Icon(Icons.fullscreen_rounded),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => _FullScreenTree(childId: widget.child.id, edit: widget.edit, root: _root),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    },
  );

  /// The way back down: the baby, …, the root's child, the root.
  Widget _trail() {
    final c = context.pal;
    final line = [for (var g = generationOf(_root); g >= 0; g--) _root >> g];
    String label(int n) => n == 1 ? widget.child.name : (widget.tree.name(treeKey(n)) ?? widget.tree.relation(treeKey(n)));
    final shown = line.length <= 4 ? line : [line.first, 0, ...line.sublist(line.length - 2)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, n) in shown.indexed) ...[
            if (i > 0) Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
            if (n == 0)
              Text('…', style: TextStyle(color: c.muted))
            else if (n == _root)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label(n),
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.ink),
                ),
              )
            else
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => _reroot(n),
                child: Text(
                  label(n),
                  style: TextStyle(color: _sideOf(n).on(c), fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// When a level grows in: the root first, then each level of branches and people.
  double _stage(int stage, int levels) {
    final step = math.min(0.13, 0.78 / math.max(1, 2 * levels));
    return Interval(stage * step, math.min(1, stage * step + 0.22)).transform(_grow.value);
  }

  Widget _canvas() => AnimatedBuilder(
    animation: Listenable.merge([_grow, _morph, _focus]),
    builder: (context, _) {
      final to = _shown!, from = _from;
      final t = Curves.easeInOutCubic.transform(_morph.value);
      final levels = math.max(to.levels, from?.levels ?? 0);
      // Everyone on either tree, where they are now, and how much they show (0–1).
      final nodes = <String, (_Node, double)>{};
      if (from == null) {
        for (final n in to.nodes.values) {
          nodes[n.id] = (n.moved(-_origin), Curves.easeOut.transform(_stage(2 * n.level, levels)));
        }
      } else {
        for (final n in from.nodes.values) {
          if (!to.nodes.containsKey(n.id)) nodes[n.id] = (n, 1 - const Interval(0, 0.5).transform(t));
        }
        for (final n in to.nodes.values) {
          final old = from.nodes[n.id];
          nodes[n.id] = old == null ? (n.moved(-_origin), const Interval(0.45, 1).transform(t)) : (_Node.lerp(old, n.moved(-_origin), t), 1.0);
        }
      }
      final families = <(_Family, double)>[
        if (from != null)
          for (final f in from.families)
            if (!to.families.any((g) => g.id == f.id && listEquals(g.children, f.children))) (f, 1 - const Interval(0, 0.4).transform(t)),
        for (final f in to.families)
          (
            f,
            from == null
                ? _stage(2 * f.level - 1, levels)
                : (from.families.any((g) => g.id == f.id && listEquals(g.children, f.children)) ? 1.0 : const Interval(0.5, 1).transform(t)),
          ),
      ];
      var size = to.size;
      if (from != null) size = Size(size.width - _origin.dx, size.height - _origin.dy);
      for (final (n, _) in nodes.values) {
        size = Size(math.max(size.width, n.center.dx + n.width / 2 + 5), math.max(size.height, n.bottom));
      }
      final c = context.pal;
      final focus = Curves.easeOutBack.transform(_focus.value.clamp(0, 1));
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TreePainter(
                  nodes: {for (final MapEntry(:key, value: (n, _)) in nodes.entries) key: n},
                  families: families,
                  more: [
                    for (final (n, show) in nodes.values)
                      if (n.more) (n, show),
                  ],
                  wood: Kind.growth.on(c).withValues(alpha: c.isDark ? 0.75 : 0.6),
                  leaf: Kind.diaper.fill(c),
                ),
              ),
            ),
            for (final (n, show) in nodes.values)
              if (show > 0)
                _TreeSpot(
                  node: n,
                  show: show,
                  focus: n.id == _focused ? focus : 0,
                  dim: _focused != null && n.id != _focused ? _focus.value : 0,
                  relation: n.id == _focused && n.look == _Look.person && n.n != 1 ? widget.tree.relation(n.id) : null,
                  // A "+" says who goes there.
                  addLabel: n.look == _Look.add ? '${l10n.add}: ${widget.tree.relation(n.id)}' : null,
                  onTap: () => _tap(n),
                  onLongPress: widget.edit && n.look == _Look.person ? () => _longPress(n) : null,
                ),
          ],
        ),
      );
    },
  );

  /// Fades the window's edges where the tree runs past them, more the further it goes.
  Widget _fadeEdges(Widget child) => ValueListenableBuilder<Matrix4>(
    valueListenable: _transform,
    child: child,
    builder: (context, m, child) {
      final shown = _shown;
      if (shown == null) return child!;
      final window = _window;
      // No rotation here: the x axis' scale is the zoom (the z axis keeps 1).
      final scale = m.entry(0, 0), t = m.getTranslation();
      final size = shown.size;
      double past(double by) => (by / _fade).clamp(0.0, 1.0);
      final left = past(-t.x), right = past(t.x + size.width * scale - window.width);
      final top = past(-t.y), bottom = past(t.y + size.height * scale - window.height);
      if (left + right + top + bottom == 0) return child!;
      // An alpha mask, not a colour on screen: opaque keeps the tree, clear hides it.
      Shader mask(Rect r, Axis axis, double start, double end) {
        final f = _fade / (axis == Axis.horizontal ? r.width : r.height);
        return LinearGradient(
          begin: axis == Axis.horizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: axis == Axis.horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 1 - start),
            Colors.black,
            Colors.black,
            Colors.black.withValues(alpha: 1 - end),
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(r);
      }

      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => mask(r, Axis.horizontal, left, right),
        child: ShaderMask(blendMode: BlendMode.dstIn, shaderCallback: (r) => mask(r, Axis.vertical, top, bottom), child: child),
      );
    },
  );
}

/// The family tree on a screen of its own, from the person the page's tree was on.
class _FullScreenTree extends StatelessWidget {
  const _FullScreenTree({required this.childId, required this.edit, required this.root});
  final String childId;
  final bool edit;
  final int root;

  @override
  Widget build(BuildContext context) {
    final child = context.watch<AppState>().children.where((c) => c.id == childId).firstOrNull;
    return Scaffold(
      backgroundColor: context.pal.surface,
      appBar: AppBar(
        backgroundColor: context.pal.surface,
        title: Text(l10n.pagesTreeTitle, style: serifStyle(20)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: child == null
              ? const SizedBox()
              : _TreeView(child: child, tree: FamilyTree(child.book, child.bookPhotos.keys.toSet()), edit: edit, fullScreen: true, root: root),
        ),
      ),
    );
  }
}

/// A person on the tree: their badge with the name under it. In focus, it grows (name and all)
/// around the badge's centre and says who they are; the others dim.
class _TreeSpot extends StatelessWidget {
  const _TreeSpot({
    required this.node,
    required this.show,
    required this.focus,
    required this.dim,
    required this.relation,
    this.addLabel,
    required this.onTap,
    this.onLongPress,
  });
  final _Node node;
  final double show, focus, dim;
  final String? relation, addLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final n = node;
    final baby = n.n == 1 && n.level == 0;
    final photo = context.watch<AppState>().bookPhoto(context.findAncestorStateOfType<_TreeViewState>()!.widget.child, n.id);
    final width = n.width + 6;
    final label = [n.name, n.caption ?? relation].nonNulls.join(', ');
    Widget spot = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (baby)
          Container(
            width: n.badge,
            height: n.badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Kind.milestone.fill(c),
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: 3),
              boxShadow: [BoxShadow(color: c.ink.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
              image: photo == null ? null : DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
            ),
            child: photo != null ? null : Icon(Icons.child_care_rounded, size: n.badge * 0.53, color: c.bandInk),
          )
        else
          _Badge(
            n.look == _Look.person && n.name != null ? initials(n.name!) : null,
            n.side,
            size: n.badge,
            photo: n.look == _Look.person ? photo : null,
            add: n.look == _Look.add,
            glow: focus,
          ),
        if (n.name != null) ...[
          const SizedBox(height: 4),
          Text(
            n.name!,
            textAlign: TextAlign.center,
            style: n.style.copyWith(color: baby ? Kind.milestone.on(c) : c.ink),
          ),
        ],
        if (n.caption ?? relation case final r?)
          Opacity(
            opacity: n.caption != null ? 1 : focus.clamp(0, 1),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              // In focus, the line may be wider than the name: it spreads out on both sides.
              child: n.caption != null
                  ? Text(r, textAlign: TextAlign.center, style: _captionStyle.copyWith(color: n.side.on(c), fontWeight: FontWeight.w600))
                  : SizedBox(
                      height: 28,
                      child: OverflowBox(
                        maxWidth: math.max(width, 150),
                        maxHeight: 28,
                        alignment: Alignment.topCenter,
                        child: Text(r, textAlign: TextAlign.center, maxLines: 2, style: _captionStyle.copyWith(color: n.side.on(c), fontWeight: FontWeight.w600)),
                      ),
                    ),
            ),
          ),
        if (baby)
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 150,
            height: 10,
            decoration: BoxDecoration(color: Kind.diaper.fill(c).withValues(alpha: 0.7), borderRadius: const BorderRadius.all(Radius.elliptical(75, 5))),
          ),
      ],
    );
    final scale = (0.6 + 0.4 * Curves.easeOutBack.transform(show.clamp(0, 1))) * (1 + 0.8 * focus);
    return Positioned(
      left: n.center.dx - width / 2,
      top: n.badgeTop,
      width: width,
      child: Opacity(
        opacity: (show * (1 - 0.45 * dim)).clamp(0, 1),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          origin: Offset(0, n.badge / 2),
          child: Semantics(
            button: n.look != _Look.gap,
            label: addLabel ?? label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: onLongPress,
              child: ExcludeSemantics(child: spot),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circle with the person's photo, else their initials in the side's color, an outlined "+"
/// when nobody is named there yet ([add]), or an empty ring on the way to someone further up.
class _Badge extends StatelessWidget {
  const _Badge(this.initials, this.side, {required this.size, this.photo, this.add = false, this.glow = 0});
  final String? initials;
  final Kind side;
  final double size;
  final Uint8List? photo;
  final bool add;

  /// In focus (0–1): a soft halo in the side's color.
  final double glow;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final empty = initials == null && photo == null;
    final small = size < 36;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: empty ? c.surface : side.fill(c),
        shape: BoxShape.circle,
        border: Border.all(
          color: empty ? c.line.withValues(alpha: add ? 1 : 0.6) : (photo != null ? side.fill(c) : c.surface),
          width: small ? 1.5 : 2.5,
        ),
        boxShadow: glow <= 0
            ? null
            : [
                BoxShadow(
                  color: side.fill(c).withValues(alpha: 0.7 * glow.clamp(0, 1)),
                  blurRadius: 10 * glow,
                  spreadRadius: 3 * glow,
                ),
              ],
        image: photo == null ? null : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
      ),
      child: photo != null
          ? null
          : empty
          ? (add ? Icon(Icons.add_rounded, size: size * 0.5, color: c.muted) : null)
          : Text(
              initials!,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.36, color: side.on(c)),
            ),
    );
  }
}

/// The branches: from each child up to where their parents' branches meet, then up to each
/// parent, with a leaf on the way. A short faded twig over someone with more generations above.
class _TreePainter extends CustomPainter {
  _TreePainter({required this.nodes, required this.families, required this.more, required this.wood, required this.leaf});
  final Map<String, _Node> nodes;
  final List<(_Family, double)> families;
  final List<(_Node, double)> more;
  final Color wood, leaf;

  static double _stroke(int level) => switch (level) {
    1 => 4.5,
    2 => 3,
    3 => 2,
    _ => 1.5,
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final (f, t) in families) {
      if (t <= 0) continue;
      final parents = [for (final id in f.parents) ?nodes[id]];
      final children = [for (final id in f.children) ?nodes[id]];
      if (parents.isEmpty || children.isEmpty) continue;
      final width = _stroke(f.level);
      final branch = Paint()
        ..color = wood.withValues(alpha: wood.a * t.clamp(0, 1))
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final top = parents.map((p) => p.bottom).reduce(math.max);
      final low = children.map((ch) => ch.badgeTop).reduce(math.min);
      // The parents' branches meet a third of the way down, go on as one trunk, then part to
      // each child (the trunk only shows when there is more than one, or one off to the side).
      final meet = Offset(parents.map((p) => p.center.dx).reduce((a, b) => a + b) / parents.length, top + (low - top) * 0.38);
      final split = children.length == 1 && (children.first.center.dx - meet.dx).abs() < 1 ? meet : Offset(meet.dx, top + (low - top) * 0.62);
      // Drawn from the bottom up while the tree grows in: the children's part, then the parents'.
      final grow = t;
      final path = Path();
      void add(Path p, double amount) {
        if (amount <= 0) return;
        for (final metric in p.computeMetrics()) {
          path.addPath(metric.extractPath(0, metric.length * amount.clamp(0, 1)), Offset.zero);
        }
      }

      for (final ch in children) {
        final from = Offset(ch.center.dx, ch.badgeTop);
        final h = from.dy - split.dy;
        add(Path()..moveTo(from.dx, from.dy)..cubicTo(from.dx, from.dy - h * 0.6, split.dx, split.dy + h * 0.4, split.dx, split.dy), grow * 3);
      }
      if (split != meet) add(Path()..moveTo(split.dx, split.dy)..lineTo(meet.dx, meet.dy), grow * 3 - 1);
      final ups = <(Offset, Offset)>[];
      for (final p in parents) {
        final to = Offset(p.center.dx, top);
        ups.add((meet, to));
        add(Path()..moveTo(meet.dx, meet.dy)..cubicTo(meet.dx, meet.dy - (meet.dy - to.dy) * 0.5, to.dx, meet.dy - (meet.dy - to.dy) * 0.5, to.dx, to.dy), grow * 3 - 2);
      }
      canvas.drawPath(path, branch);
      if (grow < 0.8) continue;
      // A leaf halfway up each parent's branch, leaning out from it.
      final leafPaint = Paint()..color = leaf.withValues(alpha: leaf.a * t.clamp(0, 1));
      for (final (i, (a, b)) in ups.indexed) {
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final out = a.dx == b.dx ? (i.isEven ? -1.0 : 1.0) : (b.dx < a.dx ? -1.0 : 1.0);
        canvas.save();
        canvas.translate(mid.dx, mid.dy);
        canvas.rotate(out * 0.9);
        final s = (4.0 + width) * ((grow - 0.8) / 0.2);
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(s * 0.6, -s * 0.9, 0, -s * 2)
            ..quadraticBezierTo(-s * 0.6, -s * 0.9, 0, 0),
          leafPaint,
        );
        canvas.restore();
      }
    }
    // More above: a twig fading out upwards, with a bud.
    for (final (n, t) in more) {
      if (t <= 0) continue;
      final from = Offset(n.center.dx, n.badgeTop - 2), to = from.translate(0, -16);
      final twig = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            wood.withValues(alpha: wood.a * t),
            wood.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(from, to))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, to, twig);
      canvas.drawCircle(to.translate(0, 3), 2, Paint()..color = leaf.withValues(alpha: leaf.a * t * 0.8));
    }
  }

  @override
  bool shouldRepaint(_TreePainter old) => true;
}

/// The page's form: every name on the tree, generation by generation (each generation's boxes for
/// the parents of everyone named in the one before), each person's brothers and sisters, one more
/// for the baby, and the rest of the family as a list.
Future<void> editTreePage(BuildContext context, Child child) {
  final tree = FamilyTree(child.book, child.bookPhotos.keys.toSet());
  final fields = <_Field>[];
  final people = <int>[1];
  for (var i = 0; i < people.length; i++) {
    final n = people[i];
    if (!tree.hasAncestor(n)) continue;
    for (final p in [2 * n, 2 * n + 1]) {
      people.add(p);
      fields.add((key: treeKey(p), label: tree.relation(treeKey(p)), hint: tree.whose(treeKey(p)) ?? l10n.pagesHintName, long: false));
    }
  }
  for (final n in people) {
    for (final k in tree.siblings(n)) {
      fields.add((key: k, label: tree.relation(k), hint: tree.whose(k) ?? l10n.pagesHintName, long: false));
    }
  }
  fields.add((
    key: siblingKey(1, nextSibling(tree.book, 1)),
    label: tree.siblings(1).isEmpty ? l10n.treeAddSibling : l10n.treeAnotherSibling,
    hint: l10n.pagesHintName,
    long: false,
  ));
  fields.add((key: 'tree_others', label: l10n.pagesTreeOthers, hint: l10n.pagesHintNames, long: true));
  return _editPage(
    context,
    child,
    title: l10n.pagesTreeTitle,
    icon: Icons.account_tree_rounded,
    photos: {
      for (final f in fields)
        if (f.key != 'tree_others') f.key: [f.key],
    },
    photoRows: [(key: treeBabyPhoto, label: child.name, hint: l10n.pagesTreeBabyPhoto)],
    fields: fields,
  );
}

/// What the person's sheet asks for once saved: their next new brother or sister's sheet, or to
/// show their parents on the tree.
typedef _PersonDone = ({String? next, bool parents});

/// One person's sheet: their photo, name and whether mother or father (sister or brother), and
/// ways to add their parents or a brother or sister.
Future<_PersonDone?> _editTreePerson(BuildContext context, Child child, String key) => showModalBottomSheet<_PersonDone>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => _PersonSheet(child: child, personKey: key),
);

class _PersonSheet extends StatefulWidget {
  const _PersonSheet({required this.child, required this.personKey});
  final Child child;
  final String personKey;

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  late final _tree = FamilyTree(widget.child.book, widget.child.bookPhotos.keys.toSet());
  String get _key => widget.personKey;
  late final _sibling = siblingOf(_key);
  late final _name = TextEditingController(text: _tree.name(_key) ?? '');
  late Role? _role = _sibling != null && !_tree.roleSet(_key) ? null : _tree.role(_key);
  Uint8List? _photo;
  bool _photoChanged = false, _busy = false;

  bool get _hasPhoto => _photoChanged ? _photo != null : widget.child.bookPhotos.containsKey(_key);

  Future<void> _pickPhoto() async {
    if (_hasPhoto) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(l10n.bookChangePhoto), onTap: () => Navigator.pop(sheet, 'change')),
              ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l10n.remove), onTap: () => Navigator.pop(sheet, 'remove')),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'remove') {
        return setState(() {
          _photo = null;
          _photoChanged = true;
        });
      }
    }
    final photo = await guard(context, () => pickSquarePhoto(size: 400, jpeg: true));
    if (photo != null && mounted) {
      setState(() {
        _photo = photo;
        _photoChanged = true;
      });
    }
  }

  Future<void> _save({bool remove = false, bool sibling = false, bool parents = false}) async {
    setState(() => _busy = true);
    final book = <String, dynamic>{..._tree.book};
    final photos = <String, Uint8List?>{};
    if (remove) {
      book.remove(_key);
      book.remove('${_key}_role');
      if (widget.child.bookPhotos.containsKey(_key)) photos[_key] = null;
    } else {
      book[_key] = _name.text.trim();
      final role = _role;
      final usual = _sibling == null && role == ((treeNumber(_key) ?? 2).isEven ? Role.father : Role.mother);
      if (role == null || usual) {
        book.remove('${_key}_role');
      } else {
        book['${_key}_role'] = role.name;
      }
      if (_photoChanged) photos[_key] = _photo;
    }
    final ok = await _saveBook(context, widget.child, book, photos);
    if (!mounted) return;
    if (!ok) return setState(() => _busy = false);
    final whose = _sibling?.$1 ?? treeNumber(_key) ?? 1;
    Navigator.pop<_PersonDone>(context, (next: sibling ? siblingKey(whose, nextSibling(book, whose)) : null, parents: parents));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    final present = _tree.has(_key);
    final whose = _tree.whose(_key);
    final side = _sideOf(_sibling?.$1 ?? treeNumber(_key) ?? 1);
    final roles = _sibling != null ? const [Role.sister, Role.brother] : const [Role.mother, Role.father];
    String roleName(Role r) => switch (r) {
      Role.mother => l10n.treeMother,
      Role.father => l10n.treeFather,
      Role.sister => l10n.treeSister,
      Role.brother => l10n.treeBrother,
    };
    final photo = _photoChanged ? _photo : context.watch<AppState>().bookPhoto(widget.child, _key);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92, maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  BlobIcon(side, size: 46, icon: Icons.account_tree_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tree.relation(_key), style: serifStyle(22)),
                        if (whose != null) Text(whose, style: TextStyle(color: c.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  FormRow(
                    label: l10n.childName,
                    below: Row(
                      children: [
                        _PhotoSpot(photo: photo, has: _hasPhoto, onTap: _pickPhoto),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _name,
                            autofocus: !present,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(hintText: l10n.pagesHintName),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: SegmentedButton<Role>(
                      segments: [for (final r in roles) ButtonSegment(value: r, label: Text(roleName(r)))],
                      selected: {?_role},
                      emptySelectionAllowed: _sibling != null,
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _role = s.firstOrNull),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Wrap(
                      spacing: 4,
                      children: [
                        if (_sibling == null)
                          TextButton.icon(
                            onPressed: _busy ? null : () => _save(parents: true),
                            icon: const Icon(Icons.north_rounded, size: 18),
                            label: Text(l10n.treeAddParents),
                          ),
                        if (_sibling == null)
                          TextButton.icon(
                            onPressed: _busy ? null : () => _save(sibling: true),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: Text(l10n.treeAddSibling),
                          ),
                        if (present)
                          TextButton.icon(
                            onPressed: _busy ? null : () => _save(remove: true),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: Text(l10n.treeRemovePerson),
                            style: TextButton.styleFrom(foregroundColor: c.danger),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: c.isDark ? k.fill(c) : k.deepTone, foregroundColor: c.onAccent),
                  child: Text(_busy ? l10n.pagesSaving : l10n.pagesSaveToBook),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
