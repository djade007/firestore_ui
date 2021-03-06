import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/src/method_channel/method_channel_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firestore_ui/firestore_list.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// todo: fix test
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreList', () {
    int mockHandleId = 0;
    final defaultBinaryMessenger =
        ServicesBinding.instance!.defaultBinaryMessenger;
    StreamController<QuerySnapshot>? streamController;
    final List<MethodCall> log = <MethodCall>[];
    late FirestoreList list;
    FirebaseFirestore firestore;
    late CollectionReference collectionReference;
    const Map<String, dynamic> kMockDocumentSnapshotData = <String, dynamic>{
      '1': 2
    };

    setUp(() async {
      setupCloudFirestoreMocks();
      // MethodChannelFirebaseFirestore.channel = const MethodChannel(
      //   'plugins.flutter.io/firebase_firestore',
      //   StandardMethodCodec(TestFirestoreMessageCodec()),
      // );

      /*    MethodChannelFirebase.channel.setMockMethodCallHandler(
        (MethodCall methodCall) async {},
      );
      MethodChannelFirebase.channel.setMockMethodCallHandler((call) => null);

      MethodChannelFirebaseFirestore.channel.setMockMethodCallHandler(
        (call) async {},
      );*/

      await Firebase.initializeApp(
        options: FirebaseOptions(
          appId: '1:1234567890:ios:42424242424242',
          messagingSenderId: '1234567890',
          apiKey: '1234',
          projectId: 'project',
        ),
      );

      firestore = FirebaseFirestore.instance;

      collectionReference = firestore.collection('foo');

      streamController = StreamController<QuerySnapshot>();

      list = FirestoreList(
        query: collectionReference,
        debug: false,
      );

      MethodChannelFirebaseFirestore.channel
          .setMockMethodCallHandler((MethodCall methodCall) async {
        print('here');
        print(methodCall);
        print(methodCall.method);
        log.add(methodCall);
        switch (methodCall.method) {
          case 'Query#snapshots':
            print('gotttt');
            return '1234';
          case 'Query#addSnapshotListener':
            final int handle = mockHandleId++;
            // Wait before sending a message back.
            // Otherwise the first request didn't have the time to finish.
            Future<void>.delayed(Duration.zero).then((_) {
              defaultBinaryMessenger.handlePlatformMessage(
                MethodChannelFirebaseFirestore.channel.name,
                MethodChannelFirebaseFirestore.channel.codec.encodeMethodCall(
                  MethodCall('QuerySnapshot', <String, dynamic>{
                    'app': defaultFirebaseAppName,
                    'handle': handle,
                    'paths': <String>["${methodCall.arguments['path']}/0"],
                    'documents': <dynamic>[kMockDocumentSnapshotData],
                    'documentChanges': <dynamic>[
                      <String, dynamic>{
                        'oldIndex': -1,
                        'newIndex': 0,
                        'type': 'DocumentChangeType.added',
                        'document': kMockDocumentSnapshotData,
                      },
                    ],
                  }),
                ),
                (_) {},
              );
            });
            return handle;
          case 'Query#addDocumentListener':
            final int handle = mockHandleId++;
            // Wait before sending a message back.
            // Otherwise the first request didn't have the time to finish.
            Future<void>.delayed(Duration.zero).then((_) {
              defaultBinaryMessenger.handlePlatformMessage(
                MethodChannelFirebaseFirestore.channel.name,
                MethodChannelFirebaseFirestore.channel.codec.encodeMethodCall(
                  MethodCall('DocumentSnapshot', <String, dynamic>{
                    'handle': handle,
                    'path': methodCall.arguments['path'],
                    'data': kMockDocumentSnapshotData,
                  }),
                ),
                (_) {},
              );
            });
            return handle;
          case 'Query#getDocuments':
            return <String, dynamic>{
              'paths': <String>["${methodCall.arguments['path']}/0"],
              'documents': <dynamic>[kMockDocumentSnapshotData],
              'documentChanges': <dynamic>[
                <String, dynamic>{
                  'oldIndex': -1,
                  'newIndex': 0,
                  'type': 'DocumentChangeType.added',
                  'document': kMockDocumentSnapshotData,
                },
              ],
            };
          case 'DocumentReference#setData':
            return true;
          case 'DocumentReference#get':
            if (methodCall.arguments['path'] == 'foo/bar') {
              return <String, dynamic>{
                'path': 'foo/bar',
                'data': <String, dynamic>{'key1': 'val1'}
              };
            } else if (methodCall.arguments['path'] == 'foo/notExists') {
              return <String, dynamic>{'path': 'foo/notExists', 'data': null};
            }
            throw PlatformException(code: 'UNKNOWN_PATH');
          case 'Firestore#runTransaction':
            return <String, dynamic>{'1': 3};
          case 'Transaction#get':
            if (methodCall.arguments['path'] == 'foo/bar') {
              return <String, dynamic>{
                'path': 'foo/bar',
                'data': <String, dynamic>{'key1': 'val1'}
              };
            } else if (methodCall.arguments['path'] == 'foo/notExists') {
              return <String, dynamic>{'path': 'foo/notExists', 'data': null};
            }
            throw PlatformException(code: 'UNKNOWN_PATH');
          case 'Transaction#set':
            return null;
          case 'Transaction#update':
            return null;
          case 'Transaction#delete':
            return null;
          case 'WriteBatch#create':
            return 1;
          default:
            return null;
        }
      });
      log.clear();
    });

    Future<void> processChange(QuerySnapshot querySnapshot) async {
      streamController!.add(querySnapshot);
    }

    test('can add to empty list', () async {
      print('step1');
      expect(collectionReference.id, "foo");
      print('step2');
      await processChange(await collectionReference.snapshots().first);
      print('step3');
      expect(list.length, 1);
      expect(list[0]!.data, kMockDocumentSnapshotData);
    });

    streamController?.close();
  });
}

typedef Callback = void Function(MethodCall call);

void setupCloudFirestoreMocks([Callback? customHandlers]) {
  MethodChannelFirebase.channel.setMockMethodCallHandler((call) async {
    if (call.method == 'Firebase#initializeCore') {
      return [
        {
          'name': defaultFirebaseAppName,
          'options': {
            'apiKey': '123',
            'appId': '123',
            'messagingSenderId': '123',
            'projectId': '123',
          },
          'pluginConstants': {},
        }
      ];
    }

    if (call.method == 'Firebase#initializeApp') {
      return {
        'name': call.arguments['appName'],
        'options': call.arguments['options'],
        'pluginConstants': {},
      };
    }

    if (customHandlers != null) {
      customHandlers(call);
    }

    return null;
  });
}
