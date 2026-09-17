import 'dart:io';
import 'dart:typed_data';

/// レシート画像のバイト列を読み込む抽象（依存性注入のため）。
abstract class ReceiptImageLoader {
  /// [path] の画像バイト列を読む。読めない場合は null。
  Future<Uint8List?> load(String path);
}

/// dart:io の [File] で実ファイルを読むローダ。
///
/// ファイル不在・IO例外は null に落とす（例外を外に漏らさない）。
class FileReceiptImageLoader implements ReceiptImageLoader {
  const FileReceiptImageLoader();

  @override
  Future<Uint8List?> load(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } on Exception {
      return null;
    }
  }
}

/// メモリ上の Map から読むローダ（試練用）。
class InMemoryReceiptImageLoader implements ReceiptImageLoader {
  /// 登録済みパス → バイト列。
  final Map<String, Uint8List> store;

  const InMemoryReceiptImageLoader(this.store);

  @override
  Future<Uint8List?> load(String path) async => store[path];
}

/// 呼び出しを記録するだけのフェイクローダ（試練用）。
class FakeReceiptImageLoader implements ReceiptImageLoader {
  /// load に渡されたパスの記録。
  final List<String> calls = <String>[];

  /// load が返す値。
  final Uint8List? result;

  FakeReceiptImageLoader({this.result});

  @override
  Future<Uint8List?> load(String path) async {
    calls.add(path);
    return result;
  }
}
