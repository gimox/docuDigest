// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ocr_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ocrConnectionStatusHash() =>
    r'63204e4c9ba34a997aa7a08e896f736b73beccfc';

/// See also [ocrConnectionStatus].
@ProviderFor(ocrConnectionStatus)
final ocrConnectionStatusProvider = AutoDisposeStreamProvider<bool>.internal(
  ocrConnectionStatus,
  name: r'ocrConnectionStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ocrConnectionStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OcrConnectionStatusRef = AutoDisposeStreamProviderRef<bool>;
String _$ocrSettingsNotifierHash() =>
    r'6067271ce2c0710ca493958a7415e7e8c5329117';

/// See also [OcrSettingsNotifier].
@ProviderFor(OcrSettingsNotifier)
final ocrSettingsNotifierProvider =
    AutoDisposeNotifierProvider<OcrSettingsNotifier, OcrSettings>.internal(
      OcrSettingsNotifier.new,
      name: r'ocrSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$ocrSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OcrSettingsNotifier = AutoDisposeNotifier<OcrSettings>;
String _$workspaceNotifierHash() => r'c56f0d13f65301cc55e0e074b73997289d68066b';

/// See also [WorkspaceNotifier].
@ProviderFor(WorkspaceNotifier)
final workspaceNotifierProvider =
    AutoDisposeNotifierProvider<WorkspaceNotifier, WorkspaceState>.internal(
      WorkspaceNotifier.new,
      name: r'workspaceNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$workspaceNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WorkspaceNotifier = AutoDisposeNotifier<WorkspaceState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
