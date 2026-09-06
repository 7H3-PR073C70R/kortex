import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/services/whiteboard_compression.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

enum WhiteboardTool { pen, eraser, shape, text, pan }

enum WhiteboardShape { rectangle, circle, line, arrow, triangle }

class CollaborativeWhiteboardWidget extends StatefulWidget {
  const CollaborativeWhiteboardWidget({
    required this.currentUserId,
    required this.currentUserName,
    super.key,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<CollaborativeWhiteboardWidget> createState() =>
      _CollaborativeWhiteboardWidgetState();
}

class _CollaborativeWhiteboardWidgetState
    extends State<CollaborativeWhiteboardWidget> {
  WhiteboardTool _currentTool = WhiteboardTool.pen;
  WhiteboardShape _currentShape = WhiteboardShape.rectangle;
  Color _selectedColor = const Color(0xFFFFFFFF);
  double _penStrokeWidth = 4;
  double _eraserStrokeWidth = 28;

  final TransformationController _transformationController =
      TransformationController();

  List<WhiteboardPoint> _activePoints = [];

  static const List<Color> _palette = [
    Color(0xFFFFFFFF), // Chalk White
    Color(0xFF00E5FF), // Neon Cyan
    Color(0xFF00E676), // Mint Emerald
    Color(0xFFFFD600), // Amber Gold
    Color(0xFFFF5252), // Coral
    Color(0xFFD500F9), // Electric Violet
    Color(0xFFFF4081), // Rose Pink
    Color(0xFF448AFF), // Sky Blue
    Color(0xFFFF6D00), // Deep Orange
    Color(0xFFB0BEC5), // Slate Gray
  ];

  static const List<double> _penSizes = [2.0, 4.0, 8.0, 14.0];
  static const List<double> _eraserSizes = [16.0, 28.0, 44.0];

  void _onPanStart(DragStartDetails details) {
    if (_currentTool == WhiteboardTool.text) return;
    AppFeedback.light();
    final localPos = details.localPosition;
    setState(() {
      _activePoints = [WhiteboardPoint(x: localPos.dx, y: localPos.dy)];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentTool == WhiteboardTool.text) return;
    final localPos = details.localPosition;
    setState(() {
      if (_currentTool == WhiteboardTool.shape) {
        // For shapes, keep origin at points[0] and update current position at points[1]
        if (_activePoints.length == 1) {
          _activePoints.add(WhiteboardPoint(x: localPos.dx, y: localPos.dy));
        } else {
          _activePoints[1] = WhiteboardPoint(x: localPos.dx, y: localPos.dy);
        }
      } else {
        _activePoints.add(WhiteboardPoint(x: localPos.dx, y: localPos.dy));
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetViewport() {
    AppFeedback.light();
    _transformationController.value = Matrix4.identity();
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentTool == WhiteboardTool.text ||
        _currentTool == WhiteboardTool.pan) {
      return;
    }
    if (_activePoints.length < 2) {
      _activePoints = [];
      return;
    }

    final strokeId =
        'str_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    final isEraser = _currentTool == WhiteboardTool.eraser;
    final isShape = _currentTool == WhiteboardTool.shape;

    // Apply Douglas-Peucker line simplification to achieve ~85% point reduction
    final simplifiedPoints = isShape || _activePoints.length <= 2
        ? List<WhiteboardPoint>.from(_activePoints)
        : WhiteboardCompression.simplify(_activePoints, epsilon: 1.2);

    final stroke = WhiteboardStroke(
      id: strokeId,
      userId: widget.currentUserId,
      userName: widget.currentUserName,
      colorHex: _selectedColor.toARGB32(),
      strokeWidth: isEraser ? _eraserStrokeWidth : _penStrokeWidth,
      isEraser: isEraser,
      elementType: isShape ? 'shape' : 'stroke',
      shapeType: isShape ? _currentShape.name : null,
      points: simplifiedPoints,
    );

    context.read<LiveRoomCubit>().addWhiteboardStroke(stroke);

    setState(() {
      _activePoints = [];
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (_currentTool != WhiteboardTool.text) return;
    unawaited(_promptAddText(details.localPosition));
  }

  Future<void> _promptAddText(Offset position) async {
    AppFeedback.medium();
    final textController = TextEditingController();
    double chosenFontSize = 18;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final colors = dialogCtx.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surfacePrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.surfaceBorder),
              ),
              title: Row(
                children: [
                  Icon(Icons.text_fields_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Add Note / Label',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: chosenFontSize,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your study note or formula...',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.surfaceBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Font Size',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [14.0, 18.0, 24.0, 32.0].map((size) {
                      final isSelected = chosenFontSize == size;
                      return ChoiceChip(
                        label: Text('${size.toInt()}pt'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => chosenFontSize = size);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Place Text'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && textController.text.trim().isNotEmpty) {
      final strokeId =
          'txt_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
      final stroke = WhiteboardStroke(
        id: strokeId,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        colorHex: _selectedColor.toARGB32(),
        strokeWidth: 2,
        elementType: 'text',
        text: textController.text.trim(),
        fontSize: chosenFontSize,
        points: [WhiteboardPoint(x: position.dx, y: position.dy)],
      );

      if (mounted) {
        context.read<LiveRoomCubit>().addWhiteboardStroke(stroke);
      }
    }
  }

  void _confirmClearBoard(BuildContext context) {
    AppFeedback.medium();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Clear Shared Board?'),
          content: const Text(
            'This will erase all collaborative drawings, shapes, and notes for all participants in the room.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.read<LiveRoomCubit>().clearWhiteboard();
              },
              child: const Text('Clear Board'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return BlocBuilder<LiveRoomCubit, LiveRoomState>(
      builder: (context, state) {
        return Stack(
          children: [
            // Interactive Blackboard/Whiteboard Drawing Canvas with Infinite Zoom & Pan
            Positioned.fill(
              child: ColoredBox(
                color: isDark
                    ? const Color(0xFF14171E)
                    : const Color(0xFF23272F),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(1200),
                  panEnabled: _currentTool == WhiteboardTool.pan,
                  scaleEnabled: true,
                  child: GestureDetector(
                    onPanStart:
                        _currentTool == WhiteboardTool.pan ? null : _onPanStart,
                    onPanUpdate: _currentTool == WhiteboardTool.pan
                        ? null
                        : _onPanUpdate,
                    onPanEnd:
                        _currentTool == WhiteboardTool.pan ? null : _onPanEnd,
                    onTapUp: _currentTool == WhiteboardTool.pan ? null : _onTapUp,
                    child: CustomPaint(
                      painter: _WhiteboardPainter(
                        committedStrokes: state.whiteboardStrokes,
                        activePoints: _activePoints,
                        activeColor: _selectedColor,
                        activeStrokeWidth:
                            _currentTool == WhiteboardTool.eraser
                                ? _eraserStrokeWidth
                                : _penStrokeWidth,
                        isEraser: _currentTool == WhiteboardTool.eraser,
                        activeShape: _currentTool == WhiteboardTool.shape
                            ? _currentShape
                            : null,
                        backgroundColor: isDark
                            ? const Color(0xFF14171E)
                            : const Color(0xFF23272F),
                      ),
                      size: const Size(2800, 2800),
                    ),
                  ),
                ),
              ),
            ),

            // Top Status Bar: Attribution badge & active tool hint
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfacePrimary.withAlpha(200),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.draw_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live Canvas (${state.whiteboardStrokes.length} items)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _resetViewport,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.center_focus_strong_rounded,
                                  size: 11,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentTool == WhiteboardTool.text)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(220),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Tap canvas to place text note',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Floating Minimap HUD
            Positioned(
              bottom: 130,
              right: 16,
              child: _WhiteboardMinimap(
                strokes: state.whiteboardStrokes,
                transformationController: _transformationController,
                onReset: _resetViewport,
                colors: colors,
                isDark: isDark,
              ),
            ),

            // Floating Bottom Toolbar with Tool options
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sub-toolbar: Size options or Shape options
                  _buildSubToolbar(colors, isDark),
                  const SizedBox(height: 6),

                  // Main Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E222D).withAlpha(245)
                          : colors.surfacePrimary.withAlpha(245),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(120),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tools and Actions Row
                        Row(
                          children: [
                            // Tool: Pen
                            _ToolButton(
                              icon: Icons.edit_rounded,
                              label: 'Pen',
                              isSelected: _currentTool == WhiteboardTool.pen,
                              onTap: () {
                                AppFeedback.selection();
                                setState(() => _currentTool = WhiteboardTool.pen);
                              },
                              colors: colors,
                            ),
                            const SizedBox(width: 4),

                            // Tool: Eraser
                            _ToolButton(
                              icon: Icons.auto_fix_normal_rounded,
                              label: 'Eraser',
                              isSelected: _currentTool == WhiteboardTool.eraser,
                              onTap: () {
                                AppFeedback.selection();
                                setState(
                                  () => _currentTool = WhiteboardTool.eraser,
                                );
                              },
                              colors: colors,
                            ),
                            const SizedBox(width: 4),

                            // Tool: Shapes
                            _ToolButton(
                              icon: Icons.category_rounded,
                              label: 'Shapes',
                              isSelected: _currentTool == WhiteboardTool.shape,
                              onTap: () {
                                AppFeedback.selection();
                                setState(() => _currentTool = WhiteboardTool.shape);
                              },
                              colors: colors,
                            ),
                            const SizedBox(width: 4),

                            // Tool: Text
                            _ToolButton(
                              icon: Icons.title_rounded,
                              label: 'Text',
                              isSelected: _currentTool == WhiteboardTool.text,
                              onTap: () {
                                AppFeedback.selection();
                                setState(() => _currentTool = WhiteboardTool.text);
                              },
                              colors: colors,
                            ),
                            const SizedBox(width: 4),

                            // Tool: Pan & Zoom
                            _ToolButton(
                              icon: Icons.pan_tool_rounded,
                              label: 'Pan',
                              isSelected: _currentTool == WhiteboardTool.pan,
                              onTap: () {
                                AppFeedback.selection();
                                setState(() => _currentTool = WhiteboardTool.pan);
                              },
                              colors: colors,
                            ),

                            const Spacer(),

                            // Undo Button
                            IconButton(
                              icon: const Icon(Icons.undo_rounded, size: 18),
                              tooltip: 'Undo',
                              onPressed: state.whiteboardStrokes.isEmpty
                                  ? null
                                  : () {
                                      AppFeedback.light();
                                      context
                                          .read<LiveRoomCubit>()
                                          .undoWhiteboardStroke();
                                    },
                            ),

                            // Redo Button
                            IconButton(
                              icon: const Icon(Icons.redo_rounded, size: 18),
                              tooltip: 'Redo',
                              onPressed: state.whiteboardRedoStack.isEmpty
                                  ? null
                                  : () {
                                      AppFeedback.light();
                                      context
                                          .read<LiveRoomCubit>()
                                          .redoWhiteboardStroke();
                                    },
                            ),

                            // Clear Canvas Button
                            IconButton(
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                size: 20,
                              ),
                              tooltip: 'Clear Board',
                              onPressed: state.whiteboardStrokes.isEmpty
                                  ? null
                                  : () => _confirmClearBoard(context),
                            ),
                          ],
                        ),

                        // Color Palette Row (shown if not eraser)
                        if (_currentTool != WhiteboardTool.eraser) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 26,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _palette.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final c = _palette[index];
                                final isChosen =
                                    _selectedColor.toARGB32() == c.toARGB32();
                                return GestureDetector(
                                  onTap: () {
                                    AppFeedback.selection();
                                    setState(() => _selectedColor = c);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: isChosen ? 24 : 18,
                                    height: isChosen ? 24 : 18,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isChosen
                                            ? colors.primary
                                            : Colors.white24,
                                        width: isChosen ? 2.5 : 1,
                                      ),
                                      boxShadow: isChosen
                                          ? [
                                              BoxShadow(
                                                color: c.withAlpha(120),
                                                blurRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubToolbar(AppThemeColorsExtension colors, bool isDark) {
    if (_currentTool == WhiteboardTool.pen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E222D).withAlpha(230)
              : colors.surfacePrimary.withAlpha(230),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.surfaceBorder.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stroke: ',
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            ..._penSizes.map((size) {
              final isChosen = _penStrokeWidth == size;
              return GestureDetector(
                onTap: () {
                  AppFeedback.selection();
                  setState(() => _penStrokeWidth = size);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isChosen ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${size.toInt()}px',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isChosen ? FontWeight.bold : FontWeight.normal,
                      color: isChosen ? Colors.white : colors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    } else if (_currentTool == WhiteboardTool.eraser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E222D).withAlpha(230)
              : colors.surfacePrimary.withAlpha(230),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.surfaceBorder.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Eraser size: ',
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            ..._eraserSizes.map((size) {
              final isChosen = _eraserStrokeWidth == size;
              return GestureDetector(
                onTap: () {
                  AppFeedback.selection();
                  setState(() => _eraserStrokeWidth = size);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isChosen ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${size.toInt()}px',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isChosen ? FontWeight.bold : FontWeight.normal,
                      color: isChosen ? Colors.white : colors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    } else if (_currentTool == WhiteboardTool.shape) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E222D).withAlpha(230)
              : colors.surfacePrimary.withAlpha(230),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.surfaceBorder.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShapeChip(
              icon: Icons.crop_square_rounded,
              label: 'Rect',
              isSelected: _currentShape == WhiteboardShape.rectangle,
              onTap: () => setState(
                () => _currentShape = WhiteboardShape.rectangle,
              ),
              colors: colors,
            ),
            _ShapeChip(
              icon: Icons.circle_outlined,
              label: 'Circle',
              isSelected: _currentShape == WhiteboardShape.circle,
              onTap: () => setState(() => _currentShape = WhiteboardShape.circle),
              colors: colors,
            ),
            _ShapeChip(
              icon: Icons.horizontal_rule_rounded,
              label: 'Line',
              isSelected: _currentShape == WhiteboardShape.line,
              onTap: () => setState(() => _currentShape = WhiteboardShape.line),
              colors: colors,
            ),
            _ShapeChip(
              icon: Icons.arrow_right_alt_rounded,
              label: 'Arrow',
              isSelected: _currentShape == WhiteboardShape.arrow,
              onTap: () => setState(() => _currentShape = WhiteboardShape.arrow),
              colors: colors,
            ),
            _ShapeChip(
              icon: Icons.change_history_rounded,
              label: 'Triangle',
              isSelected: _currentShape == WhiteboardShape.triangle,
              onTap: () => setState(
                () => _currentShape = WhiteboardShape.triangle,
              ),
              colors: colors,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeChip extends StatelessWidget {
  const _ShapeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppFeedback.selection();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  _WhiteboardPainter({
    required this.committedStrokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeStrokeWidth,
    required this.isEraser,
    required this.backgroundColor,
    this.activeShape,
  });

  final List<WhiteboardStroke> committedStrokes;
  final List<WhiteboardPoint> activePoints;
  final Color activeColor;
  final double activeStrokeWidth;
  final bool isEraser;
  final WhiteboardShape? activeShape;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw committed strokes, shapes, and text from all participants
    for (final stroke in committedStrokes) {
      if (stroke.isText) {
        _paintText(canvas, stroke);
      } else if (stroke.isShape) {
        _paintShape(canvas, stroke);
      } else {
        _paintFreehandStroke(canvas, stroke);
      }
    }

    // 2. Draw user's active in-progress drawing or shape preview
    if (activePoints.length >= 2) {
      if (activeShape != null) {
        _paintActiveShapePreview(canvas);
      } else {
        final activePaint = Paint()
          ..color = isEraser ? backgroundColor : activeColor
          ..strokeWidth = activeStrokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = Path()..moveTo(activePoints.first.x, activePoints.first.y);
        for (var i = 1; i < activePoints.length; i++) {
          path.lineTo(activePoints[i].x, activePoints[i].y);
        }
        canvas.drawPath(path, activePaint);
      }
    }
  }

  void _paintFreehandStroke(Canvas canvas, WhiteboardStroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.isEraser ? backgroundColor : Color(stroke.colorHex)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].x, stroke.points[i].y);
    }
    canvas.drawPath(path, paint);
  }

  void _paintShape(Canvas canvas, WhiteboardStroke stroke) {
    if (stroke.points.length < 2) return;
    final p1 = Offset(stroke.points.first.x, stroke.points.first.y);
    final p2 = Offset(stroke.points.last.x, stroke.points.last.y);

    final paint = Paint()
      ..color = Color(stroke.colorHex)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _drawShapeGeometry(canvas, stroke.shapeType ?? 'rectangle', p1, p2, paint);
  }

  void _paintActiveShapePreview(Canvas canvas) {
    if (activePoints.length < 2) return;
    final p1 = Offset(activePoints.first.x, activePoints.first.y);
    final p2 = Offset(activePoints.last.x, activePoints.last.y);

    final paint = Paint()
      ..color = activeColor
      ..strokeWidth = activeStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _drawShapeGeometry(canvas, activeShape!.name, p1, p2, paint);
  }

  void _drawShapeGeometry(
    Canvas canvas,
    String shapeName,
    Offset p1,
    Offset p2,
    Paint paint,
  ) {
    switch (shapeName) {
      case 'rectangle':
        final rect = Rect.fromPoints(p1, p2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          paint,
        );
      case 'circle':
        final rect = Rect.fromPoints(p1, p2);
        canvas.drawOval(rect, paint);
      case 'line':
        canvas.drawLine(p1, p2, paint);
      case 'arrow':
        canvas.drawLine(p1, p2, paint);
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final angle = math.atan2(dy, dx);
        final arrowSize = math.max(10, paint.strokeWidth * 3.5);

        final arrowP1 = Offset(
          p2.dx - arrowSize * math.cos(angle - math.pi / 6),
          p2.dy - arrowSize * math.sin(angle - math.pi / 6),
        );
        final arrowP2 = Offset(
          p2.dx - arrowSize * math.cos(angle + math.pi / 6),
          p2.dy - arrowSize * math.sin(angle + math.pi / 6),
        );

        final arrowPath = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(arrowP1.dx, arrowP1.dy)
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(arrowP2.dx, arrowP2.dy);
        canvas.drawPath(arrowPath, paint);
      case 'triangle':
        final rect = Rect.fromPoints(p1, p2);
        final trianglePath = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(trianglePath, paint);
      default:
        canvas.drawLine(p1, p2, paint);
    }
  }

  void _paintText(Canvas canvas, WhiteboardStroke stroke) {
    if (stroke.points.isEmpty || (stroke.text ?? '').isEmpty) return;

    final pos = Offset(stroke.points.first.x, stroke.points.first.y);
    final textSpan = TextSpan(
      text: stroke.text,
      style: TextStyle(
        color: Color(stroke.colorHex),
        fontSize: stroke.fontSize ?? 18,
        fontWeight: FontWeight.w600,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 320);

    // Optional background pill for crisp legibility
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        pos.dx - 4,
        pos.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );
    final bgPaint = Paint()
      ..color = Colors.black.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    return true;
  }
}

class _WhiteboardMinimap extends StatelessWidget {
  const _WhiteboardMinimap({
    required this.strokes,
    required this.transformationController,
    required this.onReset,
    required this.colors,
    required this.isDark,
  });

  final List<WhiteboardStroke> strokes;
  final TransformationController transformationController;
  final VoidCallback onReset;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReset,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1E222D) : colors.surfacePrimary)
              .withAlpha(220),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(150),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: transformationController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(80, 80),
                    painter: _MinimapPainter(
                      strokes: strokes,
                      matrix: transformationController.value,
                      isDark: isDark,
                      accentColor: colors.primary,
                    ),
                  );
                },
              ),
              Positioned(
                top: 4,
                left: 6,
                child: Text(
                  'Map',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary.withAlpha(160),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.strokes,
    required this.matrix,
    required this.isDark,
    required this.accentColor,
  });

  final List<WhiteboardStroke> strokes;
  final Matrix4 matrix;
  final bool isDark;
  final Color accentColor;

  static const double canvasDimension = 2800.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleFactor = size.width / canvasDimension;

    // Draw miniature strokes
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = Color(stroke.colorHex).withAlpha(180)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(
            stroke.points[0].x * scaleFactor,
            stroke.points[0].y * scaleFactor,
          ),
          0.8,
          strokePaint,
        );
      } else {
        for (int i = 0; i < stroke.points.length - 1; i++) {
          canvas.drawLine(
            Offset(
              stroke.points[i].x * scaleFactor,
              stroke.points[i].y * scaleFactor,
            ),
            Offset(
              stroke.points[i + 1].x * scaleFactor,
              stroke.points[i + 1].y * scaleFactor,
            ),
            strokePaint,
          );
        }
      }
    }

    // Draw current viewport indicator box
    final zoom = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    final viewWidth = (size.width / zoom) * (canvasDimension / 500.0) * scaleFactor;
    final viewHeight = (size.height / zoom) * (canvasDimension / 500.0) * scaleFactor;
    final viewX = (-translation.x / zoom) * scaleFactor;
    final viewY = (-translation.y / zoom) * scaleFactor;

    final viewRect = Rect.fromLTWH(
      viewX.clamp(0.0, size.width - 10),
      viewY.clamp(0.0, size.height - 10),
      viewWidth.clamp(10.0, size.width),
      viewHeight.clamp(10.0, size.height),
    );

    final viewPaint = Paint()
      ..color = accentColor.withAlpha(50)
      ..style = PaintingStyle.fill;
    final viewBorder = Paint()
      ..color = accentColor.withAlpha(200)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(viewRect, const Radius.circular(3)),
      viewPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(viewRect, const Radius.circular(3)),
      viewBorder,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}

