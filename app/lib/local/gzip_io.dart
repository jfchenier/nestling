import 'dart:io';

List<int> gzip(List<int> bytes) => GZipCodec(level: 6).encode(bytes);
List<int> gunzip(List<int> bytes) => GZipCodec().decode(bytes);
