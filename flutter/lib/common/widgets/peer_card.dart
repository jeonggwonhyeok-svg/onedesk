import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/common/widgets/status_badge.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../models/peer_model.dart';
import '../../models/platform_model.dart';
import '../../desktop/widgets/material_mod_popup_menu.dart' as mod_menu;
import '../../desktop/widgets/popup_menu.dart';
import 'dart:math' as math;

typedef PopupMenuEntryBuilder = Future<List<mod_menu.PopupMenuEntry<String>>>
    Function(BuildContext);

/// 피어 카드 표시 타입
/// Peer card display type
enum PeerUiType { grid, tile, list }

/// 현재 선택된 UI 타입 (기본: grid)
/// Currently selected UI type (default: grid)
final peerCardUiType = PeerUiType.grid.obs;

/// 카드에서 사용자 이름을 숨길지 여부
/// Whether to hide username on card
bool? hideUsernameOnCard;

/// 피어 카드 위젯 (원격 PC 접속 카드)
/// Peer card widget (remote PC connection card)
class _PeerCard extends StatefulWidget {
  final Peer peer; // 피어 정보 (ID, 이름, 상태 등)
  final PeerTabIndex tab; // 현재 탭 (최근 접속, 즐겨찾기 등)
  final Function(BuildContext, String) connect; // 접속 함수
  final PopupMenuEntryBuilder popupMenuEntryBuilder; // 우클릭 메뉴

  const _PeerCard(
      {required this.peer,
      required this.tab,
      required this.connect,
      required this.popupMenuEntryBuilder,
      Key? key})
      : super(key: key);

  @override
  _PeerCardState createState() => _PeerCardState();
}

/// 피어 카드 State 클래스
/// Peer card state class
class _PeerCardState extends State<_PeerCard>
    with AutomaticKeepAliveClientMixin {
  var _menuPos = RelativeRect.fill; // 팝업 메뉴 위치
  final double _tileRadius = 5; // 타일/리스트 모서리 반경

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 세로/가로 모드에 따라 다른 레이아웃 표시
    return Obx(() =>
        stateGlobal.isPortrait.isTrue ? _buildPortrait() : _buildLandscape());
  }

  /// 제스처 감지 래퍼 (클릭, 더블클릭, 길게 누르기)
  /// Gesture detector wrapper (click, double-click, long-press)
  Widget gestureDetector({required Widget child}) {
    final PeerTabModel peerTabModel = Provider.of(context);
    final peer = super.widget.peer;
    return GestureDetector(
        onDoubleTap: peerTabModel.multiSelectionMode
            ? null
            : () => widget.connect(context, peer.id), // 더블클릭: 접속
        onTap: () {
          if (peerTabModel.multiSelectionMode) {
            peerTabModel.select(peer); // 다중 선택 모드: 선택/해제
          } else {
            if (isMobile) {
              widget.connect(context, peer.id); // 모바일: 한 번 클릭으로 접속
            } else {
              peerTabModel.select(peer); // 데스크톱: 선택
            }
          }
        },
        onLongPress: () => peerTabModel.select(peer), // 길게 누르기: 선택
        child: child);
  }

  /// 세로 모드 레이아웃 (모바일)
  /// Portrait mode layout (mobile)
  Widget _buildPortrait() {
    final peer = super.widget.peer;
    return Card(
        margin: EdgeInsets.symmetric(horizontal: 2),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF2F1F6), width: 1),
        ),
        color: Colors.transparent,
        child: gestureDetector(
          child: Container(
              padding: EdgeInsets.only(left: 0, top: 0, bottom: 0),
              child: _buildMobilePeerTile(context, peer)),
        ));
  }

  /// 모바일 전용 피어 타일 빌드
  /// Mobile-specific peer tile build
  Widget _buildMobilePeerTile(BuildContext context, Peer peer) {
    hideUsernameOnCard ??=
        bind.mainGetBuildinOption(key: kHideUsernameOnCard) == 'Y';
    final name = hideUsernameOnCard == true
        ? peer.hostname
        : '${peer.username}${peer.username.isNotEmpty && peer.hostname.isNotEmpty ? '@' : ''}${peer.hostname}';

    const leftBgColor = Color(0xFFEFF1FF); // 왼쪽: 연보라색
    const rightBgColor = Color(0xFFFEFEFE); // 오른쪽: 흰색
    const logoColor = Color(0xFF5F71FF);
    const codeTextColor = Color(0xFF646368);
    const otherTextColor = Color(0xFF8F8E95);

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // 왼쪽: 시스템 로고 영역
        Container(
          decoration: const BoxDecoration(
            color: leftBgColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          alignment: Alignment.center,
          width: 80,
          height: 80,
          child: Stack(
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  logoColor,
                  BlendMode.srcIn,
                ),
                child: getPlatformImage(peer.platform, size: 30),
              ).paddingAll(6),
              if (_shouldBuildPasswordIcon(peer))
                Positioned(
                  top: 1,
                  left: 1,
                  child: Icon(Icons.key, size: 6, color: Colors.white),
                ),
            ],
          ),
        ),
        // 오른쪽: 정보 영역
        Expanded(
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              color: rightBgColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 코드 (ID)
                      Row(children: [
                        getOnline(4, peer.online),
                        Expanded(
                          child: Text(
                            '[${peer.alias.isEmpty ? formatID(peer.id) : peer.alias}]',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: codeTextColor,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      // 사용자명@호스트명
                      Text(
                        '[$name]',
                        style: const TextStyle(
                          fontSize: 15,
                          color: otherTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                checkBoxOrActionMorePortrait(peer),
              ],
            ).paddingSymmetric(horizontal: 12.0),
          ),
        )
      ],
    );
  }

  /// 가로 모드 레이아웃 (데스크톱)
  /// Landscape mode layout (desktop)
  Widget _buildLandscape() {
    final peer = super.widget.peer;
    final theme = MyTheme.peerCard(context);
    // 호버 시 테두리 효과
    var deco = Rx<BoxDecoration?>(
      BoxDecoration(
        border: Border.all(color: Colors.transparent, width: theme.borderWidth),
        borderRadius: BorderRadius.circular(theme.cardRadius),
      ),
    );
    return MouseRegion(
      onEnter: (evt) {
        // 마우스 진입: 파란 테두리 표시
        deco.value = BoxDecoration(
          border: Border.all(
              color: theme.hoverBorderColor, width: theme.borderWidth),
          borderRadius: BorderRadius.circular(theme.cardRadius),
        );
      },
      onExit: (evt) {
        // 마우스 나감: 테두리 제거
        deco.value = BoxDecoration(
          border:
              Border.all(color: Colors.transparent, width: theme.borderWidth),
          borderRadius: BorderRadius.circular(theme.cardRadius),
        );
      },
      child: gestureDetector(
          child: Obx(() => peerCardUiType.value == PeerUiType.grid
              ? _buildPeerCard(context, peer, deco) // 그리드 카드 (큰 카드)
              : _buildPeerTile(context, peer, deco))), // 타일/리스트 (작은 카드)
    );
  }

  bool _showNote(Peer peer) {
    return peerTabShowNote(widget.tab) && peer.note.isNotEmpty;
  }

  makeChild(bool isPortrait, Peer peer, PeerCardTheme theme) {
    final name = hideUsernameOnCard == true
        ? peer.hostname
        : '${peer.username}${peer.username.isNotEmpty && peer.hostname.isNotEmpty ? '@' : ''}${peer.hostname}';
    final showNote = _showNote(peer);

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
            decoration: BoxDecoration(
              // 그리드 뷰와 동일한 배경색 적용
              // Apply same background color as grid view
              color: theme.topBackgroundColor,
              borderRadius: isPortrait
                  ? BorderRadius.circular(_tileRadius)
                  : BorderRadius.only(
                      topLeft: Radius.circular(theme.cardRadius),
                      bottomLeft: Radius.circular(theme.cardRadius),
                    ),
            ),
            alignment: Alignment.center,
            width: isPortrait ? 50 : 80,
            height: isPortrait ? 50 : null,
            child: Stack(
              children: [
                // 시스템 아이콘에 보라색 적용 (grid와 동일)
                // Apply purple color to system icon (same as grid)
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    theme.accentColor,
                    BlendMode.srcIn,
                  ),
                  child: getPlatformImage(peer.platform,
                      size: isPortrait ? 38 : 32),
                ).paddingAll(6),
                if (_shouldBuildPasswordIcon(peer))
                  Positioned(
                    top: 1,
                    left: 1,
                    child: Icon(Icons.key, size: 6, color: Colors.white),
                  ),
              ],
            )),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.bottomBackgroundColor,
              border: Border.all(
                color: theme.borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(theme.cardRadius),
                bottomRight: Radius.circular(theme.cardRadius),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        getOnline(isPortrait ? 4 : 8, peer.online),
                        Expanded(
                            child: Text(
                          '[${peer.alias.isEmpty ? formatID(peer.id) : peer.alias}]',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                      ]),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Tooltip(
                              message: name,
                              waitDuration: const Duration(seconds: 1),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '[$name]',
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          if (showNote)
                            Expanded(
                              child: Tooltip(
                                message: peer.note,
                                waitDuration: const Duration(seconds: 1),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    peer.note,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.noteTextColor,
                                    ),
                                    textAlign: TextAlign.start,
                                    overflow: TextOverflow.ellipsis,
                                  ).marginOnly(
                                      left: peerCardUiType.value ==
                                              PeerUiType.list
                                          ? 32
                                          : 4),
                                ),
                              ),
                            )
                        ],
                      ),
                    ],
                  ),
                ),
                isPortrait
                    ? checkBoxOrActionMorePortrait(peer)
                    : checkBoxOrActionMoreLandscape(peer, isTile: true),
              ],
            ).paddingSymmetric(horizontal: 12.0),
          ),
        )
      ],
    );
  }

  Widget _buildPeerTile(
      BuildContext context, Peer peer, Rx<BoxDecoration?>? deco) {
    hideUsernameOnCard ??=
        bind.mainGetBuildinOption(key: kHideUsernameOnCard) == 'Y';
    final theme = MyTheme.peerCard(context);
    final colors = _frontN(peer.tags, 25)
        .map((e) => gFFI.abModel.getCurrentAbTagColor(e))
        .toList();
    return Tooltip(
      message: !(isDesktop || isWebDesktop)
          ? ''
          : peer.tags.isNotEmpty
              ? '${translate('Tags')}: ${peer.tags.join(', ')}'
              : '',
      child: Stack(children: [
        Obx(
          () => deco == null
              ? makeChild(stateGlobal.isPortrait.isTrue, peer, theme)
              : Container(
                  foregroundDecoration: deco.value,
                  child: makeChild(stateGlobal.isPortrait.isTrue, peer, theme),
                ),
        ),
        if (colors.isNotEmpty)
          Obx(() => Positioned(
                top: 2,
                right: stateGlobal.isPortrait.isTrue ? 20 : 10,
                child: CustomPaint(
                  painter: TagPainter(radius: 3, colors: colors),
                ),
              ))
      ]),
    );
  }

  String _getPlatformDisplayName(String platform) {
    if (platform.isEmpty) return '';
    if (platform.toLowerCase().contains('windows') ||
        platform == kPeerPlatformWindows) {
      return 'Windows';
    } else if (platform == kPeerPlatformMacOS ||
        platform.toLowerCase().contains('mac')) {
      return 'macOS';
    } else if (platform == kPeerPlatformLinux ||
        platform.toLowerCase().contains('linux')) {
      return 'Linux';
    } else if (platform == kPeerPlatformAndroid ||
        platform.toLowerCase().contains('android')) {
      return 'Android';
    }
    return platform;
  }

  /// 그리드 카드 빌드 (큰 카드 레이아웃)
  /// Build grid card (large card layout)
  ///
  /// 구조:
  /// ┌─────────────────┐
  /// │ [접속 가능]     │ <- 상태 배지
  /// │                 │
  /// │  🪟 Windows 11  │ <- 아이콘 + OS 버전
  /// │  [rncpe@toho]   │ <- 사용자@호스트명
  /// │                 │
  /// ├─────────────────┤
  /// │ [332 448 650]   │ <- ID (하단 영역)
  /// └─────────────────┘
  Widget _buildPeerCard(
      BuildContext context, Peer peer, Rx<BoxDecoration?> deco) {
    hideUsernameOnCard ??=
        bind.mainGetBuildinOption(key: kHideUsernameOnCard) == 'Y';
    final theme = MyTheme.peerCard(context);
    // 사용자@호스트명 형식 (예: rncpe@toho)
    final name = hideUsernameOnCard == true
        ? peer.hostname
        : '${peer.username}${peer.username.isNotEmpty && peer.hostname.isNotEmpty ? '@' : ''}${peer.hostname}';
    final child = Card(
      color: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Obx(
        () => Container(
          foregroundDecoration: deco.value, // 호버 테두리 효과
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(theme.cardRadius - theme.borderWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 상단 영역 (상태, 아이콘, 이름)
                Expanded(
                  child: Container(
                    color: theme.topBackgroundColor, // 연한 파랑 배경
                    child: Stack(
                      children: [
                        // 상태 배지 (좌측 상단) - "접속 가능" 또는 "Offline"
                        Positioned(
                          top: 16,
                          left: 16,
                          child: StatusBadge(
                            isOnline: peer.online,
                            fontSize: 15,
                            dotSize: 8,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                        ),
                        // 중앙 콘텐츠
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 24),
                              // OS 아이콘 + OS 버전
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // OS 아이콘 (Windows, macOS, Linux 등)
                                  ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      theme.accentColor, // 보라색
                                      BlendMode.srcIn,
                                    ),
                                    child: getPlatformImage(peer.platform,
                                        size: 32),
                                  ),
                                  const SizedBox(width: 8),
                                  // OS 버전 텍스트 (예: "Windows 11 Pro")
                                  Text(
                                    peer.osVersion.isNotEmpty
                                        ? peer.osVersion
                                        : _getPlatformDisplayName(
                                            peer.platform),
                                    style: TextStyle(
                                      color: theme.accentColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // 사용자@호스트명 (예: [rncpe@toho])
                              Tooltip(
                                message: name,
                                waitDuration: const Duration(seconds: 1),
                                child: Text(
                                  '[$name]',
                                  style: TextStyle(
                                      color: theme.accentColor, fontSize: 16),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 노트 (메모) - 있으면 표시
                              if (_showNote(peer))
                                Tooltip(
                                  message: peer.note,
                                  waitDuration: const Duration(seconds: 1),
                                  child: Text(
                                    peer.note,
                                    style: TextStyle(
                                        color: theme.noteTextColor,
                                        fontSize: 12),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 하단 영역 (ID 또는 별칭 + 메뉴 버튼)
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.bottomBackgroundColor, // 메인 배경색
                    border: Border.all(
                      color: theme.borderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ID 또는 별칭 (예: [332 448 650])
                      Expanded(
                          child: Text(
                        '[${peer.alias.isEmpty ? formatID(peer.id) : peer.alias}]',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      )),
                      // 체크박스 또는 더보기 버튼 (...)
                      checkBoxOrActionMoreLandscape(peer, isTile: false),
                    ],
                  ).paddingSymmetric(horizontal: 12.0),
                )
              ],
            ),
          ),
        ),
      ),
    );

    final colors = _frontN(peer.tags, 25)
        .map((e) => gFFI.abModel.getCurrentAbTagColor(e))
        .toList();
    return Tooltip(
      message: peer.tags.isNotEmpty
          ? '${translate('Tags')}: ${peer.tags.join(', ')}'
          : '',
      child: Stack(children: [
        child,
        if (_shouldBuildPasswordIcon(peer))
          Positioned(
            top: 4,
            left: 12,
            child: Icon(Icons.key, size: 12, color: Colors.white),
          ),
        if (colors.isNotEmpty)
          Positioned(
            top: 4,
            right: 12,
            child: CustomPaint(
              painter: TagPainter(radius: 4, colors: colors),
            ),
          )
      ]),
    );
  }

  List _frontN<T>(List list, int n) {
    if (list.length <= n) {
      return list;
    } else {
      return list.sublist(0, n);
    }
  }

  Widget checkBoxOrActionMorePortrait(Peer peer) {
    final PeerTabModel peerTabModel = Provider.of(context);
    final selected = peerTabModel.isPeerSelected(peer.id);
    if (peerTabModel.multiSelectionMode) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: selected
            ? Icon(
                Icons.check_box,
                color: MyTheme.accent,
              )
            : Icon(Icons.check_box_outline_blank),
      );
    } else {
      return InkWell(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                'assets/icons/peercard-vdot.svg',
                width: 20,
                height: 20,
              )),
          onTapDown: (e) {
            final x = e.globalPosition.dx;
            final y = e.globalPosition.dy;
            _menuPos = RelativeRect.fromLTRB(x, y, x, y);
          },
          onTap: () {
            _showPeerMenu(peer.id);
          });
    }
  }

  Widget checkBoxOrActionMoreLandscape(Peer peer, {required bool isTile}) {
    final PeerTabModel peerTabModel = Provider.of(context);
    final selected = peerTabModel.isPeerSelected(peer.id);
    if (peerTabModel.multiSelectionMode) {
      final icon = selected
          ? Icon(
              Icons.check_box,
              color: MyTheme.accent,
            )
          : Icon(Icons.check_box_outline_blank);
      bool last = peerTabModel.isShiftDown && peer.id == peerTabModel.lastId;
      double right = isTile ? 4 : 0;
      if (last) {
        return Container(
          decoration: BoxDecoration(
              border: Border.all(color: MyTheme.accent, width: 1)),
          child: icon,
        ).marginOnly(right: right);
      } else {
        return icon.marginOnly(right: right);
      }
    } else {
      return _actionMore(peer);
    }
  }

  Widget _actionMore(Peer peer) => Listener(
      onPointerDown: (e) {
        final x = e.position.dx;
        final y = e.position.dy;
        _menuPos = RelativeRect.fromLTRB(x, y, x, y);
      },
      onPointerUp: (_) => _showPeerMenu(peer.id),
      child: build_more(context));

  bool _shouldBuildPasswordIcon(Peer peer) {
    if (gFFI.peerTabModel.currentTab != PeerTabIndex.ab.index) return false;
    if (gFFI.abModel.current.isPersonal()) return false;
    return peer.password.isNotEmpty;
  }

  /// Show the peer menu and handle user's choice.
  /// User might remove the peer or send a file to the peer.
  void _showPeerMenu(String id) async {
    await mod_menu.showMenu(
      context: context,
      position: _menuPos,
      items: await super.widget.popupMenuEntryBuilder(context),
      elevation: 8,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

abstract class BasePeerCard extends StatelessWidget {
  final Peer peer;
  final PeerTabIndex tab;
  final EdgeInsets? menuPadding;

  BasePeerCard(
      {required this.peer, required this.tab, this.menuPadding, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _PeerCard(
      peer: peer,
      tab: tab,
      connect: (BuildContext context, String id) =>
          connectInPeerTab(context, peer, tab),
      popupMenuEntryBuilder: _buildPopupMenuEntry,
    );
  }

  Future<List<mod_menu.PopupMenuEntry<String>>> _buildPopupMenuEntry(
          BuildContext context) async =>
      (await _buildMenuItems(context))
          .map((e) => e.build(
              context,
              MenuConfig(
                  commonColor: CustomPopupMenuTheme.commonColor,
                  // 모바일: 연결카드 팝업메뉴와 동일한 스타일
                  // Mobile: same style as connection card popup menu
                  height: isMobile ? 48.0 : CustomPopupMenuTheme.height,
                  dividerHeight: isMobile ? 8.0 : CustomPopupMenuTheme.dividerHeight,
                  fontSize: isMobile ? 16.0 : MenuConfig.defaultFontSize,
                  // 모바일: 패딩을 0으로 설정하여 테스트
                  menuItemPadding: isMobile ? EdgeInsets.zero : null)))
          .expand((i) => i)
          .toList();

  @protected
  Future<List<MenuEntryBase<String>>> _buildMenuItems(BuildContext context);

  MenuEntryBase<String> _connectCommonAction(
    BuildContext context,
    String title, {
    bool isFileTransfer = false,
    bool isViewCamera = false,
    bool isTcpTunneling = false,
    bool isRDP = false,
    bool isTerminal = false,
    bool isTerminalRunAsAdmin = false,
  }) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        title,
        style: style,
      ),
      proc: () {
        if (isTerminalRunAsAdmin) {
          setEnvTerminalAdmin();
        }
        connectInPeerTab(
          context,
          peer,
          tab,
          isFileTransfer: isFileTransfer,
          isViewCamera: isViewCamera,
          isTcpTunneling: isTcpTunneling,
          isRDP: isRDP,
          isTerminal: isTerminal || isTerminalRunAsAdmin,
        );
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _connectAction(BuildContext context) {
    return _connectCommonAction(
      context,
      (peer.alias.isEmpty
          ? translate('Connect')
          : '${translate('Connect')} ${peer.id}'),
    );
  }

  @protected
  MenuEntryBase<String> _transferFileAction(BuildContext context) {
    return _connectCommonAction(
      context,
      translate('Transfer file'),
      isFileTransfer: true,
    );
  }

  @protected
  MenuEntryBase<String> _viewCameraAction(BuildContext context) {
    return _connectCommonAction(
      context,
      translate('View camera'),
      isViewCamera: true,
    );
  }

  @protected
  MenuEntryBase<String> _terminalAction(BuildContext context) {
    return _connectCommonAction(
      context,
      '${translate('Terminal')} (beta)',
      isTerminal: true,
    );
  }

  @protected
  MenuEntryBase<String> _terminalRunAsAdminAction(BuildContext context) {
    return _connectCommonAction(
      context,
      '${translate('Terminal (Run as administrator)')} (beta)',
      isTerminalRunAsAdmin: true,
    );
  }

  @protected
  MenuEntryBase<String> _tcpTunnelingAction(BuildContext context) {
    return _connectCommonAction(
      context,
      translate('TCP tunneling'),
      isTcpTunneling: true,
    );
  }

  @protected
  MenuEntryBase<String> _rdpAction(BuildContext context, String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Container(
          alignment: AlignmentDirectional.center,
          height: CustomPopupMenuTheme.height,
          child: Row(
            children: [
              Text(
                translate('RDP'),
                style: style,
              ),
              Expanded(
                  child: Align(
                alignment: Alignment.centerRight,
                child: Transform.scale(
                    scale: 0.8,
                    child: IconButton(
                      icon: const Icon(Icons.edit),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        _rdpDialog(id);
                      },
                    )),
              ))
            ],
          )),
      proc: () {
        connectInPeerTab(context, peer, tab, isRDP: true);
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _wolAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('WOL'),
        style: style,
      ),
      proc: () {
        bind.mainWol(id: id);
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  /// Only available on Windows.
  @protected
  MenuEntryBase<String> _createShortCutAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Create desktop shortcut'),
        style: style,
      ),
      proc: () {
        bind.mainCreateShortcut(id: id);
        showToast(translate('Successful'));
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  Future<MenuEntryBase<String>> _openNewConnInAction(
      String id, String label, String key) async {
    return MenuEntrySwitch<String>(
      switchType: SwitchType.scheckbox,
      text: translate(label),
      getter: () async => mainGetPeerBoolOptionSync(id, key),
      setter: (bool v) async {
        await bind.mainSetPeerOption(
            id: id, key: key, value: bool2option(key, v));
        showToast(translate('Successful'));
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  _openInTabsAction(String id) async =>
      await _openNewConnInAction(id, 'Open in New Tab', kOptionOpenInTabs);

  _openInWindowsAction(String id) async => await _openNewConnInAction(
      id, 'Open in new window', kOptionOpenInWindows);

  // ignore: unused_element
  _openNewConnInOptAction(String id) async =>
      mainGetLocalBoolOptionSync(kOptionOpenNewConnInTabs)
          ? await _openInWindowsAction(id)
          : await _openInTabsAction(id);

  @protected
  Future<bool> _isForceAlwaysRelay(String id) async {
    return option2bool(kOptionForceAlwaysRelay,
        (await bind.mainGetPeerOption(id: id, key: kOptionForceAlwaysRelay)));
  }

  @protected
  Future<MenuEntryBase<String>> _forceAlwaysRelayAction(String id) async {
    return MenuEntrySwitch<String>(
      switchType: SwitchType.scheckbox,
      text: translate('Always connect via relay'),
      getter: () async {
        return await _isForceAlwaysRelay(id);
      },
      setter: (bool v) async {
        await bind.mainSetPeerOption(
            id: id,
            key: kOptionForceAlwaysRelay,
            value: bool2option(kOptionForceAlwaysRelay, v));
        showToast(translate('Successful'));
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _renameAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Rename'),
        style: style,
      ),
      proc: () async {
        String oldName = await _getAlias(id);
        renameDialog(
            oldName: oldName,
            onSubmit: (String newName) async {
              if (newName != oldName) {
                if (tab == PeerTabIndex.ab) {
                  await gFFI.abModel.changeAlias(id: id, alias: newName);
                  await bind.mainSetPeerAlias(id: id, alias: newName);
                } else {
                  await bind.mainSetPeerAlias(id: id, alias: newName);
                  showToast(translate('Successful'));
                  _update();
                }
              }
            });
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _removeAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Delete'),
        style: style?.copyWith(color: Colors.red),
      ),
      proc: () {
        onSubmit() async {
          switch (tab) {
            case PeerTabIndex.recent:
              await bind.mainRemovePeer(id: id);
              bind.mainLoadRecentPeers();
              break;
            case PeerTabIndex.fav:
              final favs = (await bind.mainGetFav()).toList();
              if (favs.remove(id)) {
                await bind.mainStoreFav(favs: favs);
                bind.mainLoadFavPeers();
              }
              break;
            case PeerTabIndex.lan:
              await bind.mainRemoveDiscovered(id: id);
              bind.mainLoadLanPeers();
              break;
            case PeerTabIndex.ab:
              await gFFI.abModel.deletePeers([id]);
              break;
            case PeerTabIndex.group:
              break;
          }
          if (tab != PeerTabIndex.ab) {
            showToast(translate('Successful'));
          }
        }

        deleteConfirmDialog(onSubmit,
            peer.alias.isEmpty ? formatID(peer.id) : peer.alias);
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _unrememberPasswordAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Forget Password'),
        style: style,
      ),
      proc: () async {
        bool succ = await gFFI.abModel.changePersonalHashPassword(id, '');
        await bind.mainForgetPassword(id: id);
        if (succ) {
          showToast(translate('Successful'));
        } else {
          if (tab.index == PeerTabIndex.ab.index) {
            BotToast.showText(
                contentColor: Colors.red, text: translate("Failed"));
          }
        }
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _addFavAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Add to Favorites'),
        style: style,
      ),
      proc: () {
        () async {
          final favs = (await bind.mainGetFav()).toList();
          if (!favs.contains(id)) {
            favs.add(id);
            await bind.mainStoreFav(favs: favs);
          }
          showToast(translate('Successful'));
        }();
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _rmFavAction(
      String id, Future<void> Function() reloadFunc) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Remove from Favorites'),
        style: style,
      ),
      proc: () {
        () async {
          final favs = (await bind.mainGetFav()).toList();
          if (favs.remove(id)) {
            await bind.mainStoreFav(favs: favs);
            await reloadFunc();
          }
          showToast(translate('Successful'));
        }();
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _addToAb(Peer peer) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Add to address book'),
        style: style,
      ),
      proc: () {
        () async {
          addPeersToAbDialog([Peer.copy(peer)]);
        }();
      },
      padding: menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  Future<String> _getAlias(String id) async =>
      await bind.mainGetPeerOption(id: id, key: 'alias');

  @protected
  void _update();
}

class RecentPeerCard extends BasePeerCard {
  RecentPeerCard({required Peer peer, EdgeInsets? menuPadding, Key? key})
      : super(
            peer: peer,
            tab: PeerTabIndex.recent,
            menuPadding: menuPadding,
            key: key);

  @override
  Future<List<MenuEntryBase<String>>> _buildMenuItems(
      BuildContext context) async {
    final List<MenuEntryBase<String>> menuItems = [
      _connectAction(context),
      _transferFileAction(context),
      _viewCameraAction(context),
    ];

    final List favs = (await bind.mainGetFav()).toList();

    if (!favs.contains(peer.id)) {
      menuItems.add(_addFavAction(peer.id));
    } else {
      menuItems.add(_rmFavAction(peer.id, () async {}));
    }

    menuItems.add(MenuEntryDivider());
    menuItems.add(_removeAction(peer.id));
    return menuItems;
  }

  @protected
  @override
  void _update() => bind.mainLoadRecentPeers();
}

class FavoritePeerCard extends BasePeerCard {
  FavoritePeerCard({required Peer peer, EdgeInsets? menuPadding, Key? key})
      : super(
            peer: peer,
            tab: PeerTabIndex.fav,
            menuPadding: menuPadding,
            key: key);

  @override
  Future<List<MenuEntryBase<String>>> _buildMenuItems(
      BuildContext context) async {
    final List<MenuEntryBase<String>> menuItems = [
      _connectAction(context),
      _transferFileAction(context),
      _viewCameraAction(context),
    ];

    menuItems.add(_rmFavAction(peer.id, () async {
      await bind.mainLoadFavPeers();
    }));

    menuItems.add(MenuEntryDivider());
    menuItems.add(_removeAction(peer.id));
    return menuItems;
  }

  @protected
  @override
  void _update() => bind.mainLoadFavPeers();
}

class DiscoveredPeerCard extends BasePeerCard {
  DiscoveredPeerCard({required Peer peer, EdgeInsets? menuPadding, Key? key})
      : super(
            peer: peer,
            tab: PeerTabIndex.lan,
            menuPadding: menuPadding,
            key: key);

  @override
  Future<List<MenuEntryBase<String>>> _buildMenuItems(
      BuildContext context) async {
    final List<MenuEntryBase<String>> menuItems = [
      _connectAction(context),
      _transferFileAction(context),
      _viewCameraAction(context),
    ];

    final List favs = (await bind.mainGetFav()).toList();

    if (!favs.contains(peer.id)) {
      menuItems.add(_addFavAction(peer.id));
    } else {
      menuItems.add(_rmFavAction(peer.id, () async {}));
    }

    menuItems.add(MenuEntryDivider());
    menuItems.add(_removeAction(peer.id));
    return menuItems;
  }

  @protected
  @override
  void _update() => bind.mainLoadLanPeers();
}

class AddressBookPeerCard extends BasePeerCard {
  AddressBookPeerCard({required Peer peer, EdgeInsets? menuPadding, Key? key})
      : super(
            peer: peer,
            tab: PeerTabIndex.ab,
            menuPadding: menuPadding,
            key: key);

  @override
  Future<List<MenuEntryBase<String>>> _buildMenuItems(
      BuildContext context) async {
    final List<MenuEntryBase<String>> menuItems = [
      _connectAction(context),
      _transferFileAction(context),
      _viewCameraAction(context),
    ];

    final List favs = (await bind.mainGetFav()).toList();

    if (!favs.contains(peer.id)) {
      menuItems.add(_addFavAction(peer.id));
    } else {
      menuItems.add(_rmFavAction(peer.id, () async {}));
    }

    if (gFFI.abModel.current.canWrite()) {
      menuItems.add(MenuEntryDivider());
      menuItems.add(_removeAction(peer.id));
    }
    return menuItems;
  }

  // address book does not need to update
  @protected
  @override
  void _update() =>
      {}; //gFFI.abModel.pullAb(force: ForcePullAb.current, quiet: true);

  @protected
  MenuEntryBase<String> _editTagAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Edit Tag'),
        style: style,
      ),
      proc: () {
        editAbTagDialog(gFFI.abModel.getPeerTags(id), (selectedTag) async {
          await gFFI.abModel.changeTagForPeers([id], selectedTag);
        });
      },
      padding: super.menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  MenuEntryBase<String> _editNoteAction(String id) {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Edit note'),
        style: style,
      ),
      proc: () {
        editAbPeerNoteDialog(id);
      },
      padding: super.menuPadding,
      dismissOnClicked: true,
    );
  }

  @protected
  @override
  Future<String> _getAlias(String id) async =>
      gFFI.abModel.find(id)?.alias ?? '';

  MenuEntryBase<String> _changeSharedAbPassword() {
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate(
            peer.password.isEmpty ? 'Set shared password' : 'Change Password'),
        style: style,
      ),
      proc: () {
        setSharedAbPasswordDialog(gFFI.abModel.currentName.value, peer);
      },
      padding: super.menuPadding,
      dismissOnClicked: true,
    );
  }

  MenuEntryBase<String> _existIn() {
    final names = gFFI.abModel.idExistIn(peer.id);
    final text = names.join(', ');
    return MenuEntryButton<String>(
      childBuilder: (TextStyle? style) => Text(
        translate('Exist in'),
        style: style,
      ),
      proc: () {
        gFFI.dialogManager.show((setState, close, context) {
          return CustomAlertDialog(
            title: Text(translate('Exist in')),
            content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(text)]),
            actions: [
              dialogButton(
                "OK",
                icon: Icon(Icons.done_rounded),
                onPressed: close,
              ),
            ],
            onSubmit: close,
            onCancel: close,
          );
        });
      },
      padding: super.menuPadding,
      dismissOnClicked: true,
    );
  }
}

class MyGroupPeerCard extends BasePeerCard {
  MyGroupPeerCard({required Peer peer, EdgeInsets? menuPadding, Key? key})
      : super(
            peer: peer,
            tab: PeerTabIndex.group,
            menuPadding: menuPadding,
            key: key);

  @override
  Future<List<MenuEntryBase<String>>> _buildMenuItems(
      BuildContext context) async {
    final List<MenuEntryBase<String>> menuItems = [
      _connectAction(context),
      _transferFileAction(context),
      _viewCameraAction(context),
    ];

    final List favs = (await bind.mainGetFav()).toList();

    if (!favs.contains(peer.id)) {
      menuItems.add(_addFavAction(peer.id));
    } else {
      menuItems.add(_rmFavAction(peer.id, () async {}));
    }

    return menuItems;
  }

  @protected
  @override
  void _update() => gFFI.groupModel.pull();
}

void _rdpDialog(String id) async {
  final maxLength = bind.mainMaxEncryptLen();
  final port = await bind.mainGetPeerOption(id: id, key: 'rdp_port');
  final username = await bind.mainGetPeerOption(id: id, key: 'rdp_username');
  final portController = TextEditingController(text: port);
  final userController = TextEditingController(text: username);
  final passwordController = TextEditingController(
      text: await bind.mainGetPeerOption(id: id, key: 'rdp_password'));
  RxBool secure = true.obs;

  gFFI.dialogManager.show((setState, close, context) {
    submit() async {
      String port = portController.text.trim();
      String username = userController.text;
      String password = passwordController.text;
      await bind.mainSetPeerOption(id: id, key: 'rdp_port', value: port);
      await bind.mainSetPeerOption(
          id: id, key: 'rdp_username', value: username);
      await bind.mainSetPeerOption(
          id: id, key: 'rdp_password', value: password);
      showToast(translate('Successful'));
      close();
    }

    return CustomAlertDialog(
      title: Text(translate('RDP Settings')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                isDesktop
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 140),
                        child: Text(
                          "${translate('Port')}:",
                          textAlign: TextAlign.right,
                        ).marginOnly(right: 10))
                    : SizedBox.shrink(),
                Expanded(
                  child: TextField(
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(
                          r'^([0-9]|[1-9]\d|[1-9]\d{2}|[1-9]\d{3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5])$'))
                    ],
                    decoration: InputDecoration(
                        labelText: isDesktop ? null : translate('Port'),
                        hintText: '3389'),
                    controller: portController,
                    autofocus: true,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ).marginOnly(bottom: isDesktop ? 8 : 0),
            Obx(() => Row(
                  children: [
                    stateGlobal.isPortrait.isFalse
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 140),
                            child: Text(
                              "${translate('Username')}:",
                              textAlign: TextAlign.right,
                            ).marginOnly(right: 10))
                        : SizedBox.shrink(),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                            labelText:
                                isDesktop ? null : translate('Username')),
                        controller: userController,
                      ).workaroundFreezeLinuxMint(),
                    ),
                  ],
                ).marginOnly(bottom: stateGlobal.isPortrait.isFalse ? 8 : 0)),
            Obx(() => Row(
                  children: [
                    stateGlobal.isPortrait.isFalse
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 140),
                            child: Text(
                              "${translate('Password')}:",
                              textAlign: TextAlign.right,
                            ).marginOnly(right: 10))
                        : SizedBox.shrink(),
                    Expanded(
                      child: Obx(() => TextField(
                            obscureText: secure.value,
                            maxLength: maxLength,
                            decoration: InputDecoration(
                                labelText:
                                    isDesktop ? null : translate('Password'),
                                suffixIcon: IconButton(
                                    onPressed: () =>
                                        secure.value = !secure.value,
                                    icon: Icon(secure.value
                                        ? Icons.visibility_off
                                        : Icons.visibility))),
                            controller: passwordController,
                          ).workaroundFreezeLinuxMint()),
                    ),
                  ],
                ))
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
                child:
                    dialogButton("Cancel", onPressed: close, isOutline: true)),
            const SizedBox(width: 12),
            Expanded(child: dialogButton("OK", onPressed: submit)),
          ],
        ),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

Widget getOnline(double rightPadding, bool online) {
  return Tooltip(
      message: translate(online ? 'Online' : 'Offline'),
      waitDuration: const Duration(seconds: 1),
      child: Padding(
          padding: EdgeInsets.fromLTRB(0, 4, rightPadding, 4),
          child: CircleAvatar(
              radius: 4, backgroundColor: online ? Colors.green : kColorWarn)));
}

Widget build_more(BuildContext context, {bool invert = false}) {
  final RxBool hover = false.obs;
  return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {},
      onHover: (value) => hover.value = value,
      child: Obx(() => CircleAvatar(
          radius: 14,
          backgroundColor: Colors.transparent,
          child: SvgPicture.asset('assets/icons/peercard-vdot.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                  hover.value
                      ? Theme.of(context).textTheme.titleLarge?.color ??
                          Colors.black
                      : (Theme.of(context).textTheme.titleLarge?.color ??
                              Colors.black)
                          .withOpacity(0.5),
                  BlendMode.srcIn)))));
}

class TagPainter extends CustomPainter {
  final double radius;
  late final List<Color> colors;

  TagPainter({required this.radius, required List<Color> colors}) {
    this.colors = colors.reversed.toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    double x = 0;
    double y = radius;
    for (int i = 0; i < colors.length; i++) {
      Paint paint = Paint();
      paint.color = colors[i];
      x -= radius + 1;
      if (i == colors.length - 1) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      } else {
        Path path = Path();
        path.addArc(Rect.fromCircle(center: Offset(x, y), radius: radius),
            math.pi * 4 / 3, math.pi * 4 / 3);
        path.addArc(
            Rect.fromCircle(center: Offset(x - radius, y), radius: radius),
            math.pi * 5 / 3,
            math.pi * 2 / 3);
        path.fillType = PathFillType.evenOdd;
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

void connectInPeerTab(BuildContext context, Peer peer, PeerTabIndex tab,
    {bool isFileTransfer = false,
    bool isViewCamera = false,
    bool isTcpTunneling = false,
    bool isRDP = false,
    bool isTerminal = false}) async {
  var password = '';
  bool isSharedPassword = false;
  if (tab == PeerTabIndex.ab) {
    // If recent peer's alias is empty, set it to ab's alias
    // Because the platform is not set, it may not take effect, but it is more important not to display if the connection is not successful
    if (peer.alias.isNotEmpty &&
        (await bind.mainGetPeerOption(id: peer.id, key: "alias")).isEmpty) {
      await bind.mainSetPeerAlias(
        id: peer.id,
        alias: peer.alias,
      );
    }
    if (!gFFI.abModel.current.isPersonal()) {
      if (peer.password.isNotEmpty) {
        password = peer.password;
        isSharedPassword = true;
      }
      if (password.isEmpty) {
        final abPassword = gFFI.abModel.getdefaultSharedPassword();
        if (abPassword != null) {
          password = abPassword;
          isSharedPassword = true;
        }
      }
    }
  }
  connect(context, peer.id,
      password: password,
      isSharedPassword: isSharedPassword,
      isFileTransfer: isFileTransfer,
      isTerminal: isTerminal,
      isViewCamera: isViewCamera,
      isTcpTunneling: isTcpTunneling,
      isRDP: isRDP);
}
