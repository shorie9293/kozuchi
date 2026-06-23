import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';

/// 取引データの API 通信を担当するサービス
///
/// `GET /api/transactions` エンドポイントを叩き、
/// フィルタ条件に応じた取引一覧を取得する。
class TransactionService {
  final http.Client _client;
  final String _baseUrl;

  TransactionService({
    http.Client? client,
    String baseUrl = 'http://localhost:8080',
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  /// 日付を YYYY-MM-DD 形式に整形する
  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 取引一覧を API から取得する
  ///
  /// [filter] によるフィルタ（種別・日付範囲）を適用する。
  ///
  /// API レスポンス形式: `{ "data": [...] }`
  /// 各要素は [TransactionModel.fromJson] でパースされる。
  /// エラー時は [TransactionServiceException] を投げる。
  Future<List<TransactionModel>> fetchTransactions({
    required TransactionFilter filter,
  }) async {
    final queryParams = <String, String>{};

    // 種別フィルタ
    switch (filter.type) {
      case TransactionFilterType.income:
        queryParams['type'] = 'income';
        break;
      case TransactionFilterType.expense:
        queryParams['type'] = 'expense';
        break;
      case TransactionFilterType.all:
        // 'all' はクエリパラメータに含めない（サーバ側のデフォルト）
        break;
    }

    if (filter.startDate != null) {
      queryParams['start_date'] = _formatDate(filter.startDate!);
    }
    if (filter.endDate != null) {
      queryParams['end_date'] = _formatDate(filter.endDate!);
    }

    final uri = Uri.parse('$_baseUrl/api/transactions')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final dataList = body['data'] as List<dynamic>?;

        if (dataList == null) {
          throw TransactionServiceException(
            'API response missing "data" field',
          );
        }

        return dataList
            .map(
                (json) => TransactionModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw TransactionServiceException(
          'API returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw TransactionServiceException(
        'Network error: ${e.message}',
      );
    } on FormatException catch (e) {
      throw TransactionServiceException(
        'Invalid response format: ${e.message}',
      );
    }
  }

  /// リソースを解放する
  void dispose() {
    _client.close();
  }
}

/// 取引サービスで発生する例外
class TransactionServiceException implements Exception {
  final String message;
  const TransactionServiceException(this.message);

  @override
  String toString() => 'TransactionServiceException: $message';
}
