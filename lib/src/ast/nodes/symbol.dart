import 'package:flutter/widgets.dart';

import '../../render/symbols/make_symbol.dart';
import '../../utils/unicode_literal.dart';
import '../options.dart';
import '../symbols/symbols.dart';
import '../symbols/symbols_composite.dart';
import '../symbols/symbols_extra.dart';
import '../symbols/symbols_unicode.dart';
import '../symbols/unicode_accents.dart';
import '../syntax_tree.dart';
import '../types.dart';
import 'accent.dart';

class SymbolNode extends LeafNode {
  final String symbol;
  final bool variantForm;
  AtomType _atomType;
  AtomType get atomType => _atomType ??=
      getDefaultAtomTypeForSymbol(symbol, variantForm: variantForm, mode: mode);
  final FontOptions overrideFont;

  final Mode mode;

  bool get noBreak => symbol == '\u00AF';

  SymbolNode({
    @required this.symbol,
    this.variantForm = false,
    AtomType atomType,
    this.overrideFont,
    this.mode = Mode.math,
  })  : assert(symbol.isNotEmpty),
        _atomType = atomType;

  @override
  BuildResult buildWidget(
      Options options, List<BuildResult> childBuildResults) {
    final expanded = symbol.runes.expand((code) {
      final ch = String.fromCharCode(code);
      return unicodeSymbols[ch]?.split('') ?? [ch];
    }).toList(growable: false);

    // If symbol is single code
    if (expanded.length == 1) {
      return makeBaseSymbol(
        symbol: expanded[0],
        variantForm: variantForm,
        atomType: atomType,
        overrideFont: overrideFont,
        mode: mode,
        options: options,
      );
    } else if (expanded.length > 1) {
      if (isCombiningMark(expanded[1])) {
        if (expanded[0] == 'i') {
          expanded[0] = '\u0131'; // dotless i, in math and text mode
        } else if (expanded[0] == 'j') {
          expanded[0] = '\u0237'; // dotless j, in math and text mode
        }
      }
      GreenNode res = this.copyWith(symbol: expanded[0]);
      for (var ch in expanded.skip(1)) {
        final accent = unicodeAccents[ch];
        if (accent == null) {
          break;
        } else {
          res = AccentNode(
            base: res.wrapWithEquationRow(),
            label: accent,
            isStretchy: false,
            isShifty: true,
          );
        }
      }
      return SyntaxNode(parent: null, value: res, pos: 0).buildWidget(options);
    } else {
      // TODO: log a warning here.
      return BuildResult(
        widget: Container(
          height: 0,
          width: 0,
        ),
        options: options,
        italic: 0,
      );
    }
  }

  @override
  bool shouldRebuildWidget(Options oldOptions, Options newOptions) =>
      oldOptions.mathFontOptions != newOptions.mathFontOptions ||
      oldOptions.textFontOptions != newOptions.textFontOptions ||
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier;

  @override
  AtomType get leftType => atomType;

  @override
  AtomType get rightType => atomType;

  @override
  Map<String, Object> toJson() => super.toJson()
    ..addAll({
      'mode': mode.toString(),
      'symbol': unicodeLiteral(symbol),
      if (variantForm) 'variantForm': variantForm,
      if (_atomType != null) 'atomType': _atomType.toString(),
    });

  SymbolNode copyWith({
    String symbol,
    bool variantForm,
    AtomType atomType,
    FontOptions overrideFont,
    Mode mode,
  }) =>
      SymbolNode(
        symbol: symbol ?? this.symbol,
        variantForm: variantForm ?? this.variantForm,
        atomType: _atomType ?? this._atomType,
        overrideFont: overrideFont ?? this.overrideFont,
        mode: mode ?? this.mode,
      );
}

EquationRowNode stringToNode(String string, [Mode mode = Mode.text]) =>
    EquationRowNode(
      children: string
          .split('')
          .map((ch) => SymbolNode(symbol: ch, mode: mode))
          .toList(growable: false),
    );

AtomType getDefaultAtomTypeForSymbol(
  String symbol, {
  bool variantForm = false,
  @required Mode mode,
}) {
  var symbolRenderConfig = symbolRenderConfigs[symbol];
  if (variantForm) {
    symbolRenderConfig = symbolRenderConfig?.variantForm;
  }
  final renderConfig =
      mode == Mode.math ? symbolRenderConfig?.math : symbolRenderConfig?.text;
  if (renderConfig != null) {
    return renderConfig.defaultType;
  }
  if (variantForm == false && mode == Mode.math) {
    if (negatedOperatorSymbols.containsKey(symbol)) {
      return AtomType.rel;
    }
    if (compactedCompositeSymbols.containsKey(symbol)) {
      return compactedCompositeSymbolTypes[symbol];
    }
    if (decoratedEqualSymbols.contains(symbol)) {
      return AtomType.rel;
    }
  }
  return AtomType.ord;
}

bool isCombiningMark(String ch) {
  final code = ch.codeUnitAt(0);
  return code >= 0x0300 && code <= 0x036f;
}
