/// 인증 래퍼 위젯
/// 로그인 상태에 따라 LoginPage 또는 메인 화면을 표시합니다.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../../common.dart';
import './login_page.dart';
import './desktop_tab_page.dart';

/// 인증 상태에 따라 적절한 페이지를 표시하는 래퍼 위젯
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WindowListener {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initCheck();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initCheck() async {
    // 약간의 딜레이를 주어 userModel이 초기화될 시간을 줌
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onLoginSuccess() {
    setState(() {});
  }

  @override
  void onWindowClose() {
    // 로그인 상태 확인
    final isLoggedIn = gFFI.userModel.userName.isNotEmpty ||
                       gFFI.userModel.userEmail.isNotEmpty;

    if (!isLoggedIn) {
      // 로그인하지 않은 상태에서는 앱 종료
      exit(0);
    }
    // 로그인 상태에서는 DesktopTab의 WindowListener가 처리함
    // (hide 동작)
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Obx를 사용하여 userModel의 userName 변화를 감지
    return Obx(() {
      final isLoggedIn = gFFI.userModel.userName.isNotEmpty ||
                         gFFI.userModel.userEmail.isNotEmpty;

      if (isLoggedIn) {
        return const DesktopTabPage();
      } else {
        return LoginPage(onLoginSuccess: _onLoginSuccess);
      }
    });
  }
}
