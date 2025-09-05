// flip_page_route.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlipPageRoute<T> extends PageRouteBuilder<T> {
  FlipPageRoute({
    required Widget child,
    Duration duration = const Duration(milliseconds: 650),
    Curve curve = Curves.easeOutCubic,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         pageBuilder: (_, __, ___) => child,
         transitionsBuilder: (_, animation, __, child) {
           final angle = Tween<double>(
             begin: math.pi / 2,
             end: 0,
           ).animate(CurvedAnimation(parent: animation, curve: curve));

           return AnimatedBuilder(
             animation: angle,
             builder: (context, _) {
               final m =
                   Matrix4.identity()
                     ..setEntry(3, 2, 0.001) // 透視
                     ..rotateY(angle.value); // Y 軸翻轉

               // 加一點陰影讓翻頁更像紙
               final darkness = (1 - (angle.value / (math.pi / 2))).clamp(
                 0.0,
                 1.0,
               );

               return Stack(
                 children: [
                   // 背景微暗，避免閃白
                   ColoredBox(color: Colors.black.withOpacity(0.15 * darkness)),
                   Transform(
                     alignment: Alignment.centerLeft,
                     transform: m,
                     child: DecoratedBox(
                       decoration: BoxDecoration(
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.25 * darkness),
                             blurRadius: 18,
                             spreadRadius: 2,
                           ),
                         ],
                       ),
                       child: child,
                     ),
                   ),
                 ],
               );
             },
           );
         },
       );
}
