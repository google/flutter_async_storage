// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter_async_storage/flutter_async_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform/src/testing/fake_platform.dart';

void main() {
  group(AsyncStorageReader, () {
    test('delegates to [AsyncStorageAndroid] on Android', () {
      expect(
          AsyncStorageReader(FakePlatform(operatingSystem: 'android'))
              is AsyncStorageAndroid,
          isTrue);
    });

    test('delegates to [AsyncStorageIOS] on iOS', () {
      expect(
          AsyncStorageReader(FakePlatform(operatingSystem: 'ios'))
              is AsyncStorageIOS,
          isTrue);
    });

    test('throws for a [Platform] other than iOS or Android', () {
      expect(() => AsyncStorageReader(FakePlatform(operatingSystem: '')),
          throwsA(isA<UnimplementedError>()));
    });
  });

  // [AsyncStorageAndroid._read] is not useful to test directly, since there is
  // no in-memory test mock of SQFLite.
}
