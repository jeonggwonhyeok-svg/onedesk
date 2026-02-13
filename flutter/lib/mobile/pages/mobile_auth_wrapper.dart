/// 모바일용 인증 래퍼 위젯
/// 로그인 상태에 따라 LoginPage 또는 HomePage를 표시합니다.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../desktop/pages/login_page.dart';
import './home_page.dart';

/// 인증 상태에 따라 적절한 페이지를 표시하는 래퍼 위젯
class MobileAuthWrapper extends StatefulWidget {
  const MobileAuthWrapper({Key? key}) : super(key: key);

  @override
  State<MobileAuthWrapper> createState() => _MobileAuthWrapperState();
}

class _MobileAuthWrapperState extends State<MobileAuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCheck();
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
        return HomePage();
      } else {
        return LoginPage(onLoginSuccess: _onLoginSuccess);
      }
    });
  }
}
