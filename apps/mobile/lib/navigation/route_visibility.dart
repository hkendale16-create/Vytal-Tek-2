import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// True when [path] is the visible GoRouter location (overlays sit on root).
bool isCurrentRoutePath(BuildContext context, String path) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return true;
  return router.routerDelegate.currentConfiguration.uri.path == path;
}
