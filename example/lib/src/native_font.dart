import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

class ProbeFault implements Exception {
  ProbeFault(this.stage, this.code);
  final String stage;
  final int code;
  @override
  String toString() => '$stage (HRESULT/code $code)';
}

/// context와 오류 buffer는 worker 내부 소유이며 외부 isolate에 포인터를 보내지 않는다.
class NativeFont {
  NativeFont(String dll, String path) : library = DynamicLibrary.open(dll) {
    final name = path.toNativeUtf16();
    final failure = calloc<Pointer<Utf8>>();
    try {
      handle = library
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Pointer<Utf8>>),
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Pointer<Utf8>>)
          >('probe_open')(name, failure);
      if (handle == nullptr) throw fault(failure.value);
    } finally {
      if (failure.value != nullptr) freeNative(failure.value);
      calloc.free(failure);
      calloc.free(name);
    }
  }
  final DynamicLibrary library;
  late Pointer<Void> handle;
  void freeNative(Pointer<Utf8> p) =>
      library.lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('probe_free')(p);
  ProbeFault fault(Pointer<Utf8> p) {
    final value = jsonDecode(p.toDartString()) as Map<String, dynamic>;
    return ProbeFault(value['stage'] as String, value['hresult'] as int);
  }

  Map<String, dynamic> batch(List<String> texts) {
    final strings = calloc<Pointer<Utf16>>(texts.length);
    final failure = calloc<Pointer<Utf8>>();
    for (var i = 0; i < texts.length; i++) {
      strings[i] = texts[i].toNativeUtf16();
    }
    Pointer<Utf8> result = nullptr;
    try {
      result = library
          .lookupFunction<
            Pointer<Utf8> Function(
              Pointer<Void>,
              Pointer<Pointer<Utf16>>,
              Int32,
              Pointer<Pointer<Utf8>>,
            ),
            Pointer<Utf8> Function(
              Pointer<Void>,
              Pointer<Pointer<Utf16>>,
              int,
              Pointer<Pointer<Utf8>>,
            )
          >('probe_batch')(handle, strings, texts.length, failure);
      if (result == nullptr) throw fault(failure.value);
      return jsonDecode(result.toDartString()) as Map<String, dynamic>;
    } finally {
      if (result != nullptr) freeNative(result);
      if (failure.value != nullptr) freeNative(failure.value);
      calloc.free(failure);
      for (var i = 0; i < texts.length; i++) {
        calloc.free(strings[i]);
      }
      calloc.free(strings);
    }
  }

  void close() {
    if (handle != nullptr) {
      library.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('probe_close')(handle);
      handle = nullptr;
    }
  }
}
