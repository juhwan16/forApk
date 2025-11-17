// lib/screens/extinguisher_list_screen.dart
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
        // 필요하면 여기서 로그인 화면으로 이동 로직 추가
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
    // 상세 화면에서 저장 후 돌아오면 목록 다시 로드
    await _loadExtinguishers();
  }

  @override
  Widget build(BuildContext context) {
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
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: ListTile(
                          leading: ext.imagePath != null &&
                                  ext.imagePath!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    '$imageRootUrl${ext.imagePath}',
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.fire_extinguisher),
                          title: Text(ext.name ?? '이름 없음'),
                          subtitle: Row(
                            children: [
                              Icon(
                                ext.isLightOn == true
                                    ? Icons.lightbulb
                                    : Icons.lightbulb_outline,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                ext.isSoundOn == true
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                size: 18,
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
