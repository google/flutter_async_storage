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

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:disposables/disposables.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform/platform.dart';
import 'package:sqflite/sqflite.dart';

const iosBundleIdentifier = "com.example.your.bundle.id";

/// Class to read data from React Native AsyncStorage.
///
/// Delegates to either [AsyncStorageAndroid] or [AsyncStorageIOS], as storage
/// format differs by platform.
///
/// Error handling on public methods should be handled by the end user.
abstract class AsyncStorageReader {
  factory AsyncStorageReader(Platform platform) {
    if (platform.isAndroid) return AsyncStorageAndroid();
    if (platform.isIOS) return AsyncStorageIOS();
    // Unit tests run on Linux.
    if (platform.isLinux) return AsyncStorageTestOnly();
    throw UnimplementedError('Unrecognized platform: $platform');
  }

  /// Whether there is AsyncStorage data available.
  Future<bool> exists();

  /// Stored data from AsyncStorage as a string.
  ///
  /// You can deserialize the data into another format.
  Future<String?> data(String dataKey);

  /// Wipes data from AsyncStorage if it exists.
  Future<void> clear();
}

/// The database that contains AsyncStorage data on Android.
const _androidDbName = 'RKStorage';

/// The table within [androidDbName] that contains AsyncStorage data on Android.
const _androidTableName = 'catalystLocalStorage';

/// The column within [androidTableName] that contains AsyncStorage keys.
const _androidKeyColumnName = 'key';

/// The column within [androidTableName] that contains AsyncStorage values.
const _androidDataColumnName = 'value';

/// Android implementation of [AsyncStorageReader].
///
/// On Android, React Native AsyncStorage is backed by a SQLite db.
class AsyncStorageAndroid implements AsyncStorageReader, Disposable  {
  /// Whether [_db] is ready for use.
  bool _initialized = false;

  @override
  bool isDisposed = false;

  /// Connection to the SQLite database, or [null] if no database exists.
  late Database? _db;

  Future<void> _initialize() async {
    if (await exists()) {
      // Initialize as read-only so we don't have to implement an [onUpgrade].
      _db = await openDatabase(_androidDbName, readOnly: true);
    } else {
      _db = null;
    }
    _initialized = true;
  }

  Future<void> _close() async {
    if (await exists() && _db != null) {
      await _db!.close();
    }
    _initialized = false;
  }

  @override
  Future<bool> exists() async => databaseExists(_androidDbName);

  @override
  Future<String?> data(String dataKey) async {
    if (!_initialized) {
      await _initialize();
    }
    if (_db != null) {
      final result = await _db!.query(_androidTableName,
          columns: [_androidDataColumnName],
          where: '$_androidKeyColumnName = ?',
          whereArgs: [dataKey]);
      return result.single[_androidDataColumnName] as String;
    }
    return null;
  }

  @override
  Future<void> clear() async {
    if (!_initialized) {
      await _initialize();
    }
    if (_db != null) {
      await deleteDatabase(_androidDbName);
      await _close();
    }
  }

  @override
  void dispose() {
    isDisposed = true;
    _close();
  }
}

/// Directory containing AsyncStorage data on iOS.
const _iosDataDirectory = 'RCTAsyncLocalStorage_V1';

/// File containing some AsyncStorage data and paths to other data files.
const _iosManifestFilename = 'manifest.json';

/// iOS implementation of [AsyncStorageReader].
///
/// On iOS, React Native AsyncStorage is backed by a directory of JSON files.
@visibleForTesting
class AsyncStorageIOS implements AsyncStorageReader {
  @override
  Future<bool> exists() async {
    return (await _manifest).exists();
  }

  @override
  Future<String?> data (String dataKey) async {
      // On iOS, data is either stored in the manifest file, or if too
      // large is sharded into another file in the same directory. Following
      // the same logic as AsyncStorage, we first check the manifest, then the
      // filesystem if the manifest does not contain any data.
      return (await _dataFromManifest(dataKey)) ??
          (await _dataFromFilesystem(dataKey));
  }

  @override
  Future<void> clear() async {
      final storageDirectory = await _asyncStorageDirectory();
      await storageDirectory.delete(recursive: true);
  }

  /// Directory that all AsyncStorage files are contained in on iOS.
  Future<Directory> _asyncStorageDirectory() async {
    // Storing data in the Documents directory should be avoided, but in
    // this case we need to access it to port data from the legacy React Native
    // app.
    final docDir = await getApplicationSupportDirectory();
    return Directory('${docDir.path}/$iosBundleId/$_iosDataDirectory');
  }

  Future<File> _asyncStorageFile(String filename) async {
    final rnDir = await _asyncStorageDirectory();
    return File('${rnDir.path}/$filename');
  }

  /// Returns data stored in the manifest file, if available.
  Future<String?> _dataFromManifest(String dataKey) async {
      final manifestData = await (await _manifest).readAsString();
      final jsonData = json.decode(manifestData);
      return jsonData[dataKey];
  }

  /// Returns data sharded into the filesystem, if available.
  Future<String?> _dataFromFilesystem(String dataKey) async {
      // md5 is cryptographically insecure, but is used by React Native to
      // shard files.
      final encodedFilename =
          md5.convert(utf8.encode(dataKey)).toString();
      final encodedFile = await _asyncStorageFile(encodedFilename);
      return encodedFile.readAsString();
  }

  Future<File> get _manifest async => _asyncStorageFile(_iosManifestFilename);
}

/// Test-only mock of [AsyncStorageReader].
@visibleForTesting
class AsyncStorageTestOnly implements AsyncStorageReader {
  @override
  Future<bool> exists() async => true;

  @override
  Future<String?> data(String _) async => '';

  @override
  Future<void> clear() async {}
}
