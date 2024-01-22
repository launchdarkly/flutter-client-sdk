import 'package:launchdarkly_dart_common/ld_common.dart';

import '../persistence/persistence.dart';
import 'context_modifier.dart';
import 'utils.dart';

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
  final EnvironmentReporter _envReporter;
  final LDLogger _logger;

  AutoEnvContextModifier(EnvironmentReporter environmentReporter,
      Persistence persistence, LDLogger logger)
      : _envReporter = environmentReporter,
        _persistence = persistence,
        _logger = logger;

  @override
  Future<LDContext> decorate(LDContext context) async {
    final builder = LDContextBuilder.fromContext(context);

    final recipes = await _makeRecipeList();
    for (final recipe in recipes) {
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

  Future<Iterable<_ContextRecipe>> _makeRecipeList() async {
    // TODO: in some platforms, APIs are called twice, optimize performance since
    // the environment reporter is likely to be invoked in the startup phase of
    // client applications.  Current tests: 3ms on Chrome, 11ms on physical Android,
    // 400-500ms on physical iPad, 200ms on iPhone emulator, 160ms on macOS

    final appInfo = await _envReporter.applicationInfo;
    final deviceInfo = await _envReporter.deviceInfo;
    final osInfo = await _envReporter.osInfo;
    final locale = await _envReporter.locale;

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
        () => getOrGenerateKey(_persistence, AutoEnvConsts.ldDeviceKind),
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
    final attributesBuilder = singleContextBuilder.kind(kind, await getKeyFunc());

    // adapter is used to make builder look like a writeable map for the nodes
    // to write themselves into it.
    final adaptedBuilder = _LDAttributesBuilderAdapter(attributesBuilder);

    // this will tell us if any nodes were written successfully as it iterates.
    final wroteANode = recipeNodes.fold(false,
        (wroteANode, node) => wroteANode | node.tryWrite(adaptedBuilder));

    // if any of the nodes are able to write themselves, include the version
    // and add the context
    if (wroteANode) {
      attributesBuilder.set(AutoEnvConsts.envAttributesVersion,
          LDValue.ofString(AutoEnvConsts.specVersion));
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
      settableMap.set(_key, _value!);
      return true;
    }

    if (_children == null) return false;

    final objBuilder = LDValue.buildObject();
    final adaptedBuilder = _ObjectBuilderAdapter(objBuilder);

    final wroteANode = _children!.fold(false,
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
    _underlyingBuilder.set(attributeName, value);
  }
}
