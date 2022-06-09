# flutter_async_storage

flutter_async_storage reads data from React Native's [AsyncStorage](https://reactnative.dev/docs/asyncstorage) from within Flutter apps. This is useful for Flutter apps that have migrated from React Native and need to access data stored on disk.

## Reading data

To read data from AsyncStorage in Flutter, you can use a workflow like:

```
final asyncStorageReader = AsyncStorageReader(LocalPlatform());
try {
if (await asyncStorageReader.exists()) {
    final data = await asyncStorageReader.data('myDataKey');

    // Do something with data...

    // Clear AsyncStorage.
    await asyncStorageReader.clear();
}
} catch (e) {
// Handle error.
}
```

## Using data

Data in AsyncStorage is keyed; you can use the `data()` method on `AsyncStorageReader` to read arbitrary keys. Data returned is stringified JSON, which you can deserialize to another format. [built_value](https://pub.dev/packages/built_value) allows you to create custom deserializers which are helpful for converting data to Dart objects.

## Platform specific code

flutter_async_storage can read from AsyncStorage on both Android and iOS. On Android, AsyncStorage data is stored in a SQLite database in the table `RKStorage`. On iOS, AsyncStorage data is stored in the filesystem (in a manifest file for smaller data, and sharded into separate files for larger data using a hash function). flutter_async_storage mimics the path taken to retrive data by React Native's AsyncStorage.

The platform must be specified in the constructor for `AsyncStorageReader`, but the API is the same.
