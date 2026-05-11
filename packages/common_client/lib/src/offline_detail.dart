/// Details for [ResolvedOffline] to help consumers make decisions (e.g. status
/// reporting).
sealed class OfflineDetail {
  const OfflineDetail();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OfflineDetail &&
        switch ((this, other)) {
          (OfflineSetOffline(), OfflineSetOffline()) => true,
          (OfflineNetworkUnavailable(), OfflineNetworkUnavailable()) => true,
          (OfflineBackgroundDisabled(), OfflineBackgroundDisabled()) => true,
          _ => false,
        };
  }

  @override
  int get hashCode => switch (this) {
        OfflineSetOffline() => 0,
        OfflineNetworkUnavailable() => 1,
        OfflineBackgroundDisabled() => 2,
      };
}

/// Offline because the application or client chose not to connect (including
/// explicit SDK offline and connection mode override to offline).
/// Corresponds to [DataSourceState.setOffline].
final class OfflineSetOffline extends OfflineDetail {
  const OfflineSetOffline();
}

/// Offline because automatic resolution detected no usable network.
/// Corresponds to [DataSourceState.networkUnavailable].
final class OfflineNetworkUnavailable extends OfflineDetail {
  const OfflineNetworkUnavailable();
}

/// Offline because the app is backgrounded and background updates are
/// disabled. Corresponds to [DataSourceState.backgroundDisabled].
final class OfflineBackgroundDisabled extends OfflineDetail {
  const OfflineBackgroundDisabled();
}
