import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/app_api_client.dart';
import 'purchase_history_data_source.dart';
import 'purchase_history_models.dart';

final class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({required this.dataSource, super.key});

  final PurchaseHistoryDataSource dataSource;

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

final class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  List<PurchaseHistoryOrder> _orders = const [];
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        toolbarHeight: 50,
        leading: IconButton(
          key: const ValueKey('purchase-history-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '我的订单',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const ValueKey('purchase-history-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: _orders.isEmpty
              ? const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _PurchaseHistoryEmpty(),
                  ),
                ]
              : [
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    sliver: SliverList.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) => _PurchaseOrderCard(
                        key: ValueKey('purchase-order-$index'),
                        order: _orders[index],
                        index: index,
                        onCopy: _copyOrderId,
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final generation = ++_loadGeneration;
    try {
      final orders = await widget.dataSource.loadOrders();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _orders = List.unmodifiable(orders));
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _orders = const []);
      _showMessage(_errorMessage(error));
    } finally {
      if (generation == _loadGeneration) _loading = false;
    }
  }

  Future<void> _copyOrderId(String orderId) async {
    await Clipboard.setData(ClipboardData(text: orderId));
    if (mounted) _showMessage('订单号已复制');
  }

  String _errorMessage(Object error) {
    if (error is AppApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    if (error is FormatException) {
      final message = error.message.toString().trim();
      if (message.isNotEmpty) return message;
    }
    return '网络异常';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _PurchaseHistoryEmpty extends StatelessWidget {
  const _PurchaseHistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '暂无购买记录',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              '下拉可刷新列表',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC4C9D4), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({
    required this.order,
    required this.index,
    required this.onCopy,
    super.key,
  });

  final PurchaseHistoryOrder order;
  final int index;
  final Future<void> Function(String orderId) onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.displayTitle,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('订单号：', style: _detailStyle),
              Expanded(
                child: Text(
                  order.orderId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _detailStyle,
                ),
              ),
              TextButton(
                key: ValueKey('purchase-order-copy-$index'),
                onPressed: () => onCopy(order.orderId),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(40, 32),
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('复制', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('支付状态：${_javaString(order.orderStatus)}', style: _detailStyle),
          const SizedBox(height: 8),
          Text(
            '订单金额：${formatPurchaseAmount(order.orderAmount)}',
            style: _detailStyle,
          ),
          const SizedBox(height: 6),
          Text('付费时间：${_javaString(order.payTime)}', style: _detailStyle),
          const SizedBox(height: 6),
          Text(
            '到期时间：${_javaString(order.benefitsExpireTime)}',
            style: _detailStyle,
          ),
        ],
      ),
    );
  }

  static const _detailStyle = TextStyle(color: Color(0xFF6B7280), fontSize: 13);

  static String _javaString(String? value) => value ?? 'null';
}
