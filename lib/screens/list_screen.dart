// lib/screens/list.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_extinguisher_app/models/fire_extinguisher.dart';
import 'package:smart_extinguisher_app/screens/detail.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';

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
        final jsonBody = jsonDecode(res.body) as Map<String, dynamic>;
        if (jsonBody['ok'] == true && jsonBody['data'] is List) {
          final List<dynamic> list = jsonBody['data'];
          final items = list
              .map((e) => FireExtinguisher.fromJson(e as Map<String, dynamic>))
              .toList();

          setState(() {
            _items = items;
          });
        } else {
          _showSnackBar('소화기 목록을 불러오지 못했습니다.');
        }
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

  Future<void> _globalOff() async {
    try {
      final res = await httpPut(
        '/api/v1/extinguishers/global-off',
        {},
        context: context,
        auth: true,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final jsonBody = jsonDecode(res.body) as Map<String, dynamic>;
        if (jsonBody['ok'] == true) {
          _showSnackBar('모든 소화기의 빛/소리를 끔');
          await _loadExtinguishers();
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

                      Widget leading;
                      if (ext.imagePath != null && ext.imagePath!.isNotEmpty) {
                        leading = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '$imageRootUrl${ext.imagePath}',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported),
                          ),
                        );
                      } else {
                        leading = Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.fire_extinguisher_outlined,
                            color: Colors.red.shade400,
                          ),
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: ListTile(
                          leading: leading,
                          title: Text(
                            ext.location.isEmpty
                                ? '이름 없는 소화기'
                                : ext.location,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ext.expireDate.isEmpty
                                    ? '사용 가능 기간 정보 없음'
                                    : '사용 가능 기간: ${ext.expireDate}',
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
