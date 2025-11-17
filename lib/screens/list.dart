// C:\project\smart_extinguisher_app-main\lib\screens\list.dart
// lib/screens/list.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_extinguisher_app/models/fire_extinguisher.dart';
import 'package:smart_extinguisher_app/screens/detail.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';
import 'package:smart_extinguisher_app/services/bluetooth_service.dart';

class ExtinguisherListScreen extends StatefulWidget {
  const ExtinguisherListScreen({Key? key}) : super(key: key);

  @override
  State<ExtinguisherListScreen> createState() => _ExtinguisherListScreenState();
}

class _ExtinguisherListScreenState extends State<ExtinguisherListScreen> {
  bool _loading = false;
  List<FireExtinguisher> _items = [];

  @override
  void initState() {
    super.initState();
    _loadExtinguishers();
  }

  Future<void> _loadExtinguishers() async {
    setState(() {
      _loading = true;
    });

    try {
      final res = await httpGet(
        '/api/v1/extinguishers',
        context: context,
        auth: true,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        // 서버 응답을 유연하게 처리:
        // 1) [ {...}, {...} ] 형식
        // 2) { ok:true, extinguishers:[...]} 형식
        // 3) { ok:true, data:[...]} 형식
        // 4) { items:[...]} 형식
        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          final dynamic inner =
              decoded['extinguishers'] ?? decoded['data'] ?? decoded['items'];
          if (inner is List) {
            list = inner;
          } else {
            list = const [];
          }
        } else {
          list = const [];
        }

        final items = list
            .whereType<Map<String, dynamic>>()
            .map((e) => FireExtinguisher.fromJson(e))
            .toList();

        setState(() {
          _items = items;
        });
      } else if (res.statusCode == 401) {
        _showSnackBar('로그인이 필요합니다.');
      } else {
        _showSnackBar('서버 에러: ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('네트워크 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ---------------- 개별 삭제 ----------------
  Future<void> _deleteExtinguisher(FireExtinguisher ext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('소화기 삭제'),
        content: Text('소화기 "${ext.location}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await httpDelete(
        '/api/v1/extinguishers/${ext.id}',
        context: context,
        auth: true,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _items.removeWhere((e) => e.id == ext.id);
        });
        _showSnackBar('삭제되었습니다.');
      } else {
        final data = jsonDecode(res.body);
        _showSnackBar('삭제 실패: ${data['error'] ?? '알 수 없는 오류'}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('삭제 중 오류: $e');
    }
  }

  // ---------------- 전체 끄기 ----------------
  Future<void> _globalOff() async {
    try {
      // ★ 여기: PUT → POST 로 변경
      final res = await httpPost(
        '/api/v1/extinguishers/global-off',
        {},
        context: context,
        auth: true, // 서버에서는 auth 안 써도 되지만 헤더 있어도 무방
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        // body 에 ok 가 있을 수도 있고, 없을 수도 있음
        bool ok = true;
        try {
          final body = jsonDecode(res.body);
          if (body is Map<String, dynamic> && body.containsKey('ok')) {
            ok = body['ok'] == true;
          }
        } catch (_) {
          // JSON 이 아니면 statusCode 만으로 성공 처리
        }

        if (ok) {
          // DB 상태 최신화
          await _loadExtinguishers();

          // 현재 연결된 BLE 모듈이 있으면 모두 끄기 신호 전송
          if (myBleService.ready) {
            await myBleService.turnAllOff();
          }

          _showSnackBar('모든 소화기의 불빛/소리를 끔');
        } else {
          _showSnackBar('전역 OFF 처리 실패');
        }
      } else {
        _showSnackBar('서버 에러: ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('네트워크 오류: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openDetail(FireExtinguisher extinguisher) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(extinguisher: extinguisher),
      ),
    );
    await _loadExtinguishers();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('소화기 목록'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExtinguishers,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('등록된 소화기가 없습니다.')),
                    ],
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final ext = _items[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/fire_list_icon.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                          title: Text(
                            ext.location.isEmpty
                                ? '이름 없는 소화기'
                                : ext.location,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ext.expireDate.isEmpty
                                    ? '사용 가능 기간 정보 없음'
                                    : '사용 가능 기간: ${ext.expireDate}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    ext.isLightOn
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    size: 18,
                                    color: ext.isLightOn
                                        ? Colors.orange
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    ext.isSoundOn
                                        ? Icons.volume_up
                                        : Icons.volume_off,
                                    size: 18,
                                    color: ext.isSoundOn
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _openDetail(ext),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deleteExtinguisher(ext),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _globalOff,
        icon: const Icon(Icons.power_settings_new),
        label: const Text('전체 끄기'),
      ),
    );
  }
}
