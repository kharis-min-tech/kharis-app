class RemoteConfigModel {
  final bool? forceUpdate;
  final int? localBuildNumber;
  final int? remoteBuildNumber;

  RemoteConfigModel({
    required this.forceUpdate,
    required this.localBuildNumber,
    required this.remoteBuildNumber,
  });
}
