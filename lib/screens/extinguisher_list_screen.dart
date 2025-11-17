import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_extinguisher_app/models/fire_extinguisher.dart';
import 'package:smart_extinguisher_app/screens/detail.dart';
import 'package:smart_extinguisher_app/screens/register_user_screen.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';
import 'package:smart_extinguisher_app/services/bluetooth_service.dart';

class ExtinguisherListScreen extends StatefulWidget {
  const ExtinguisherListScreen({super.key});

  @override
  State<ExtinguisherListScreen> createState() => _ExtinguisherListScreenState();
}

class _ExtinguisherListScreenState extends State<ExtinguisherListScreen> {
  bool _loading = false;
  String? _error;
  final List<FireExtinguisher> _items = [];

  @override
  void initState() {
    super.initState();
    _loadExtinguishers();
  }

  Future<void> _loadExtinguishers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await httpGet(
        '/api/v1/extinguishers',
        context: context,
        auth: true,
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['extinguishers'] is List) {
        final List list = data['extinguishers'] as List;
        _items
          ..clear()
          ..addAll(list
              .map((e) => FireExtinguisher.fromJson(e as Map<String, dynamic>)));
      } else {
        _items.clear();
        _error =
            '목록을 불러오지 못했습니다: ${data['error'] ?? data['detail'] ?? '알 수 없는 오류'}';
      }
    } catch (e) {
      _error = '오류 발생: $e';
      _items.clear();
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _goToRegister() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterExtinguisherScreen(),
      ),
    );
    if (changed == true) {
      await _loadExtinguishers();
    } else {
      // changed 가 null 이거나 false 여도, 그냥 항상 새로고침 해도 됨
      await _loadExtinguishers();
    }
  }

  Future<void> _deleteItem(FireExtinguisher item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: Text('소화기 "${item.location}"을(를) 삭제하시겠습니까?'),
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

    if (ok != true) return;

    try {
      final res = await httpDelete(
        '/api/v1/extinguishers/${item.id}',
        context: context,
        auth: true,
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['ok'] == true) {
        if (!mounted) return;
        setState(() {
          _items.removeWhere((e) => e.id == item.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '삭제 실패: ${data['error'] ?? data['detail'] ?? '알 수 없는 오류'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  Future<void> _allOff() async {
    try {
      await httpPost(
        '/api/v1/extinguishers/global-off',
        {},
        context: context,
        auth: true,
      );
    } catch (_) {}

    if (myBleService.ready) {
      await myBleService.turnAllOff();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('불빛·소리 OFF 신호를 전송했습니다.')),
    );
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('등록된 소화기가 없습니다.')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: Image.asset(
                                'assets/images/fire_list_icon.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                              title: Text(
                                item.location.isEmpty
                                    ? '(이름 없음)'
                                    : item.location,
                              ),
                              subtitle: Text(
                                item.expireDate.isEmpty
                                    ? '사용 가능 기간: 정보 없음'
                                    : '사용 가능 기간: ${item.expireDate}',
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetailScreen(extinguisher: item),
                                  ),
                                );
                                await _loadExtinguishers();
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteItem(item),
                              ),
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'all_off',
            onPressed: _allOff,
            label: const Text('전체 끄기'),
            icon: const Icon(Icons.power_settings_new),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _goToRegister,
            label: const Text('소화기 등록'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
