@TestOn('browser')

import 'dart:async';
import 'dart:html';

import 'package:stream_channel/message_port_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  MessagePort port;
  StreamChannel channel;

  setUp(() {
    var messageChannel = MessageChannel();
    port = messageChannel.port2;
    channel = MessagePortChannel(messageChannel.port1);
  });

  tearDown(() {
    port.close();
    channel.sink.close();
  });

  test("the channel can send messages", () {
    channel.sink.add(1);
    channel.sink.add(2);
    channel.sink.add(3);

    expect(port.onMessage.map((message) => message.data).take(3).toList(),
        completion(equals([1, 2, 3])));
  });

  test("the channel can receive messages", () {
    port.postMessage(1);
    port.postMessage(2);
    port.postMessage(3);

    expect(channel.stream.take(3).toList(), completion(equals([1, 2, 3])));
  });

  test("events can't be added to an explicitly closed sink", () {
    expect(channel.sink.close(), completes);
    expect(() => channel.sink.add(1), throwsStateError);
    expect(() => channel.sink.addError("oh no"), throwsStateError);
    expect(() => channel.sink.addStream(Stream.fromIterable([])),
        throwsStateError);
  });

  test("events can't be added while a stream is being added", () {
    var controller = StreamController();
    channel.sink.addStream(controller.stream);

    expect(() => channel.sink.add(1), throwsStateError);
    expect(() => channel.sink.addError("oh no"), throwsStateError);
    expect(() => channel.sink.addStream(Stream.fromIterable([])),
        throwsStateError);
    expect(() => channel.sink.close(), throwsStateError);

    controller.close();
  });

  group("stream channel rules", () {
    test(
        "closing the sink causes the stream to close before it emits any more "
        "events", () {
      port.postMessage(1);
      port.postMessage(2);
      port.postMessage(3);
      port.postMessage(4);
      port.postMessage(5);

      channel.stream.listen(expectAsync1((message) {
        expect(message, equals(1));
        channel.sink.close();
      }, count: 1));
    });

    test("cancelling the stream's subscription has no effect on the sink",
        () async {
      channel.stream.listen(null).cancel();
      await pumpEventQueue();

      channel.sink.add(1);
      channel.sink.add(2);
      channel.sink.add(3);
      expect(port.onMessage.map((message) => message.data).take(3).toList(),
          completion(equals([1, 2, 3])));
    });

    test("the sink closes as soon as an error is added", () async {
      channel.sink.addError("oh no");
      channel.sink.add(1);
      expect(channel.sink.done, throwsA("oh no"));

      // Since the sink is closed, the stream should also be closed.
      expect(channel.stream.isEmpty, completion(isTrue));

      // The other end shouldn't receive the next event, since the sink was
      // closed. Pump the event queue to give it a chance to.
      port.onMessage.listen(expectAsync1((_) {}, count: 0));
      await pumpEventQueue();
    });

    test("the sink closes as soon as an error is added via addStream",
        () async {
      var canceled = false;
      var controller = StreamController(onCancel: () {
        canceled = true;
      });

      // This future shouldn't get the error, because it's sent to [Sink.done].
      expect(channel.sink.addStream(controller.stream), completes);

      controller.addError("oh no");
      expect(channel.sink.done, throwsA("oh no"));
      await pumpEventQueue();
      expect(canceled, isTrue);

      // Even though the sink is closed, this shouldn't throw an error because
      // the user didn't explicitly close it.
      channel.sink.add(1);
    });
  });

  test("create a connected pair of channels", () {
    var channel1 = channel;
    var channel2 = MessagePortChannel(port);

    channel1.sink.add(1);
    channel1.sink.add(2);
    channel1.sink.add(3);
    expect(channel2.stream.take(3).toList(), completion(equals([1, 2, 3])));

    channel2.sink.add(4);
    channel2.sink.add(5);
    channel2.sink.add(6);
    expect(channel1.stream.take(3).toList(), completion(equals([4, 5, 6])));
  });
}
