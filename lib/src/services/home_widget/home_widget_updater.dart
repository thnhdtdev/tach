import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../photo/photo_compressor.dart';

enum WidgetBalanceTone { owe, owed, even }

/// Những gì widget màn hình chính hiện. Chữ và số tiền đã định dạng sẵn để
/// phần native chỉ việc hiện.
@immutable
class WidgetContent {
  const WidgetContent({
    required this.group,
    required this.balanceLabel,
    required this.balanceTone,
    this.balanceAmount,
    this.expenseId,
    this.payerInitial,
    this.payerTone,
    this.avatarKey,
    this.note,
    this.amountShort,
    this.amountFull,
    this.hasPhoto = false,
  });

  final String group;

  final String balanceLabel;
  final String? balanceAmount;
  final WidgetBalanceTone balanceTone;

  /// Khoản chi mới nhất của nhóm; các trường này `null` khi nhóm chưa có khoản.
  final String? expenseId;

  /// Chữ cái đầu tên và màu nền ("RRGGBB") của avatar người ghi, dùng khi họ
  /// chưa đặt ảnh đại diện.
  final String? payerInitial;
  final String? payerTone;

  /// Đổi khi ảnh đại diện của người ghi đổi; `null` khi họ không có ảnh.
  final int? avatarKey;
  final String? note;
  final String? amountShort;
  final String? amountFull;
  final bool hasPhoto;

  Map<String, Object?> toJson() => {
    'group': group,
    'payerInitial': payerInitial,
    'payerTone': payerTone,
    'note': note,
    'amountShort': amountShort,
    'amountFull': amountFull,
    'balanceLabel': balanceLabel,
    'balanceAmount': balanceAmount,
    'balanceTone': balanceTone.name,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetContent &&
      other.expenseId == expenseId &&
      other.hasPhoto == hasPhoto &&
      other.avatarKey == avatarKey &&
      mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(expenseId, hasPhoto, group, balanceAmount);
}

abstract interface class HomeWidgetUpdater {
  /// `null` đưa widget về trạng thái trống (đã đăng xuất hoặc chưa có nhóm).
  Future<void> show(
    WidgetContent? content, {
    Uint8List? photo,
    Uint8List? avatar,
  });
}

class NoHomeWidgetUpdater implements HomeWidgetUpdater {
  @override
  Future<void> show(
    WidgetContent? content, {
    Uint8List? photo,
    Uint8List? avatar,
  }) async {}
}

class SystemHomeWidgetUpdater implements HomeWidgetUpdater {
  /// Phải khớp với App Group trong `Runner.entitlements` và
  /// `TachWidget.entitlements`, và với tên widget trong `TachWidget.swift`.
  static const _appGroup = 'group.vn.tachapp.tach';
  static const _widgetKind = 'TachWidget';

  // Widget cỡ nhỏ rộng chừng 170 điểm, tức 510 điểm ảnh ở màn 3x.
  static const _photoSide = 480;
  static const _avatarSide = 96;

  @override
  Future<void> show(
    WidgetContent? content, {
    Uint8List? photo,
    Uint8List? avatar,
  }) async {
    await HomeWidget.setAppGroupId(_appGroup);
    await HomeWidget.saveWidgetData<String>(
      'content',
      content == null ? null : jsonEncode(content.toJson()),
      deleteFile: false,
    );
    await HomeWidget.saveWidgetData<Uint8List>(
      'photo',
      photo == null
          ? null
          : await squareJpeg(photo, side: _photoSide, quality: 80),
      deleteFile: false,
    );
    await HomeWidget.saveWidgetData<Uint8List>(
      'avatar',
      avatar == null
          ? null
          : await squareJpeg(avatar, side: _avatarSide, quality: 80),
      deleteFile: false,
    );
    await HomeWidget.updateWidget(iOSName: _widgetKind);
  }
}
