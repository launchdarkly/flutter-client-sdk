import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../persistence/persistence.dart';
import 'context_modifier.dart';
import 'utils.dart';

const _autoEnvContextKeyNamespace = 'LaunchDarkly_AutoEnvContextKey';

final class AutoEnvConsts {
  static const String ldApplicationKind = 'ld_application';
  static const String ldDeviceKind = 'ld_device';
  static const String attrId = 'id';
  static const String attrName = 'name';
  static const String attrVersion = 'version';
  static const String attrVersionName = 'versionName';
  static const String attrManufacturer = 'manufacturer';
  static const String attrModel = 'model';
  static const String attrLocale = 'locale';
  static const String attrOs = 'os';
  static const String attrFamily = 'family';
  static const String envAttributesVersion = 'envAttributesVersion';
  static const String specVersion = '1.0';
}

/// A modifier that adds contexts/kinds to the provided context using collected
/// data from various sources including the provided [EnvironmentReporter].  For
/// certain context kinds, persistent data made be read/written to the provided
/// [Persistence].
final class AutoEnvContextModifier implements ContextModifier {
  final Persistence _persistence;
  final EnvironmentReport _envReport;
  final LDLogger _logger;
  late final Iterable<_ContextRecipe> _recipes;

  AutoEnvContextModifier(EnvironmentReport environmentReporter,
      Persistence persistence, LDLogger logger)
      : _envReport = environmentReporter,
        _persistence = persistence,
        _logger = logger {
    _recipes = _makeRecipeList();
  }

  @override
  Future<LDContext> decorate(LDContext context) async {
    if (!context.valid) {
      _logger.warn(
          'AutoEnvContextModifier was asked to modify an invalid context and will attempt to do so. This is expected if starting with an empty context.');
    }

    final builder = LDContextBuilder.fromContext(context);

    for (final recipe in _recipes) {
      // test if the recipe kind already is in the context.
      // 'keys' map is keyed by kinds
      if (!context.keys.containsKey(recipe.kind)) {
        await recipe.tryWrite(builder);
      } else {
        _logger.warn(
            'Unable to automatically add environment attributes for kind:${recipe.kind}. ${recipe.kind} already exists.');
      }
    }

    return builder.build();
  }

  LDValue _asLDValue(String? s) {
    if (s != null) {
      return LDValue.ofString(s);
    } else {
      return LDValue.ofNull();
    }
  }

  Iterable<_ContextRecipe> _makeRecipeList() {
    final appInfo = _envReport.applicationInfo;
    final deviceInfo = _envReport.deviceInfo;
    final osInfo = _envReport.osInfo;
    final locale = _envReport.locale;

    final applicationNodes = [
      _Node(AutoEnvConsts.attrId, _asLDValue(appInfo?.applicationId)),
      _Node(AutoEnvConsts.attrName, _asLDValue(appInfo?.applicationName)),
      _Node(AutoEnvConsts.attrVersion, _asLDValue(appInfo?.applicationVersion)),
      _Node(AutoEnvConsts.attrVersionName,
          _asLDValue(appInfo?.applicationVersionName)),
      _Node(AutoEnvConsts.attrLocale, _asLDValue(locale)),
    ];

    final deviceNodes = [
      _Node(
          AutoEnvConsts.attrManufacturer, _asLDValue(deviceInfo?.manufacturer)),
      _Node(AutoEnvConsts.attrModel, _asLDValue(deviceInfo?.model)),
      _Node.withChildren(AutoEnvConsts.attrOs, [
        _Node(AutoEnvConsts.attrFamily, _asLDValue(osInfo?.family)),
        _Node(AutoEnvConsts.attrName, _asLDValue(osInfo?.name)),
        _Node(AutoEnvConsts.attrVersion, _asLDValue(osInfo?.version)),
      ]),
    ];

    return [
      _ContextRecipe(
        AutoEnvConsts.ldApplicationKind,
        () => Future.value(urlSafeSha256Hash(appInfo?.applicationId ?? '')),
        applicationNodes,
      ),
      _ContextRecipe(
        AutoEnvConsts.ldDeviceKind,
        () => getOrGenerateKey(_persistence, _autoEnvContextKeyNamespace,
            AutoEnvConsts.ldDeviceKind),
        deviceNodes,
      ),
    ];
  }
}

class _ContextRecipe {
  final String kind;
  final Future<String> Function() getKeyFunc;
  final List<_Node> recipeNodes;

  _ContextRecipe(this.kind, this.getKeyFunc, this.recipeNodes);

  Future<void> tryWrite(LDContextBuilder builder) async {
    final singleContextBuilder = LDContextBuilder();
    final attributesBuilder =
        singleContextBuilder.kind(kind, await getKeyFunc());

    // adapter is used to make builder look like a writeable map for the nodes
    // to write themselves into it.
    final adaptedBuilder = _LDAttributesBuilderAdapter(attributesBuilder);

    // this will tell us if any nodes were written successfully as it iterates.
    final wroteANode = recipeNodes.fold(false,
        (wroteANode, node) => wroteANode | node.tryWrite(adaptedBuilder));

    // if any of the nodes are able to write themselves, include the version
    // and add the context
    if (wroteANode) {
      attributesBuilder.setString(
          AutoEnvConsts.envAttributesVersion, AutoEnvConsts.specVersion);
      builder.mergeContext(singleContextBuilder.build());
    }
  }
}

class _Node {
  final String _key;
  final LDValue? _value;
  final List<_Node>? _children;

  _Node(this._key, LDValue value)
      : _value = value,
        _children = null;

  _Node.withChildren(this._key, List<_Node> children)
      : _value = null,
        _children = children;

  bool tryWrite(_ISettableMap settableMap) {
    if (_value != null && _value != LDValue.ofNull()) {
      settableMap.set(_key, _value);
      return true;
    }

    if (_children == null) return false;

    final objBuilder = LDValue.buildObject();
    final adaptedBuilder = _ObjectBuilderAdapter(objBuilder);

    final wroteANode = _children.fold(false,
        (wroteANode, node) => wroteANode | node.tryWrite(adaptedBuilder));

    if (!wroteANode) return false;

    // only add the structure if at least one child was written.
    settableMap.set(_key, objBuilder.build());
    return true;
  }
}

abstract class _ISettableMap {
  void set(String attributeName, LDValue value);
}

class _ObjectBuilderAdapter implements _ISettableMap {
  final LDValueObjectBuilder _underlyingBuilder;

  _ObjectBuilderAdapter(this._underlyingBuilder);

  @override
  void set(String attributeName, LDValue value) {
    _underlyingBuilder.addValue(attributeName, value);
  }
}

class _LDAttributesBuilderAdapter implements _ISettableMap {
  final LDAttributesBuilder _underlyingBuilder;

  _LDAttributesBuilderAdapter(this._underlyingBuilder);

  @override
  void set(String attributeName, LDValue value) {
    _underlyingBuilder.setValue(attributeName, value);
  }
}
