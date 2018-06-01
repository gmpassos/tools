// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  StreamController streamController;
  StreamController sinkController;
  StreamChannel channel;
  setUp(() {
    streamController = new StreamController();
    sinkController = new StreamController();
    channel = new StreamChannel(streamController.stream, sinkController.sink);
  });

  test("pipe() pipes data from each channel's stream into the other's sink",
      () {
    var otherStreamController = new StreamController();
    var otherSinkController = new StreamController();
    var otherChannel = new StreamChannel(
        otherStreamController.stream, otherSinkController.sink);
    channel.pipe(otherChannel);

    streamController.add(1);
    streamController.add(2);
    streamController.add(3);
    streamController.close();
    expect(otherSinkController.stream.toList(), completion(equals([1, 2, 3])));

    otherStreamController.add(4);
    otherStreamController.add(5);
    otherStreamController.add(6);
    otherStreamController.close();
    expect(sinkController.stream.toList(), completion(equals([4, 5, 6])));
  });

  test("transform() transforms the channel", () async {
    var transformed = channel
        .cast<List<int>>()
        .transform(new StreamChannelTransformer.fromCodec(utf8));

    streamController.add([102, 111, 111, 98, 97, 114]);
    streamController.close();
    expect(await transformed.stream.toList(), equals(["foobar"]));

    transformed.sink.add("fblthp");
    transformed.sink.close();
    expect(
        sinkController.stream.toList(),
        completion(equals([
          [102, 98, 108, 116, 104, 112]
        ])));
  });

  test("transformStream() transforms only the stream", () async {
    var transformed =
        channel.cast<String>().transformStream(const LineSplitter());

    streamController.add("hello world");
    streamController.add(" what\nis");
    streamController.add("\nup");
    streamController.close();
    expect(await transformed.stream.toList(),
        equals(["hello world what", "is", "up"]));

    transformed.sink.add("fbl\nthp");
    transformed.sink.close();
    expect(sinkController.stream.toList(), completion(equals(["fbl\nthp"])));
  });

  test("transformSink() transforms only the sink", () async {
    var transformed = channel.cast<String>().transformSink(
        new StreamSinkTransformer.fromStreamTransformer(const LineSplitter()));

    streamController.add("fbl\nthp");
    streamController.close();
    expect(await transformed.stream.toList(), equals(["fbl\nthp"]));

    transformed.sink.add("hello world");
    transformed.sink.add(" what\nis");
    transformed.sink.add("\nup");
    transformed.sink.close();
    expect(sinkController.stream.toList(),
        completion(equals(["hello world what", "is", "up"])));
  });

  test("changeStream() changes the stream", () {
    var newController = new StreamController();
    var changed = channel.changeStream((stream) {
      expect(stream, equals(channel.stream));
      return newController.stream;
    });

    newController.add(10);
    newController.close();

    streamController.add(20);
    streamController.close();

    expect(changed.stream.toList(), completion(equals([10])));
  });

  test("changeSink() changes the sink", () {
    var newController = new StreamController();
    var changed = channel.changeSink((sink) {
      expect(sink, equals(channel.sink));
      return newController.sink;
    });

    expect(newController.stream.toList(), completion(equals([10])));
    streamController.stream.listen(expectAsync1((_) {}, count: 0));

    changed.sink.add(10);
    changed.sink.close();
  });
}
