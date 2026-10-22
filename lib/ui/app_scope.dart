import 'package:flutter/widgets.dart';

import '../core_bridge.dart';

enum FormFactor { phone, wide, television }

const televisionInset = 58.0;

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.television,
    this.desktop = false,
    this.systemColorAvailable = false,
    this.version = '',
    required super.child,
  });
  final AppRepository repository;
  final bool television;
  final bool desktop;
  final bool systemColorAvailable;
  final String version;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static FormFactor formFactorOf(BuildContext context) {
    if (of(context).television) return FormFactor.television;
    return MediaQuery.sizeOf(context).width >= 600
        ? FormFactor.wide
        : FormFactor.phone;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository ||
      television != oldWidget.television ||
      desktop != oldWidget.desktop ||
      systemColorAvailable != oldWidget.systemColorAvailable ||
      version != oldWidget.version;
}
