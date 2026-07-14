import 'dart:convert';

enum AppFailureKind { business, parse }

sealed class AppResult<T> {
  const AppResult();
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);
  final T value;
}

final class AppFailure<T> extends AppResult<T> {
  const AppFailure({
    required this.kind,
    required this.message,
    this.code,
    this.cause,
  });

  final AppFailureKind kind;
  final String message;
  final int? code;
  final Object? cause;
}

abstract final class AppResponse {
  static AppResult<T> resolve<T>(
    String rawJson,
    T Function(Object? body) decodeBody,
  ) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return AppFailure<T>(kind: AppFailureKind.parse, message: '响应格式错误');
      }
      final root = Map<String, Object?>.from(decoded);
      final code = _asInt(root['code']);
      final message = (root['msg'] ?? root['message'] ?? '').toString();
      if (code != 200) {
        return AppFailure<T>(
          kind: AppFailureKind.business,
          code: code,
          message: message.isEmpty ? '请求失败' : message,
        );
      }
      return AppSuccess<T>(decodeBody(root['body']));
    } catch (error) {
      return AppFailure<T>(
        kind: AppFailureKind.parse,
        message: '响应解析失败',
        cause: error,
      );
    }
  }

  static AppResult<List<T>> resolveList<T>(
    String rawJson,
    T Function(Object? item) decodeItem,
  ) {
    return resolve<List<T>>(rawJson, (body) {
      if (body is! List) throw const FormatException('body is not a list');
      return body.map(decodeItem).toList(growable: false);
    });
  }

  static int? _asInt(Object? value) => switch (value) {
    int number => number,
    String text => int.tryParse(text),
    _ => null,
  };
}
