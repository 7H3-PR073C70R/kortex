// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as _svg;
import 'package:vector_graphics/vector_graphics.dart' as _vg;

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/.gitkeep
  String get aGitkeep => 'assets/icons/.gitkeep';

  /// File path: assets/icons/app_icon_development.png
  AssetGenImage get appIconDevelopment =>
      const AssetGenImage('assets/icons/app_icon_development.png');

  /// File path: assets/icons/app_icon_production.png
  AssetGenImage get appIconProduction =>
      const AssetGenImage('assets/icons/app_icon_production.png');

  /// File path: assets/icons/app_icon_staging.png
  AssetGenImage get appIconStaging =>
      const AssetGenImage('assets/icons/app_icon_staging.png');

  /// List of all assets
  List<dynamic> get values => [
    aGitkeep,
    appIconDevelopment,
    appIconProduction,
    appIconStaging,
  ];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/.gitkeep
  String get aGitkeep => 'assets/images/.gitkeep';

  /// File path: assets/images/campus_student_bg.png
  AssetGenImage get campusStudentBg =>
      const AssetGenImage('assets/images/campus_student_bg.png');

  /// File path: assets/images/syllabot_avatar.png
  AssetGenImage get syllabotAvatar =>
      const AssetGenImage('assets/images/syllabot_avatar.png');

  /// List of all assets
  List<dynamic> get values => [aGitkeep, campusStudentBg, syllabotAvatar];
}

class $AssetsSvgsGen {
  const $AssetsSvgsGen();

  /// File path: assets/svgs/.gitkeep
  String get aGitkeep => 'assets/svgs/.gitkeep';

  /// File path: assets/svgs/kortex_logo.svg
  SvgGenImage get kortexLogo =>
      const SvgGenImage('assets/svgs/kortex_logo.svg');

  /// File path: assets/svgs/onboarding_ingestion.svg
  SvgGenImage get onboardingIngestion =>
      const SvgGenImage('assets/svgs/onboarding_ingestion.svg');

  /// File path: assets/svgs/onboarding_ocr.svg
  SvgGenImage get onboardingOcr =>
      const SvgGenImage('assets/svgs/onboarding_ocr.svg');

  /// File path: assets/svgs/onboarding_retention.svg
  SvgGenImage get onboardingRetention =>
      const SvgGenImage('assets/svgs/onboarding_retention.svg');

  /// File path: assets/svgs/onboarding_socratic.svg
  SvgGenImage get onboardingSocratic =>
      const SvgGenImage('assets/svgs/onboarding_socratic.svg');

  /// List of all assets
  List<dynamic> get values => [
    aGitkeep,
    kortexLogo,
    onboardingIngestion,
    onboardingOcr,
    onboardingRetention,
    onboardingSocratic,
  ];
}

abstract final class AppAssets {
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsSvgsGen svgs = $AssetsSvgsGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}

class SvgGenImage {
  const SvgGenImage(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = false;

  const SvgGenImage.vec(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = true;

  final String _assetName;
  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;

  _svg.SvgPicture svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    _svg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    final _svg.BytesLoader loader;
    if (_isVecFormat) {
      loader = _vg.AssetBytesLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
      );
    } else {
      loader = _svg.SvgAssetLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
        colorMapper: colorMapper,
      );
    }
    return _svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter:
          colorFilter ??
          (color == null ? null : ColorFilter.mode(color, colorBlendMode)),
      clipBehavior: clipBehavior,
      cacheColorFilter: cacheColorFilter,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
